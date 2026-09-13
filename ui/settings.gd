extends Control
## Settings page: volume + quality, persisted via Save.

@onready var _volume: HSlider = $Center/VBox/VolumeSlider
@onready var _quality: OptionButton = $Center/VBox/QualityOption


func _ready() -> void:
	for q in ["Low", "Medium", "High", "Auto"]:
		_quality.add_item(q)
	_quality.selected = int(Save.get_setting("quality", 3))
	_quality.item_selected.connect(_on_quality)
	_volume.value = float(Save.get_setting("volume", 1.0))
	_apply_volume(_volume.value)
	_volume.value_changed.connect(_on_volume)


func _on_volume(v: float) -> void:
	_apply_volume(v)
	Save.set_setting("volume", v)


func _apply_volume(v: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.001)) if v > 0.0 else -60.0)


func _on_quality(idx: int) -> void:
	Save.set_setting("quality", idx)
