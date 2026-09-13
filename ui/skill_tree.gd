extends Control
## Progression shell: slot modal, radial tree, playable level modal and node details.

const Defs = preload("res://game/defs.gd")
const Progression = preload("res://game/progression.gd")
const NODE_SIZE := Vector2(84, 84)
const ZOOM_MIN := 0.62
const ZOOM_MAX := 1.35
const HOLD_TIME := 0.45

var _mode := "slots"
var _tree := {}
var _resources := {}
var _selected_node := ""
var _pan := Vector2.ZERO
var _zoom := 0.62
var _panning := false
var _last_pointer := Vector2.ZERO
var _pressed_node := ""
var _pressed_at := 0.0
var _hold_opened := false

var _node_buttons := {}
var _topbar: HBoxContainer
var _resource_labels := {}
var _backdrop: ColorRect
var _modal: PanelContainer
var _modal_title: Label
var _modal_body: VBoxContainer
var _tooltip: PanelContainer
var _tooltip_title: Label
var _tooltip_body: Label
var _status: Label
var _cheapest: Label
var _confirm: ConfirmationDialog
var _info: AcceptDialog


func _ready() -> void:
	set_process_input(true)
	_build_tree()
	_build_topbar()
	_build_tooltip()
	_build_bottom_ui()
	_build_backdrop()
	_build_modal()
	_confirm = ConfirmationDialog.new()
	_confirm.dialog_text = "Delete this expedition?"
	_confirm.confirmed.connect(_on_delete_confirmed)
	add_child(_confirm)
	_info = AcceptDialog.new()
	add_child(_info)
	_refresh_data()
	_open_tree() if Save.active_slot >= 0 else _open_slots()


func _refresh_data() -> void:
	var data := Save.fresh_data() if Save.active_slot < 0 else Save.load_slot(Save.active_slot)
	_tree = (data["meta"] as Dictionary).get("tree", {"core": 1})
	_resources = (data["meta"] as Dictionary).get("resources", {"shards": 0, "crystals": 0, "diamonds": 0})
	if not _tree.has("core"):
		_tree["core"] = 1
	for id in _resource_labels:
		(_resource_labels[id] as Label).text = "%s  %d" % [String(id).to_upper(), int(_resources.get(id, 0))]
	_refresh_nodes()


func _build_tree() -> void:
	for spec in Progression.NODES:
		var id := String(spec["id"])
		var b := Button.new()
		b.custom_minimum_size = NODE_SIZE
		b.size = NODE_SIZE
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 10)
		b.button_down.connect(_on_node_down.bind(id))
		b.button_up.connect(_on_node_up.bind(id))
		add_child(b)
		_node_buttons[id] = b
	_layout_nodes()


func _layout_nodes() -> void:
	var center := get_viewport_rect().size * 0.5 + _pan
	for spec in Progression.NODES:
		var id := String(spec["id"])
		var b: Button = _node_buttons.get(id)
		if b == null:
			continue
		var p: Vector2 = spec["position"]
		b.position = center + p * _zoom - NODE_SIZE * _zoom * 0.5
		b.scale = Vector2.ONE * _zoom
	queue_redraw()


func _refresh_nodes() -> void:
	for spec in Progression.NODES:
		var id := String(spec["id"])
		var b: Button = _node_buttons.get(id)
		if b == null:
			continue
		var state := Progression.state(_tree, _resources, id)
		var color: Color = Progression.color_for(String(spec["category"]))
		b.text = "%s\n%d/%s" % [String(spec["name"]), Progression.level(_tree, id), Progression.max_label(spec)]
		b.add_theme_stylebox_override("normal", _node_style(color, state))
		b.add_theme_stylebox_override("hover", _node_style(color, state, true))
		b.add_theme_stylebox_override("pressed", _node_style(color, state, true))
		b.modulate = Color.WHITE if state in ["maxed", "purchasable", "partial"] else Color(0.52, 0.56, 0.62)
		if id == Progression.cheapest_available(_tree, _resources):
			b.modulate = Color(1.0, 0.95, 0.55)
		b.tooltip_text = String(spec["desc"])
	_layout_nodes()
	if _selected_node != "":
		_show_node(_selected_node)
	if _cheapest != null:
		var cheapest := Progression.cheapest_available(_tree, _resources)
		_cheapest.text = "CHEAPEST AVAILABLE: %s" % String(Progression.node(cheapest).get("name", "NONE")) if cheapest != "" else "CHEAPEST AVAILABLE: earn more Shards"


