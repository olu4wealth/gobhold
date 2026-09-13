extends SceneTree

const Defs = preload("res://game/defs.gd")

var save: Node


func _initialize() -> void:
	save = root.get_node("Save")
	save.delete_slot(2)
	save.active_slot = -1
	var ui = (load("res://ui/skill_tree.tscn") as PackedScene).instantiate()
	root.add_child(ui)
	call_deferred("_check", ui)


func _check(ui: Control) -> void:
	ui._select_slot(2)
	var data: Dictionary = save.load_slot(2)
	var meta: Dictionary = data["meta"]
	var resources: Dictionary = meta["resources"]
	resources["shards"] = 100
	meta["resources"] = resources
	save.write_slot(2, data)
	ui._refresh_data()
	ui._open_node("weapon")
	ui._buy_selected()
	data = save.load_slot(2)
	assert(int((data["meta"] as Dictionary)["resources"]["shards"]) == 80)
	assert(int((data["meta"] as Dictionary)["tree"]["weapon"]) == 1)
	ui._open_levels()
	ui._show_stage_info(Defs.level("T"), true)
	ui.queue_free()
	save.delete_slot(2)
	save.active_slot = -1
	print("progression UI test passed")
	quit()
