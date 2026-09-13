extends Node2D
## Gobhold battle phase. Towers hold their build-time aim while the commander
## fires cursor-directed support. Tutorial combat is intentionally loss-only.

const Defs = preload("res://game/defs.gd")
const Progression = preload("res://game/progression.gd")
const TowerScript = preload("res://game/tower.gd")

var def := {}
var tree := {}
var effects := {}
var layout := []
var is_tutorial := false
var state := "battle" # ready | battle | done
var wave_idx := -1
var spawn_left := 0
var spawn_timer := 0.0
var next_timer := 1.5
var base_hp := 20
var base_max := 20
var kills := 0
var score := 0
var gold := 0
var time_s := 0.0
var speed := 1.0
var tut_step := 0
var tut_timer := 0.0
var portal_visible := true
var result := {}
var ability_cooldowns := {}
var ability_buttons := {}

@onready var path: Path2D = $Path
@onready var road: Line2D = $Road
@onready var towers_root: Node2D = $Towers
@onready var horde = $Horde
@onready var missile = $Missile
@onready var wave_label: Label = $HUD/WaveLabel
@onready var hp_label: Label = $HUD/HPLabel
@onready var shard_label: Label = $HUD/ShardLabel
@onready var gold_label: Label = $HUD/GoldLabel
@onready var score_label: Label = $HUD/ScoreLabel
@onready var kills_label: Label = $HUD/KillsLabel
@onready var resource_label: Label = $HUD/ResourceLabel
@onready var missile_label: Label = $HUD/MissileLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var coach_panel: PanelContainer = $HUD/CoachPanel
@onready var coach_label: Label = $HUD/CoachPanel/VBox/CoachLabel
@onready var coach_step: Label = $HUD/CoachPanel/VBox/CoachStep
@onready var missile_button: Button = $HUD/MissileButton
@onready var start_button: Button = $HUD/StartWaveButton
@onready var speed_button: Button = $HUD/SpeedButton
@onready var health_bar: ProgressBar = $HUD/HealthBar
@onready var help_button: Button = $HUD/HelpButton
@onready var help_panel: PanelContainer = $HUD/HelpPanel
@onready var results_button: Button = $HUD/ResultsButton
@onready var result_panel: PanelContainer = $HUD/ResultPanel
@onready var result_title: Label = $HUD/ResultPanel/VBox/Title
@onready var result_body: Label = $HUD/ResultPanel/VBox/Body
@onready var tree_button: Button = $HUD/ResultPanel/VBox/TreeButton
@onready var retry_button: Button = $HUD/ResultPanel/VBox/RetryButton
@onready var ability_box: HBoxContainer = $HUD/AbilityBox


func _ready() -> void:
	Engine.time_scale = 1.0
	speed_button.pressed.connect(_on_speed)
	start_button.pressed.connect(_on_start_wave)
	help_button.pressed.connect(func() -> void: help_panel.visible = not help_panel.visible)
	$HUD/HelpPanel/VBox/CloseButton.pressed.connect(func() -> void: help_panel.visible = false)
	results_button.pressed.connect(func() -> void: result_panel.visible = not result_panel.visible)
	missile_button.pressed.connect(_on_missile_button)
	$HUD/CoachPanel/VBox/SkipButton.pressed.connect(_on_skip_tutorial)
	$HUD/ResultPanel/VBox/TreeButton.pressed.connect(_on_tree)
	$HUD/ResultPanel/VBox/RetryButton.pressed.connect(_on_retry)
	if Save.active_level == "":
		_start_run(Defs.level("T"), {}, Save.pending_layout if not Save.pending_layout.is_empty() else _dev_layout(), true)
	else:
		var data := Save.load_slot(Save.active_slot)
		_start_run(Defs.level(Save.active_level), (data["meta"] as Dictionary).get("tree", {}), Save.pending_layout, Save.active_level == "T")


func _dev_layout() -> Array:
	return [{"type": "gun", "x": 420.0, "y": 260.0, "aim": 0.0, "arc": TAU, "priority": "near"}]


