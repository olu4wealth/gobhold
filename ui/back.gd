extends Button
## Generic back button: attach to any Button, set target scene in the editor.
@export var target := "res://ui/main_menu.tscn"


func _ready() -> void:
	pressed.connect(func() -> void: get_tree().change_scene_to_file(target))