func _node_style(color: Color, state: String, hovered := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.015, 0.025, 0.05, 0.94)
	sb.set_corner_radius_all(int(NODE_SIZE.x * 0.5))
	sb.set_border_width_all(3 if hovered else 2)
	var alpha := 0.95 if state == "maxed" or state == "purchasable" or state == "partial" else 0.42
	sb.border_color = Color(color.r, color.g, color.b, alpha)
	return sb


func _build_topbar() -> void:
	_topbar = HBoxContainer.new()
	_topbar.position = Vector2(18, 14)
	_topbar.size = Vector2(1244, 58)
	_topbar.add_theme_constant_override("separation", 14)
	_topbar.z_index = 5
	add_child(_topbar)
	var title := Label.new()
	title.text = "WAR ROOM"
	title.add_theme_font_size_override("font_size", 26)
	_topbar.add_child(title)
	for id in ["shards", "crystals", "diamonds"]:
		var label := Label.new()
		label.text = "%s  0" % String(id).to_upper()
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Progression.color_for("weapon") if id == "shards" else (Progression.color_for("ability") if id == "crystals" else Progression.color_for("enemy")))
		_resource_labels[id] = label
		_topbar.add_child(label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_topbar.add_child(spacer)
	var slots := _make_button("SLOTS", Vector2(118, 48), 18)
	slots.pressed.connect(_open_slots)
	_topbar.add_child(slots)
	var levels := _make_button("LEVELS", Vector2(126, 48), 18)
	levels.pressed.connect(_open_levels)
	_topbar.add_child(levels)


func _build_bottom_ui() -> void:
	var legend := PanelContainer.new()
	legend.position = Vector2(18, 610)
	legend.size = Vector2(190, 88)
	legend.z_index = 5
	add_child(legend)
	var legend_text := Label.new()
	legend_text.text = "DRAG  Pan Camera\nWHEEL  Zoom\nHOLD  Preview | TAP  Buy"
	legend_text.add_theme_font_size_override("font_size", 12)
	legend.add_child(legend_text)
	var play := _make_button("PLAY", Vector2(150, 62), 22)
	play.position = Vector2(1112, 642)
	play.z_index = 5
	play.pressed.connect(_open_levels)
	add_child(play)
	_status = Label.new()
	_status.position = Vector2(230, 672)
	_status.size = Vector2(650, 32)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 14)
	_status.z_index = 5
	add_child(_status)
	_cheapest = Label.new()
	_cheapest.position = Vector2(230, 635)
	_cheapest.size = Vector2(650, 32)
	_cheapest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cheapest.add_theme_font_size_override("font_size", 12)
	_cheapest.z_index = 5
	add_child(_cheapest)


func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.position = Vector2(430, 106)
	_tooltip.size = Vector2(340, 145)
	_tooltip.z_index = 6
	_tooltip.visible = false
	add_child(_tooltip)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_tooltip.add_child(vb)
	_tooltip_title = Label.new()
	_tooltip_title.add_theme_font_size_override("font_size", 18)
	vb.add_child(_tooltip_title)
	_tooltip_body = Label.new()
	_tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_tooltip_body)


func _build_backdrop() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.z_index = 10
	var shader := load("res://ui/modal_blur.gdshader") as Shader
	var blur_material := ShaderMaterial.new()
	blur_material.shader = shader
	_backdrop.material = blur_material
	_backdrop.visible = false
	add_child(_backdrop)