func _start_run(p_def: Dictionary, p_tree: Dictionary, p_layout: Array, tutorial: bool) -> void:
	def = p_def
	tree = p_tree
	layout = p_layout
	is_tutorial = tutorial
	effects = Progression.effects(tree)
	base_max = int(def.get("base_hp", 20)) + int(effects["base_hp"]) - 20
	base_hp = base_max
	gold = 0 if is_tutorial else maxi(0, Save.pending_gold)
	if not is_tutorial and gold <= 0:
		gold = 400
	score = 0
	kills = 0
	var pts := PackedVector2Array(def["path"])
	var curve := Curve2D.new()
	for p in pts:
		curve.add_point(p)
	path.curve = curve
	road.points = curve.get_baked_points()
	horde.setup(pts)
	horde.died.connect(_on_died)
	horde.leaked.connect(_on_leaked)
	for spec in layout:
		var tower_type := String(spec.get("type", "gun"))
		if not Defs.TOWERS.has(tower_type):
			continue
		var t = TowerScript.new()
		t.setup(tower_type, Defs.TOWERS[tower_type], float(effects["damage_mult"].get(tower_type, 1.0)), float(effects["rate_mult"].get(tower_type, 1.0)), float(effects["range_mult"]), effects)
		t.position = Vector2(float(spec.get("x", 0.0)), float(spec.get("y", 0.0)))
		t.aim_angle = float(spec.get("aim", 0.0))
		t.arc = minf(float(spec.get("arc", TAU)), deg_to_rad(float(effects["cone_width"])))
		t.priority = String(spec.get("priority", "near"))
		towers_root.add_child(t)
	missile.horde = horde
	missile.cooldown = 0.5 if is_tutorial else float(effects["missile_cooldown"])
	missile.damage = 18.0 if is_tutorial else 60.0 * float(effects["missile_damage_mult"])
	missile.blast = 24.0 if is_tutorial else float(effects["missile_blast"])
	missile.auto_unlocked = bool(effects["auto"])
	missile.active = true
	missile.fired.connect(_on_fired)
	portal_visible = not is_tutorial
	_build_ability_buttons()
	if is_tutorial:
		state = "ready"
		coach_panel.visible = true
		start_button.visible = true
		tut_step = 0
		_say_hint("Tap once to reveal the enemy entrance. START WAVE still begins the attack.", 0)
	else:
		state = "battle"
	_update_hud()


func _build_ability_buttons() -> void:
	for child in ability_box.get_children():
		child.queue_free()
	ability_buttons.clear()
	for ability in ["strafe", "artillery", "orbital", "nuke"]:
		if not bool(effects["ability_unlocks"].get(ability, false)):
			continue
		var b := Button.new()
		b.text = ability.to_upper()
		b.custom_minimum_size = Vector2(112, 48)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_use_ability.bind(ability))
		ability_box.add_child(b)
		ability_buttons[ability] = b
		ability_cooldowns[ability] = 0.0


func _process(delta: float) -> void:
	queue_redraw()
	for ability in ability_cooldowns:
		ability_cooldowns[ability] = maxf(0.0, float(ability_cooldowns[ability]) - delta)
		var b: Button = ability_buttons.get(ability)
		if b != null:
			b.disabled = state != "battle" or float(ability_cooldowns[ability]) > 0.0
			if float(ability_cooldowns[ability]) > 0.0:
				b.text = "%s %.0f" % [String(ability).to_upper(), float(ability_cooldowns[ability])]
			else:
				b.text = String(ability).to_upper()
	if state != "battle":
		return
	time_s += delta
	_tick_spawner(delta)
	_tick_tutorial(delta)
	_update_hud()
	missile_label.text = "Missile READY — click" if missile.cd_left <= 0.0 else "Missile %.1fs" % missile.cd_left
	missile_button.text = ("AUTO ON" if missile.auto_on else "AUTO OFF") if missile.auto_unlocked else "MSL"


func _tick_spawner(delta: float) -> void:
	var waves: Array = def["waves"]
	if wave_idx < 0 or (spawn_left <= 0 and horde.count_alive() <= 0):
		if wave_idx + 1 >= waves.size():
			if wave_idx >= 0:
				_finish(false if is_tutorial else true)
			return
		next_timer -= delta
		if next_timer <= 0.0:
			wave_idx += 1
			var w: Dictionary = waves[wave_idx]
			spawn_left = int(w["n"])
			spawn_timer = 0.5
			_say("Wave %d/%d — %d orcs." % [wave_idx + 1, waves.size(), spawn_left])
		return
	if spawn_left > 0 and horde.count_alive() < horde.active_cap:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			var w: Dictionary = waves[wave_idx]
			spawn_timer = float(w.get("gap", 0.25))
			spawn_left -= 1
			horde.spawn_wave(1, float(w["hp"]), float(w["speed"]), 1, 1, String(w.get("enemy", "grunt")), bool(w.get("explosive", false)))


func _on_died(_reward: int) -> void:
	if state != "battle":
		return
	kills += 1
	gold += 10
	score += 10


