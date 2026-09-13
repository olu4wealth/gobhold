extends Control
## Gobhold main menu: pure router. Each item opens its own page.

func _ready() -> void:
	$Center/VBox/PlayButton.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://ui/skill_tree.tscn"))
	$Center/VBox/SettingsButton.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://ui/settings.tscn"))
	$Center/VBox/CreditsButton.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://ui/credits.tscn"))
	$Center/VBox/QuitButton.pressed.connect(func() -> void: get_tree().quit())