func _build_modal() -> void:
	_modal = PanelContainer.new()
	_modal.set_anchors_preset(Control.PRESET_CENTER)
	_modal.offset_left = -470.0
	_modal.offset_top = -285.0
	_modal.offset_right = 470.0
	_modal.offset_bottom = 285.0
	_modal.z_index = 11
	_modal.visible = false
	var modal_style := StyleBoxFlat.new()
	modal_style.bg_color = Color("#111827")
	modal_style.border_color = Color("#4b5563")
	modal_style.set_border_width_all(2)
	modal_style.set_corner_radius_all(10)
	_modal.add_theme_stylebox_override("panel", modal_style)
	add_child(_modal)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	_modal.add_child(margin)
	_modal_body = VBoxContainer.new()
	_modal_body.add_theme_constant_override("separation", 10)
	margin.add_child(_modal_body)
	_modal_title = Label.new()
	_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_title.add_theme_font_size_override("font_size", 28)
	_modal_body.add_child(_modal_title)


func _show_modal(title: String, height: float) -> void:
	_modal_title.text = title
	_modal.offset_top = -height * 0.5
	_modal.offset_bottom = height * 0.5
	for child in _modal_body.get_children():
		if child != _modal_title:
			child.queue_free()
	_modal.visible = true
	_backdrop.visible = true
	_tooltip.visible = false


func _open_slots() -> void:
	_mode = "slots"
	_show_modal("CHOOSE AN EXPEDITION", 430.0)
	var note := Label.new()
	note.text = "Select a save to continue. Empty slots create a new progression state."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 14)
	_modal_body.add_child(note)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 14)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_body.add_child(cards)
	for i in Save.SLOT_COUNT:
		cards.add_child(_slot_card(i))
	var close := _make_button("CLOSE", Vector2(180, 44), 18)
	close.pressed.connect(_open_tree)
	_modal_body.add_child(close)


func _slot_card(i: int) -> PanelContainer:
	var s := Save.summary(i)
	var occupied := bool(s.get("exists", false))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(265, 245)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	margin.add_child(vb)
	var title := Label.new()
	title.text = "Slot #%d" % [i + 1]
	title.add_theme_font_size_override("font_size", 20)
	vb.add_child(title)
	var details := Label.new()
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if occupied:
			details.text = "Current Level   %s\nShards          %d\nCrystals         %d\nDiamonds         %d\nEarned           %d\nLast Played      %s%s" % [
			String(s.get("level", "T")), int(s.get("shards", 0)), int(s.get("crystals", 0)), int(s.get("diamonds", 0)),
			int(s.get("lifetime", 0)), String(s.get("last", "—")), "\n\nACTIVE" if Save.active_slot == i else ""]
	else:
		details.text = "\nEmpty\n\nCreate a new expedition."
	vb.add_child(details)
	var select := _make_button("CONTINUE" if occupied else "CREATE", Vector2(0, 44), 16)
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.pressed.connect(_select_slot.bind(i))
	vb.add_child(select)
	if occupied:
		var delete := _make_button("DELETE", Vector2(0, 30), 13)
		delete.pressed.connect(_confirm_delete.bind(i))
		vb.add_child(delete)
	return card


func _select_slot(i: int) -> void:
	var created := not Save.slot_exists(i)
	if created:
		Save.write_slot(i, Save.fresh_data())
	Save.active_slot = i
	var data := Save.load_slot(i)
	var meta: Dictionary = data["meta"]
	meta["last"] = Save.stamp()
	Save.write_slot(i, data)
	_refresh_data()
	if created:
		Save.active_level = "T"
		Save.pending_layout = []
		Save.pending_gold = 0
		get_tree().change_scene_to_file("res://game/combat.tscn")
	elif String(meta.get("current_level", "T")) == "T" and not bool(meta.get("tut", false)):
		Save.active_level = "T"
		Save.pending_layout = []
		get_tree().change_scene_to_file("res://game/combat.tscn")
	else:
		_open_tree()


func _confirm_delete(i: int) -> void:
	_confirm.set_meta("slot", i)
	_confirm.popup_centered()


func _on_delete_confirmed() -> void:
	var i := int(_confirm.get_meta("slot", -1))
	if i >= 0:
		Save.delete_slot(i)
		if Save.active_slot == i:
			Save.active_slot = -1
		_refresh_data()
		_open_slots()


