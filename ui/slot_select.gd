extends Control
## Slot select: 3 square expedition cards. DELETE on top, state button
## at the bottom (EMPTY starts a new run, PLAY continues).

@onready var _cards: HBoxContainer = $Center/VBox/Cards

var _confirm: ConfirmationDialog


func _ready() -> void:
	$Center/VBox/BackButton.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://ui/main_menu.tscn"))
	_confirm = ConfirmationDialog.new()
	_confirm.dialog_text = "Delete this expedition?"
	_confirm.confirmed.connect(_on_confirm_delete)
	add_child(_confirm)
	refresh()


func refresh() -> void:
	for c in _cards.get_children():
		c.queue_free()
	for i in Save.SLOT_COUNT:
		_cards.add_child(_make_card(i))


func _make_card(i: int) -> PanelContainer:
	var s := Save.summary(i)
	var occupied := bool(s.get("exists", false))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(360, 360)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.15, 0.18, 1)
	style.border_color = Color(0.45, 0.5, 0.58, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	var delete := Button.new()
	delete.text = "DELETE SAVE"
	delete.add_theme_font_size_override("font_size", 18)
	delete.disabled = not occupied
	delete.pressed.connect(_on_delete.bind(i))
	vb.add_child(delete)
	var title := Label.new()
	title.text = "SLOT %d" % [i + 1]
	if Save.active_slot == i:
		title.text += " · ACTIVE"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var info := Label.new()
	info.add_theme_font_size_override("font_size", 20)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(320, 80)
	if occupied:
		info.text = "%s · %d shards\nEarned %d · %s" % [s.get("top", "-"), int(s.get("shards", 0)),
			int(s.get("lifetime", 0)), s.get("last", "—")]
	else:
		info.text = ""
	vb.add_child(info)
	var play := Button.new()
	play.text = "PLAY" if occupied else "EMPTY"
	play.custom_minimum_size = Vector2(320, 64)
	play.add_theme_font_size_override("font_size", 26)
	play.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play.pressed.connect(_on_play.bind(i))
	vb.add_child(play)
	return card


func _on_play(i: int) -> void:
	if not Save.slot_exists(i):
		Save.write_slot(i, Save.fresh_data())
	Save.active_slot = i
	var data := Save.load_slot(i)
	(data["meta"] as Dictionary)["last"] = Save.stamp()
	Save.write_slot(i, data)
	Save.active_level = ""
	Save.pending_layout = []
	if bool((data["meta"] as Dictionary).get("tut", false)):
		get_tree().change_scene_to_file("res://ui/skill_tree.tscn")
	else:
		Save.active_level = "T"
		get_tree().change_scene_to_file("res://game/combat.tscn")


func _on_delete(i: int) -> void:
	_confirm.set_meta("slot", i)
	_confirm.popup_centered()


func _on_confirm_delete() -> void:
	var i := int(_confirm.get_meta("slot", 0))
	Save.delete_slot(i)
	refresh()