func _on_leaked(_damage: int) -> void:
	if state != "battle":
		return
	base_hp -= 1
	Input.vibrate_handheld(40)
	if base_hp <= 0:
		base_hp = 0
		_finish(false)


func _finish(victory: bool) -> void:
	if state == "done":
		return
	state = "done"
	missile.active = false
	var kill_shards := int(floor(float(kills) / 10.0))
	var payout := int(floor(float(kill_shards) * float(effects["payout_mult"])))
	var flawless := victory and base_hp >= base_max
	var all_killed: bool = victory and horde.leaked_total == 0 and horde.spawned_total >= int(def.get("orcs", 0))
	var crystals := 1 + int(effects["crystal_gain"]) if flawless else 0
	var diamonds := 1 + int(effects["diamond_gain"]) if all_killed else 0
	result = {"victory": victory, "kills": kills, "shards": payout, "crystals": crystals, "diamonds": diamonds, "gold": gold, "score": score, "time": time_s, "flawless": flawless, "all_killed": all_killed}
	_persist()
	if victory:
		result_title.text = "LEVEL CLEAR"
	else:
		result_title.text = "OVERRUN" if not is_tutorial else "FIELD TEST LOST"
	tree_button.text = "UPGRADES"
	tree_button.visible = true
	retry_button.visible = not is_tutorial
	retry_button.text = "PLAY AGAIN"
	var rewards := []
	if payout > 0:
		rewards.append("+%d SHARDS" % payout)
	if crystals > 0:
		rewards.append("+%d CRYSTAL%s" % [crystals, "S" if crystals != 1 else ""])
	if diamonds > 0:
		rewards.append("+%d DIAMOND%s" % [diamonds, "S" if diamonds != 1 else ""])
	var reward_text := ", ".join(rewards) if not rewards.is_empty() else "No resource rewards"
	var run_summary := "Kills %d  |  Score %d" % [kills, score]
	if gold > 0:
		run_summary += "  |  Gold %d" % gold
	result_body.text = "%s\n%s" % [run_summary, reward_text]
	result_panel.visible = true
	results_button.visible = true
	_update_hud()


func _persist() -> void:
	if Save.active_slot < 0:
		return
	var data := Save.load_slot(Save.active_slot)
	var meta: Dictionary = data["meta"]
	var resources: Dictionary = meta.get("resources", {"shards": 0, "crystals": 0, "diamonds": 0})
	resources["shards"] = int(resources.get("shards", 0)) + int(result.get("shards", 0))
	resources["crystals"] = int(resources.get("crystals", 0)) + int(result.get("crystals", 0))
	resources["diamonds"] = int(resources.get("diamonds", 0)) + int(result.get("diamonds", 0))
	meta["resources"] = resources
	meta["shards"] = int(resources["shards"])
	meta["lifetime"] = int(meta.get("lifetime", 0)) + int(result.get("shards", 0))
	meta["last"] = Save.stamp()
	meta["current_level"] = String(def.get("id", "T"))
	if is_tutorial:
		meta["tut"] = true
		var tut_tree: Dictionary = meta.get("tree", {})
		if Progression.level(tut_tree, "gun") <= 0:
			tut_tree["gun"] = 1
			meta["tree"] = tut_tree
	var prog: Dictionary = data["progress"]
	var unlocked: Array = prog.get("unlocked", [])
	var lid := String(def.get("id", ""))
	if bool(result.get("victory", false)) or is_tutorial:
		for nxt in def.get("unlocks", []):
			if not unlocked.has(nxt):
				unlocked.append(nxt)
	var best: Dictionary = prog.get("best", {})
	var prev: Dictionary = best.get(lid, {})
	best[lid] = {"kills": maxi(int(prev.get("kills", 0)), kills), "clear": bool(prev.get("clear", false)) or bool(result.get("victory", false))}
	Save.write_slot(Save.active_slot, data)


func _on_start_wave() -> void:
	if state != "ready":
		return
	state = "battle"
	start_button.visible = false
	next_timer = 1.5
	if is_tutorial:
		tut_step = 2
		_say_hint("Good. Hold the line and keep firing.", 2)
	Input.vibrate_handheld(20)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_on_start_wave()
		get_viewport().set_input_as_handled()


func _on_speed() -> void:
	speed = 2.0 if speed < 2.0 else 1.0
	Engine.time_scale = speed
	speed_button.text = "2x" if speed > 1.0 else "1x"


func _on_tree() -> void:
	get_tree().change_scene_to_file("res://ui/skill_tree.tscn")