func _open_tree() -> void:
	_mode = "tree"
	_modal.visible = false
	_backdrop.visible = false
	_refresh_data()
	if Save.active_slot < 0:
		_open_slots()
	else:
		var data := Save.load_slot(Save.active_slot)
		var meta: Dictionary = data["meta"]
		if bool(meta.get("tut", false)) and Progression.level(_tree, "gun") == 0:
			_info.dialog_text = "FIELD TEST COMPLETE\n\nShards buy repeatable stat upgrades. Crystals unlock new weapons and deep active skills. Diamonds unlock enemy effects.\n\nGUNNER is your first free skill. Buy it, then press PLAY to enter Level 1.1."
			_info.popup_centered()


func _open_node(id: String) -> void:
	_selected_node = id
	_show_node(id)


func _show_node(id: String) -> void:
	var spec := Progression.node(id)
	if spec.is_empty():
		return
	var current := Progression.level(_tree, id)
	var state := Progression.state(_tree, _resources, id)
	var cost := Progression.cost_for(id, current)
	_tooltip_title.text = "%s   %d/%s" % [String(spec["name"]), current, Progression.max_label(spec)]
	_tooltip_body.text = "%s\n\nEffect: %s\nCost: %s\nStatus: %s" % [String(spec["desc"]), Progression.effect_text(spec), Progression.cost_text(cost), state.replace("_", " ").to_upper()]
	if not Progression.requirements_met(_tree, spec):
		_tooltip_body.text += "\nRequires: " + ", ".join(spec.get("needs", []))
	_tooltip.visible = _mode == "tree"
	var button: Button = _node_buttons.get(id)
	if button != null:
		_tooltip.position = Vector2(clampf(button.position.x + NODE_SIZE.x + 12.0, 8.0, size.x - _tooltip.size.x - 8.0), clampf(button.position.y, 82.0, size.y - _tooltip.size.y - 20.0))


func _on_node_down(id: String) -> void:
	_pressed_node = id
	_pressed_at = Time.get_ticks_msec() / 1000.0
	_hold_opened = false


func _on_node_up(id: String) -> void:
	if id != _pressed_node:
		return
	var was_hold := _hold_opened
	_pressed_node = ""
	_hold_opened = false
	if was_hold:
		_selected_node = ""
		_tooltip.visible = false
		return
	_selected_node = id
	if not _buy_selected():
		_status.text = "Hold to inspect requirements."
	_selected_node = ""
	_tooltip.visible = false


func _process(_delta: float) -> void:
	if _pressed_node == "" or _hold_opened:
		return
	if Time.get_ticks_msec() / 1000.0 - _pressed_at < HOLD_TIME:
		return
	_hold_opened = true
	_selected_node = _pressed_node
	_show_node(_pressed_node)


func _buy_selected() -> bool:
	if _selected_node == "" or Save.active_slot < 0:
		return false
	if not Progression.can_purchase(_tree, _resources, _selected_node):
		return false
	var data := Save.load_slot(Save.active_slot)
	var meta: Dictionary = data["meta"]
	var resources: Dictionary = meta.get("resources", {})
	var tree: Dictionary = meta.get("tree", {})
	var current := Progression.level(tree, _selected_node)
	var cost := Progression.cost_for(_selected_node, current)
	for resource in cost:
		resources[String(resource)] = int(resources.get(String(resource), 0)) - int(cost[resource])
	meta["resources"] = resources
	meta["shards"] = int(resources.get("shards", 0))
	tree[_selected_node] = current + 1
	meta["tree"] = tree
	Save.write_slot(Save.active_slot, data)
	_resources = resources
	_tree = tree
	_status.text = "%s upgraded." % String(Progression.node(_selected_node)["name"])
	_selected_node = ""
	_refresh_data()
	return true


func _open_levels() -> void:
	if Save.active_slot < 0:
		_open_slots()
		return
	_mode = "levels"
	_show_modal("LEVELS", 610.0)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(850, 465)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_body.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var data := Save.load_slot(Save.active_slot)
	var unlocked: Array = (data["progress"] as Dictionary).get("unlocked", [])
	for stage in Defs.LEVELS:
		if bool(stage.get("tutorial", false)):
			continue
		rows.add_child(_stage_card(stage, unlocked))
	var back := _make_button("BACK TO TREE", Vector2(220, 44), 18)
	back.pressed.connect(_open_tree)
	_modal_body.add_child(back)


