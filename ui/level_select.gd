extends Control
## Level select: cards with orc count, difficulty and an info popup.
## Tutorial gate: only Field Test is open until it is done.

const Defs = preload("res://game/defs.gd")

@onready var _rows: VBoxContainer = $Center/VBox/Rows

var _info: AcceptDialog


func _ready() -> void:
	$Center/VBox/BackButton.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://ui/slot_select.tscn"))
	_info = AcceptDialog.new()
	add_child(_info)
	refresh()


func refresh() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var data := Save.load_slot(Save.active_slot)
	var meta: Dictionary = data["meta"]
	var unlocked: Array = (data["progress"] as Dictionary).get("unlocked", [])
	var tut_done := bool(meta.get("tut", false))
	for lv in Defs.LEVELS:
		var lid := String(lv["id"])
		var open := lid == "T" or (tut_done and (lid == "1.1" or unlocked.has(lid)))
		_rows.add_child(_make_card(lv, open, not tut_done and lid != "T"))


func _make_card(lv: Dictionary, open: bool, gated: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 120)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.15, 0.18, 1)
	style.border_color = Color(0.45, 0.5, 0.58, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	card.add_child(hb)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 24)
	if not open:
		title.text = "%s %s — %s" % [String(lv["id"]), String(lv["name"]), "finish Field Test" if gated else "clear prior level"]
	else:
		title.text = "%s %s" % [String(lv["id"]), String(lv["name"])]
	vb.add_child(title)
	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 1))
	sub.text = "%d orcs · %s" % [int(lv.get("orcs", 0)), String(lv.get("diff", ""))]
	vb.add_child(sub)
	var info_btn := Button.new()
	info_btn.text = "i"
	info_btn.custom_minimum_size = Vector2(56, 56)
	info_btn.add_theme_font_size_override("font_size", 22)
	info_btn.pressed.connect(_on_info.bind(lv))
	hb.add_child(info_btn)
	var play := Button.new()
	play.text = "PLAY"
	play.custom_minimum_size = Vector2(140, 80)
	play.add_theme_font_size_override("font_size", 24)
	play.disabled = not open
	play.pressed.connect(_on_play.bind(String(lv["id"])))
	hb.add_child(play)
	return card


func _on_info(lv: Dictionary) -> void:
	_info.dialog_text = "%s %s\n\n%s" % [String(lv["id"]), String(lv["name"]), String(lv.get("about", ""))]
	_info.popup_centered()


func _on_play(lid: String) -> void:
	Save.active_level = lid
	Save.pending_layout = []
	if lid == "T":
		get_tree().change_scene_to_file("res://game/combat.tscn")
	else:
		get_tree().change_scene_to_file("res://game/build_phase.tscn")