func _on_retry() -> void:
	Save.pending_gold = 0 if is_tutorial else 400
	Save.pending_layout = [] if is_tutorial else Save.pending_layout
	if is_tutorial:
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file("res://game/build_phase.tscn")


func _on_fired() -> void:
	if is_tutorial and tut_step == 0:
		portal_visible = true
		tut_step = 1
		tut_timer = 4.0
		_say_hint("Entrance revealed. Press START WAVE, then keep firing.", 1)
		queue_redraw()


func _on_skip_tutorial() -> void:
	if state != "battle" and state != "ready":
		return
	_finish(false)


func _on_missile_button() -> void:
	if not missile.auto_unlocked:
		_say("Unlock Automatic Missile in the War Room.")
		return
	var on: bool = missile.toggle_auto()
	_say("Automatic missile ON." if on else "Automatic missile OFF.")


func _use_ability(ability: String) -> void:
	if state != "battle" or float(ability_cooldowns.get(ability, 0.0)) > 0.0:
		return
	var point: Vector2 = missile.cross
	match ability:
		"strafe":
			var width := float(effects["ability_stats"]["strafe_width"])
			horde.damage_at(point, width, 85.0)
			ability_cooldowns[ability] = maxf(2.0, 8.0 - float(effects["ability_stats"]["strafe_rate"]))
		"artillery":
			var shells := int(effects["ability_stats"]["artillery_shells"])
			for i in shells:
				horde.damage_at(point + Vector2(randf_range(-70, 70), randf_range(-45, 45)), 58.0, 110.0)
			ability_cooldowns[ability] = 12.0
		"orbital":
			horde.damage_at(point, 48.0, 180.0 * float(effects["ability_stats"]["orbital_heat"]))
			ability_cooldowns[ability] = maxf(4.0, 14.0 - float(effects["ability_stats"]["orbital_hold"]))
		"nuke":
			horde.damage_at(point, float(effects["ability_stats"]["nuke_blast"]), 99999.0)
			ability_cooldowns[ability] = 30.0


func _tick_tutorial(delta: float) -> void:
	if not is_tutorial:
		return
	if tut_step == 1:
		tut_timer -= delta
		if tut_timer <= 0.0:
			tut_step = 3
			_say_hint("The wave is coming. Every ten kills earns a Shard.", 3)


func _say_hint(t: String, step := 0) -> void:
	coach_label.text = t
	if step > 0:
		coach_step.text = "%d / 3" % step


func _say(t: String) -> void:
	message_label.text = t


func _update_hud() -> void:
	wave_label.text = "Wave %d/%d" % [maxi(wave_idx + 1, 1), (def.get("waves", []) as Array).size()]
	hp_label.text = "Base %d/%d" % [base_hp, base_max]
	health_bar.max_value = base_max
	health_bar.value = base_hp
	shard_label.text = "SHARDS +%d" % int(floor(float(kills) / 10.0))
	gold_label.text = "GOLD %d" % gold
	score_label.text = "SCORE %d" % score
	kills_label.text = "KILLS %d" % kills
	if Save.active_slot >= 0:
		var data := Save.load_slot(Save.active_slot)
		var resources: Dictionary = (data["meta"] as Dictionary).get("resources", {})
		resource_label.text = "SHARD %d   CRYSTAL %d   DIAMOND %d" % [int(resources.get("shards", 0)), int(resources.get("crystals", 0)), int(resources.get("diamonds", 0))]


func _draw() -> void:
	draw_rect(Rect2(Vector2(-100, -100), Vector2(1500, 900)), Color("#5f963d"))
	var curve := path.curve
	if curve == null or curve.point_count <= 0:
		return
	var s: Vector2 = curve.get_point_position(0)
	var e: Vector2 = curve.get_point_position(curve.point_count - 1)
	if portal_visible:
		var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
		draw_colored_polygon([s + Vector2(-14, -34) * pulse, s + Vector2(14, -34) * pulse, s + Vector2(0, -8) * pulse], Color(1, 0.2, 0.2))
		draw_circle(s + Vector2(0, 2) * pulse, 7.0, Color(1, 0.2, 0.2))
		draw_circle(s + Vector2(0, 2) * pulse, 7.0, Color.WHITE, false, 2.0)
	for x in range(-24, 25, 12):
		for y in range(-24, 25, 12):
			if int(x / 12 + y / 12) % 2 == 0:
				draw_rect(Rect2(e + Vector2(x, y), Vector2(12, 12)), Color.WHITE)
