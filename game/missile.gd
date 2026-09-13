extends Node2D
## Manual missile: the commander's hand in battle.
## PC: crosshair follows the mouse, click fires. Mobile: press-drag from the
## bottom-center handle, release fires. Drop delay + cooldown gate spam.

signal fired

var horde = null
var active := false
var cooldown := 2.0
var damage := 60.0
var blast := 45.0
var auto_unlocked := false
var auto_on := false

const DROP := 0.25

var cd_left := 0.0
var cross := Vector2(640, 360)
var last_hit := Vector2(-9999.0, -9999.0)
var _touch_id := -1
var _mheld := false
var _touch_device := false
var _pending := [] # [{point, timer}]
var _flashes := [] # [{pos, t}]


func _ready() -> void:
	cross = get_viewport_rect().size * 0.5
	_touch_device = DisplayServer.is_touchscreen_available()


func _process(_delta: float) -> void:
	# PC crosshair follows unconditionally: no event delivery to trust.
	if active and not _touch_device:
		cross = _to_world(get_viewport().get_mouse_position())
		var held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if held and not _mheld:
			var hovered := get_viewport().gui_get_hovered_control()
			if hovered == null or not (hovered is Button):
				try_fire(cross)
		_mheld = held


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion:
		cross = _to_world(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cross = _to_world(event.position)
		try_fire(cross)
	elif event is InputEventScreenTouch:
		# Touch: finger steers the crosshair, lift-off fires there.
		# A quick tap fires where it lands.
		if event.pressed and _touch_id < 0:
			_touch_id = event.index
			cross = _to_world(event.position)
		elif not event.pressed and event.index == _touch_id:
			_touch_id = -1
			cross = _to_world(event.position)
			try_fire(cross)
	elif event is InputEventScreenDrag and event.index == _touch_id:
		cross = _to_world(event.position)


func _to_world(viewport_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * viewport_pos


func try_fire(world: Vector2) -> bool:
	if not active or cd_left > 0.0:
		return false
	cd_left = cooldown
	cross = world
	_pending.append({"point": world, "timer": DROP})
	fired.emit()
	Input.vibrate_handheld(30)
	return true


func toggle_auto() -> bool:
	if not auto_unlocked:
		return false
	auto_on = not auto_on
	Input.vibrate_handheld(15)
	return auto_on


func _physics_process(delta: float) -> void:
	cd_left = maxf(0.0, cd_left - delta)
	if active and auto_on and cd_left <= 0.0:
		try_fire(cross)
	var i := 0
	while i < _pending.size():
		var p: Dictionary = _pending[i]
		p["timer"] = float(p["timer"]) - delta
		if float(p["timer"]) <= 0.0:
			_detonate(p["point"])
			_pending.remove_at(i)
			continue
		i += 1
	for f in _flashes:
		f["t"] = float(f["t"]) - delta
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return float(f["t"]) > 0.0)
	queue_redraw()


func _detonate(point: Vector2) -> void:
	if horde != null and is_instance_valid(horde):
		horde.damage_at(point, blast, damage)
	last_hit = point
	_flashes.append({"pos": point - global_position, "t": 0.35})
	Input.vibrate_handheld(40)


func _draw() -> void:
	if not active:
		return
	# Crosshair.
	var c := cross - global_position
	var is_ready := cd_left <= 0.0
	var col := Color(1, 0.85, 0.3) if is_ready else Color(0.5, 0.5, 0.55, 0.7)
	draw_arc(c, 24.0, 0.0, TAU, 28, col, 3.0)
	draw_line(c + Vector2(-34, 0), c + Vector2(-14, 0), col, 3.0)
	draw_line(c + Vector2(14, 0), c + Vector2(34, 0), col, 3.0)
	draw_line(c + Vector2(0, -34), c + Vector2(0, -14), col, 3.0)
	draw_line(c + Vector2(0, 14), c + Vector2(0, 34), col, 3.0)
	if not is_ready:
		draw_arc(c, 32.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - cd_left / cooldown), 28, col, 4.0)
	if auto_on:
		draw_arc(c, 42.0, 0.0, TAU, 28, Color(0.4, 1.0, 0.5, 0.9), 3.0)
	# Last impact marker.
	if last_hit.x > -9000.0:
		var h := last_hit - global_position
		draw_arc(h, 10.0, 0.0, TAU, 16, Color(1, 0.5, 0.2, 0.8), 2.0)
	# Pending drop shadows.
	for p in _pending:
		var pp: Vector2 = (p["point"] as Vector2) - global_position
		draw_arc(pp, blast * (1.0 - float(p["timer"]) / DROP), 0.0, TAU, 32, Color(1, 0.4, 0.2, 0.8), 2.0)
	# Detonation flashes.
	for f in _flashes:
		var frac: float = 1.0 - float(f["t"]) / 0.35
		draw_arc(f["pos"], blast * frac, 0.0, TAU, 32, Color(1, 0.7, 0.3, 1.0 - frac), 4.0)
