extends Node2D
## Gobhold build phase: spend owned tower copies on free placement,
## drag-aim each tower (crosshair distance = arc width), then commit.
## Constraints: off the path, no overlaps. Start locks the layout.

const Defs = preload("res://game/defs.gd")
const Progression = preload("res://game/progression.gd")
const TowerScript = preload("res://game/tower.gd")
const PATH_HALF := 38.0
const TOWER_R := 20.0
const ARC_MAX_DIST := 400.0

var def := {}
var tree := {}
var effects := {}
var copies := {}
var tower_cap := 3
var build_tutorial := false
var tray := "" # selected tower type for placement, "" = none
var mode := "aim" # aim | move
var selected = null # tower being aimed/moved/inspected
var baked := PackedVector2Array()

var _press_down := false
var _press_tower = null
var _press_vpos := Vector2.ZERO
var _press_moved := false
var _press_orig := Vector2.ZERO
var _hover := Vector2(-9999.0, -9999.0)

@onready var path: Path2D = $Path
@onready var road: Line2D = $Road
@onready var towers_root: Node2D = $Towers
@onready var tray_box: HBoxContainer = $HUD/TrayBox
@onready var count_label: Label = $HUD/CountLabel
@onready var start_button: Button = $HUD/StartButton
@onready var back_button: Button = $HUD/BackButton
@onready var mode_button: Button = $HUD/ModeButton
@onready var help_button: Button = $HUD/HelpButton
@onready var help_panel: PanelContainer = $HUD/HelpPanel
@onready var message_label: Label = $HUD/MessageLabel
@onready var info_panel: PanelContainer = $HUD/InfoPanel
@onready var info_title: Label = $HUD/InfoPanel/VBox/Title
@onready var info_priority: Button = $HUD/InfoPanel/VBox/PriorityButton
@onready var info_arc_label: Label = $HUD/InfoPanel/VBox/ArcLabel
@onready var info_arc: HSlider = $HUD/InfoPanel/VBox/ArcSlider


func _ready() -> void:
	Engine.time_scale = 1.0
	var lid := Save.active_level if Save.active_level != "" else "1.1"
	def = Defs.level(lid)
	if Save.active_slot >= 0:
		var data := Save.load_slot(Save.active_slot)
		tree = (data["meta"] as Dictionary).get("tree", {})
	effects = Progression.effects(tree)
	copies = (effects["copies"] as Dictionary).duplicate()
	tower_cap = 3 + int(effects.get("tower_count", 0))
	build_tutorial = lid == "1.1"
	if lid == "1.1" and int(copies.get("gun", 0)) <= 0:
		copies["gun"] = 1
	if Save.active_level == "" and copies.get("gun", 0) == 0:
		copies = {"scrapper": 1, "gun": 2, "cannon": 1, "mortar": 1, "flame": 0, "grenade": 0, "tesla": 0, "cryo": 0, "laser": 0} # dev slice purse
	var pts := PackedVector2Array(def["path"])
	var curve := Curve2D.new()
	for p in pts:
		curve.add_point(p)
	path.curve = curve
	road.points = curve.get_baked_points()
	baked = curve.get_baked_points()
	start_button.pressed.connect(_on_start)
	help_button.pressed.connect(func() -> void: help_panel.visible = not help_panel.visible)
	$HUD/HelpPanel/VBox/CloseButton.pressed.connect(func() -> void: help_panel.visible = false)
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://ui/skill_tree.tscn"))
	mode_button.pressed.connect(_on_mode)
	info_priority.pressed.connect(_on_priority)
	info_arc.value_changed.connect(_on_arc)
	$HUD/InfoPanel/VBox/DeleteButton.pressed.connect(_on_delete)
	$HUD/InfoPanel/VBox/CloseButton.pressed.connect(_on_info_close)
	_build_tray()
	if not Save.pending_layout.is_empty():
		var saved := Save.pending_layout.duplicate(true)
		Save.pending_layout = []
		for spec in saved:
			_spawn_tower(spec)
		_build_tray()
		_say("Replay the exact layout, or remove a tower and rebuild.")
	elif build_tutorial:
		_say("Build tutorial: choose GUNNER, place it on grass, then drag to aim.")
	else:
		_say("Tap a tray icon, then tap open ground near the road.")
	_update_hud()


