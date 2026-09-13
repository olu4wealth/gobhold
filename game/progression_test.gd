extends SceneTree

const Progression = preload("res://game/progression.gd")


func _initialize() -> void:
	var tree: Dictionary = {"core": 1, "weapon": 1, "gun": 1, "gun_rate": 10, "gun_copy": 12, "missile_cd": 8, "ordnance": 1}
	var resources: Dictionary = {"shards": 10000, "crystals": 5, "diamonds": 3}
	assert(Progression.can_purchase(tree, resources, "gun_dmg"))
	assert(Progression.can_purchase(tree, resources, "auto"))
	assert(Progression.cost_for("gun_copy", 12)["shards"] >= 8000)
	assert(Progression.effects(tree)["copies"]["gun"] == 13)
	assert(Progression.effects(tree)["pierce"]["gun"] == 1)
	resources["shards"] = 0
	resources["crystals"] = 0
	assert(not Progression.can_purchase(tree, resources, "auto"))
	resources["shards"] = 10000
	assert(Progression.cost_for("auto", 0).has("shards"))
	assert(not Progression.cost_for("auto", 0).has("crystals"))
	var effects := Progression.effects(tree)
	assert(int(effects["copies"]["gun"]) == 13)
	assert(is_equal_approx(float(effects["missile_cooldown"]), 1.36))
	assert(Progression.state(tree, resources, "gun") == "maxed")
	assert(Progression.max_label(Progression.node("gun_dmg")) == "∞")
	print("progression test passed")
	quit()
