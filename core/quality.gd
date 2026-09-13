extends Node
class_name GobQuality
## Adaptive quality scaler (GDD 9.2 order): particles -> resolution ->
## physics -> entity cap. 2s EMA window. Attach once in main.tscn.
## ponytail: cap-only + flash-flag now; resolution/physics hooks when
## mid-tier frame time exceeds 16ms in profiler.

var tier := "Mid"
var _ema := 16.0
var _timer := 0.0
var _horde = null


func _ready() -> void:
	_horde = get_tree().get_first_node_in_group("horde")


func _process(delta: float) -> void:
	_ema = lerpf(_ema, delta * 1000.0, 0.05)
	_timer += delta
	if _timer < 2.0:
		return
	_timer = 0.0
	if _horde == null:
		_horde = get_tree().get_first_node_in_group("horde")
		if _horde == null:
			return
	if _ema > 24.0 and _horde.active_cap > 150:
		_horde.active_cap = maxi(150, _horde.active_cap - 100)
		tier = "Low"
	elif _ema < 14.0 and _horde.active_cap < 500:
		_horde.active_cap = mini(500, _horde.active_cap + 100)
		tier = "Mid" if _horde.active_cap < 500 else "High"