func _build_tray() -> void:
	for c in tray_box.get_children():
		c.queue_free()
	var shown := 0
	for t in Defs.TOWERS:
		var n: int = int(copies.get(t, 0))
		if n <= 0:
			continue
		var b := Button.new()
		b.text = "%s x%d" % [String(Defs.TOWERS[t]["name"]), n]
		b.custom_minimum_size = Vector2(150, 54)
		b.add_theme_font_size_override("font_size", 16)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.toggled.connect(_on_tray.bind(t))
		b.set_meta("type", t)
		tray_box.add_child(b)
		shown += 1
	if shown == 0:
		_say("No towers owned — open LEVELS, buy GUNNER (Free).")
	start_button.disabled = build_tutorial and towers_root.get_child_count() == 0


func _on_tray(pressed: bool, t: String) -> void:
	if pressed:
		tray = t
		for b in tray_box.get_children():
			if String(b.get_meta("type")) != t:
				b.set_pressed_no_signal(false)
		_close_info()
	else:
		tray = ""
	queue_redraw()


func _on_mode() -> void:
	mode = "move" if mode == "aim" else "aim"
	mode_button.text = "MODE: MOVE" if mode == "move" else "MODE: AIM"
	_say("Drag towers to move them." if mode == "move" else "Drag from a tower to aim it.")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_start()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_hover = _to_world(event.position)
		_drag(event.position, (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)
	elif event is InputEventScreenDrag:
		_hover = _to_world(event.position)
		_drag(event.position, true)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)


