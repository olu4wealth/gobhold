extends SceneTree

const HordeScript = preload("res://core/horde.gd")


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var horde = HordeScript.new()
	root.add_child(horde)
	horde.setup(PackedVector2Array([Vector2.ZERO, Vector2(400, 0)]))
	horde.spawn_wave(3, 10.0, 0.0, 1, 1, "grunt", false)
	assert(horde.count_alive() == 3)
	horde.damage_piercing(0, 20.0, 3)
	assert(horde.count_alive() == 0)
	horde.spawn_wave(1, 100.0, 0.0, 1, 1, "explosive", true)
	assert(horde.enemy_type[0] == "explosive")
	horde.apply_slow(0, 0.5)
	assert(is_equal_approx(float(horde.slow_arr[0]), 0.5))
	horde.apply_mark(0, 1.25)
	assert(is_equal_approx(float(horde.mark_arr[0]), 1.25))
	horde.damage_single(0, 100.0)
	assert(horde.count_alive() == 0)
	print("runtime test passed")
	quit()
