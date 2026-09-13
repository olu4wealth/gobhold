extends SceneTree


func _initialize() -> void:
	var build := (load("res://game/build_phase.tscn") as PackedScene).instantiate()
	root.add_child(build)
	call_deferred("_check", build)


func _check(build: Node) -> void:
	assert(build._placement_error(Vector2(600.0, 80.0), null) == "")
	assert(build._placement_error(Vector2(600.0, 540.0), null).begins_with("Blocked: place"))
	build.queue_free()
	print("placement test passed")
	quit()