func _to_world(vpos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * vpos


func _tower_at(world: Vector2):
	var best = null
	var best_d := 40.0
	for t in towers_root.get_children():
		var d: float = t.global_position.distance_to(world)
		if d < best_d:
			best = t
			best_d = d
	return best


func _press(vpos: Vector2) -> void:
	_press_down = true
	_press_moved = false
	_press_vpos = vpos
	_press_tower = null
	if tray == "":
		_press_tower = _tower_at(_to_world(vpos))
		if _press_tower != null:
			_press_orig = _press_tower.position


func _drag(vpos: Vector2, held: bool) -> void:
	if not _press_down or not held or _press_tower == null:
		return
	if not is_instance_valid(_press_tower):
		_press_tower = null
		return
	if (vpos - _press_vpos).length() > 16.0:
		_press_moved = true
	if not _press_moved:
		return
	var t = _press_tower
	var world := _to_world(vpos)
	if mode == "move":
		t.position = world
	else:
		var to: Vector2 = world - t.global_position
		if to.length() > 24.0:
			t.aim_angle = to.angle()
			t.arc = minf(lerpf(TAU, deg_to_rad(25.0), clampf(to.length() / ARC_MAX_DIST, 0.0, 1.0)), deg_to_rad(float(effects.get("cone_width", 360.0))))
			if t == selected:
				_refresh_info()


func _release(vpos: Vector2) -> void:
	if not _press_down:
		return
	_press_down = false
	var world := _to_world(vpos)
	if tray != "":
		_try_place(world)
		_press_tower = null
		return
	var t = _press_tower
	_press_tower = null
	if t == null or not is_instance_valid(t):
		return
	if _press_moved and mode == "move":
		var reason := _placement_error(t.position, t)
		if reason != "":
			t.position = _press_orig
			_say(reason)
		t.show_scope = false
		queue_redraw()
		return
	_open_info(t)


func _dist_to_path(p: Vector2) -> float:
	var best := 1e9
	for b in baked:
		best = minf(best, p.distance_to(b))
	return best


func _valid_spot(p: Vector2, ignore) -> bool:
	return _placement_error(p, ignore) == ""


func _placement_error(p: Vector2, ignore) -> String:
	if ignore == null and towers_root.get_child_count() >= tower_cap:
		return "Deployment cap reached. Unlock TOWER COUNT for another slot."
	if _dist_to_path(p) < PATH_HALF + TOWER_R + 4.0:
		return "Blocked: place the turret on grass, not the road."
	for t in towers_root.get_children():
		if t == ignore:
			continue
		if t.global_position.distance_to(p) < TOWER_R * 2.0 + 4.0:
			return "Blocked: leave space between turrets."
	var size := get_viewport_rect().size
	var top_left := _to_world(Vector2(24.0, 24.0))
	var bottom_right := _to_world(size - Vector2(24.0, 24.0))
	if p.x < top_left.x or p.y < top_left.y or p.x > bottom_right.x or p.y > bottom_right.y:
		return "Blocked: keep the turret inside the map."
	return ""


func _try_place(world: Vector2) -> void:
	if int(copies.get(tray, 0)) <= 0:
		_say("No %s unlocked. Buy it in the skill tree." % String(Defs.TOWERS.get(tray, {}).get("name", tray)))
		return
	var reason := _placement_error(world, null)
	if reason != "":
		_say(reason)
		return
	var t = _spawn_tower({"type": tray, "x": world.x, "y": world.y, "aim": (_nearest_path(world) - world).angle(), "arc": TAU, "priority": "near"})
	Input.vibrate_handheld(25)
	_build_tray()
	if int(copies.get(tray, 0)) <= 0:
		tray = ""
	_say("%d towers placed. Drag one to aim." % towers_root.get_child_count())
	if build_tutorial:
		_say("Good. Drag from Gunner toward the lane to narrow its firing cone, then press BATTLE.")
		build_tutorial = false
	queue_redraw()
	_update_hud()


func _spawn_tower(spec: Dictionary):
	var tower_type := String(spec.get("type", "gun"))
	if not Defs.TOWERS.has(tower_type):
		return null
	var t = TowerScript.new()
	t.setup(tower_type, Defs.TOWERS[tower_type], float(effects["damage_mult"].get(tower_type, 1.0)), float(effects["rate_mult"].get(tower_type, 1.0)), float(effects["range_mult"]), effects)
	t.position = Vector2(float(spec.get("x", 0.0)), float(spec.get("y", 0.0)))
	t.aim_angle = float(spec.get("aim", 0.0))
	t.arc = minf(float(spec.get("arc", TAU)), deg_to_rad(float(effects.get("cone_width", 360.0))))
	t.priority = String(spec.get("priority", "near"))
	towers_root.add_child(t)
	if int(copies.get(tower_type, 0)) > 0:
		copies[tower_type] = int(copies[tower_type]) - 1
	return t


func _nearest_path(p: Vector2) -> Vector2:
	var best: Vector2 = baked[0] if baked.size() > 0 else p
	var best_d := 1e9
	for b in baked:
		var d := p.distance_to(b)
		if d < best_d:
			best_d = d
			best = b
	return best


func _open_info(t) -> void:
	if selected != null and is_instance_valid(selected) and selected != t:
		selected.show_scope = false
	selected = t
	t.show_scope = true
	_refresh_info()
	var screen: Vector2 = get_viewport().get_canvas_transform() * (t.global_position + Vector2(52, -170))
	screen.x = clampf(screen.x, 8.0, get_viewport_rect().size.x - 260.0)
	screen.y = clampf(screen.y, 8.0, get_viewport_rect().size.y - 300.0)
	info_panel.position = screen
	info_panel.visible = true
	Input.vibrate_handheld(10)


func _refresh_info() -> void:
	var t = selected
	if t == null or not is_instance_valid(t):
		return
	info_title.text = "%s — %s" % [String(Defs.TOWERS[t.type]["name"]), t.priority.capitalize()]
	info_priority.text = "Target: %s" % t.priority.capitalize()
	info_arc.set_value_no_signal(rad_to_deg(t.arc))
	info_arc.max_value = float(effects.get("cone_width", 360.0))
	info_arc_label.text = "Arc: %d°" % int(round(rad_to_deg(t.arc)))


func _on_priority() -> void:
	if selected == null or not is_instance_valid(selected):
		return
	var order := ["near", "first", "strong"]
	selected.priority = order[(order.find(selected.priority) + 1) % order.size()]
	_refresh_info()


func _on_arc(value: float) -> void:
	if selected == null or not is_instance_valid(selected):
		return
	selected.arc = deg_to_rad(clampf(value, 25.0, float(effects.get("cone_width", 360.0))))
	_refresh_info()


func _on_delete() -> void:
	if selected == null or not is_instance_valid(selected):
		_close_info()
		return
	copies[selected.type] = int(copies.get(selected.type, 0)) + 1
	_say("%s recovered." % String(Defs.TOWERS[selected.type]["name"]))
	selected.queue_free()
	selected = null
	_close_info()
	_build_tray()


func _on_info_close() -> void:
	_close_info()


func _close_info() -> void:
	if selected != null and is_instance_valid(selected):
		selected.show_scope = false
	selected = null
	info_panel.visible = false


func _on_start() -> void:
	var specs := []
	for t in towers_root.get_children():
		specs.append({"type": t.type, "x": t.position.x, "y": t.position.y,
			"aim": t.aim_angle, "arc": t.arc, "priority": t.priority})
	Save.pending_layout = specs
	Save.pending_gold = 400
	if towers_root.get_child_count() == 0:
		_say("Place at least one tower before battle.")
		return
	if Save.active_slot >= 0:
		var data := Save.load_slot(Save.active_slot)
		var meta: Dictionary = data["meta"]
		var progress: Dictionary = data["progress"]
		meta["current_level"] = String(def.get("id", "1.1"))
		meta["last"] = Save.stamp()
		progress["layouts"][String(def.get("id", "1.1"))] = specs
		Save.write_slot(Save.active_slot, data)
	print("build committed %d towers on %s." % [specs.size(), String(def.get("id", "?"))])
	get_tree().change_scene_to_file("res://game/combat.tscn")


func _process(_delta: float) -> void:
	if tray != "":
		queue_redraw() # placement ghost follows pointer


func _say(t: String) -> void:
	message_label.text = t


func _update_hud() -> void:
	count_label.text = "TOWERS %d/%d" % [towers_root.get_child_count(), tower_cap]


func _draw() -> void:
	draw_rect(Rect2(Vector2(-100, -100), Vector2(1500, 900)), Color("#5f963d"))
	if baked.size() > 0:
		var start := baked[0]
		var finish := baked[baked.size() - 1]
		draw_circle(start, 20.0, Color(0.85, 0.15, 0.15, 0.9))
		draw_string(ThemeDB.fallback_font, start + Vector2(-7, 8), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
		for x in range(-24, 25, 12):
			for y in range(-24, 25, 12):
				if int(x / 12 + y / 12) % 2 == 0:
					draw_rect(Rect2(finish + Vector2(x, y), Vector2(12, 12)), Color.WHITE)
	if tray == "" or _hover.x < -9000.0:
		return
	var stats: Dictionary = Defs.TOWERS[tray]
	var ok := _valid_spot(_hover, null)
	var c := Color(0.35, 1.0, 0.45, 0.8) if ok else Color(1.0, 0.35, 0.35, 0.6)
	draw_arc(_hover, float(stats["range"]), 0.0, TAU, 48, Color(c.r, c.g, c.b, 0.3), 2.0)
	draw_circle(_hover, TOWER_R, Color(c.r, c.g, c.b, 0.3))
	# Suggested aim wedge toward the road (new towers start full-circle).
	var aim := (_nearest_path(_hover) - _hover).angle()
	var half := deg_to_rad(60.0)
	var faint := Color(c.r, c.g, c.b, 0.18)
	draw_line(_hover, _hover + Vector2.RIGHT.rotated(aim - half) * float(stats["range"]), faint, 2.0)
	draw_line(_hover, _hover + Vector2.RIGHT.rotated(aim + half) * float(stats["range"]), faint, 2.0)
	draw_arc(_hover, float(stats["range"]) * 0.99, aim - half, aim + half, 32, faint, 2.0)