func _stage_card(stage: Dictionary, unlocked: Array) -> PanelContainer:
	var id := String(stage["id"])
	var open := unlocked.has(id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(820, 92)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	card.add_child(hb)
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(140, 76)
	var preview_label := Label.new()
	preview_label.text = String(stage.get("preview", id)) + ("\nLOCKED" if not open else "")
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_label.add_theme_font_size_override("font_size", 14)
	preview.add_child(preview_label)
	hb.add_child(preview)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "%s   %s" % [id, String(stage["name"])]
	title.add_theme_font_size_override("font_size", 18)
	body.add_child(title)
	var stats := Label.new()
	stats.text = "%d orcs   |   %s   |   1 Shard / 10 kills   |   Perfect clear: Crystal" % [int(stage.get("orcs", 0)), String(stage.get("diff", ""))]
	stats.add_theme_font_size_override("font_size", 13)
	body.add_child(stats)
	hb.add_child(body)
	var info := _make_button("i", Vector2(42, 42), 18)
	info.pressed.connect(_show_stage_info.bind(stage, open))
	hb.add_child(info)
	var play := _make_button("PLAY", Vector2(112, 60), 18)
	play.disabled = not open
	play.pressed.connect(_play_stage.bind(id))
	hb.add_child(play)
	return card


func _show_stage_info(stage: Dictionary, open: bool) -> void:
	_info.dialog_text = "%s %s\n\n%s\n\nStatus: %s\nReward: 1 Shard / 10 kills%s" % [
		String(stage["id"]), String(stage["name"]), String(stage.get("about", "")), "OPEN" if open else "LOCKED",
		" + 1 Crystal if flawless; + 1 Diamond if all enemies fall" if open else ""]
	_info.popup_centered()


func _play_stage(id: String) -> void:
	Save.active_level = id
	Save.pending_layout = []
	Save.pending_gold = 400
	var data := Save.load_slot(Save.active_slot)
	var meta: Dictionary = data["meta"]
	meta["current_level"] = id
	meta["last"] = Save.stamp()
	Save.write_slot(Save.active_slot, data)
	if id == "T":
		get_tree().change_scene_to_file("res://game/combat.tscn")
	else:
		get_tree().change_scene_to_file("res://game/build_phase.tscn")


func _make_button(text: String, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _input(event: InputEvent) -> void:
	if _mode != "tree":
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = minf(ZOOM_MAX, _zoom + 0.08)
			_layout_nodes()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = maxf(ZOOM_MIN, _zoom - 0.08)
			_layout_nodes()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var hovered := get_viewport().gui_get_hovered_control()
				_panning = not (hovered is Button or hovered is PanelContainer)
				_last_pointer = event.position
			else:
				_panning = false
	elif event is InputEventMouseMotion and _panning:
		_pan += event.position - _last_pointer
		_last_pointer = event.position
		_layout_nodes()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_panning = true
			_last_pointer = event.position
		else:
			_panning = false
	elif event is InputEventScreenDrag and _panning:
		_pan += event.position - _last_pointer
		_last_pointer = event.position
		_layout_nodes()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_nodes()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#05070c"))
	var center := get_viewport_rect().size * 0.5 + _pan
	for spec in Progression.NODES:
		var to: Vector2 = center + (spec["position"] as Vector2) * _zoom
		for need in spec.get("needs", []):
			var parent := Progression.node(String(need))
			if parent.is_empty():
				continue
			var from: Vector2 = center + (parent["position"] as Vector2) * _zoom
			var color: Color = Progression.color_for(String(spec["category"]))
			var lit := Progression.level(_tree, String(need)) > 0
			var line_color := Color(color.r, color.g, color.b, 0.9 if lit else 0.25)
			draw_line(from, to, line_color, 3.0 if lit else 1.5)
	for category in ["weapon", "offense", "ability", "defense", "utility", "enemy"]:
		var label_pos := center + _category_position(category) * _zoom
		draw_string(ThemeDB.fallback_font, label_pos, category.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.55, 0.62, 0.72, 0.8))


func _category_position(category: String) -> Vector2:
	match category:
		"weapon": return Vector2(-630, -385)
		"offense": return Vector2(520, -385)
		"ability": return Vector2(530, 390)
		"defense": return Vector2(-410, 500)
		"utility": return Vector2(-90, -570)
	return Vector2.ZERO
