extends RefCounted
## Flat incremental progression rules shared by the tree, build phase, and combat.

const COST_GROWTH := 1.5515

const CATEGORY_COLORS := {
	"core": Color("#e9c46a"),
	"weapon": Color("#39a9ff"),
	"offense": Color("#f28f3b"),
	"ability": Color("#f04f9d"),
	"defense": Color("#55d6d0"),
	"utility": Color("#a77bff"),
	"enemy": Color("#ef476f"),
}

# Most nodes are intentionally repeatable. Unlock nodes are finite and use a
# separate currency gate; their stat children share the same price curve.
const NODES := [
	{"id": "core", "name": "CORE", "category": "core", "position": Vector2(0, 0), "desc": "Command core. Every upgrade starts here.", "max": 1, "costs": [{}], "needs": [], "effect": {"kind": "none"}},
	{"id": "weapon", "name": "WEAPONS", "category": "weapon", "position": Vector2(-240, -20), "desc": "Open the weapon catalog.", "max": 1, "costs": [{"shards": 20}], "needs": ["core"], "effect": {"kind": "none"}},
	{"id": "tower_count", "name": "TOWER COUNT", "category": "utility", "position": Vector2(-240, 170), "desc": "Raise the hard deployment cap by one tower.", "max": -1, "base_cost": 70, "currency": "shards", "needs": ["core"], "effect": {"kind": "tower_count", "amount": 1}},
	{"id": "cone", "name": "NARROWING CONE", "category": "utility", "position": Vector2(-240, 360), "desc": "Focus projectile towers down the lane by narrowing their legal firing arc.", "max": -1, "base_cost": 85, "currency": "shards", "needs": ["core"], "effect": {"kind": "cone", "amount": 15.0}},

	{"id": "scrapper", "name": "SCRAPPER", "category": "weapon", "position": Vector2(-470, -150), "desc": "Cheap rapid-fire starter weapon.", "max": 1, "costs": [{"shards": 30}], "needs": ["weapon"], "effect": {"kind": "tower_copies", "tower": "scrapper", "amount": 1}},
	{"id": "scrapper_dmg", "name": "SCRAP DAMAGE", "category": "offense", "position": Vector2(-690, -230), "desc": "Repeatable Scrapper damage.", "max": -1, "base_cost": 55, "currency": "shards", "needs": ["scrapper"], "effect": {"kind": "damage", "tower": "scrapper", "amount": 0.05}},
	{"id": "scrapper_rate", "name": "SCRAP RATE", "category": "offense", "position": Vector2(-690, -80), "desc": "Repeatable Scrapper fire rate.", "max": -1, "base_cost": 60, "currency": "shards", "needs": ["scrapper"], "effect": {"kind": "rate", "tower": "scrapper", "amount": 0.05}},

	{"id": "gun", "name": "GUNNER", "category": "weapon", "position": Vector2(-470, 40), "desc": "Free first weapon. Reliable direct-fire coverage.", "max": 1, "costs": [{}], "needs": ["core"], "effect": {"kind": "tower_copies", "tower": "gun", "amount": 1}},
	{"id": "gun_copy", "name": "MORE GUNNERS", "category": "utility", "position": Vector2(-690, 110), "desc": "Add one legal Gunner placement. Level 13 is the major coverage breakpoint.", "max": -1, "base_cost": 42, "currency": "shards", "needs": ["gun"], "effect": {"kind": "tower_copies", "tower": "gun", "amount": 1}},
	{"id": "gun_dmg", "name": "GUNNER DAMAGE", "category": "offense", "position": Vector2(-690, 250), "desc": "Repeatable flat percentage damage increase.", "max": -1, "base_cost": 65, "currency": "shards", "needs": ["gun"], "effect": {"kind": "damage", "tower": "gun", "amount": 0.05}},
	{"id": "gun_rate", "name": "GUNNER FIRE RATE", "category": "offense", "position": Vector2(-470, 340), "desc": "Repeatable percentage fire-rate increase.", "max": -1, "base_cost": 70, "currency": "shards", "needs": ["gun"], "effect": {"kind": "rate", "tower": "gun", "amount": 0.05}},
	{"id": "gun_range", "name": "GUNNER RANGE", "category": "offense", "position": Vector2(-250, 300), "desc": "Repeatable Gunner attack range.", "max": -1, "base_cost": 70, "currency": "shards", "needs": ["gun"], "effect": {"kind": "tower_range", "tower": "gun", "amount": 0.04}},
	{"id": "gun_pierce", "name": "PIERCING", "category": "offense", "position": Vector2(-80, 400), "desc": "Projectile breakthrough. Levels 2, 3, and 4 allow 3, 4, and 5 sequential orc hits.", "max": 4, "base_cost": 160, "currency": "shards", "needs": ["gun"], "effect": {"kind": "pierce", "tower": "gun", "amount": 1}},
	{"id": "rapid_fire", "name": "RAPID FIRE BREAKTHROUGH", "category": "offense", "position": Vector2(-20, 520), "desc": "A high-level breakpoint that adds five shots per second to Gunners.", "max": 1, "costs": [{"crystals": 5}], "needs": ["gun_rate"], "requires_level": {"gun_rate": 10}, "effect": {"kind": "rate_add", "tower": "gun", "amount": 5.0}},

	{"id": "mortar", "name": "MORTAR", "category": "weapon", "position": Vector2(-20, -180), "desc": "Heavy explosive shells for dense lanes.", "max": 1, "costs": [{"crystals": 2}], "needs": ["weapon"], "effect": {"kind": "tower_copies", "tower": "mortar", "amount": 1}},
	{"id": "mortar_dmg", "name": "MORTAR OOMPH", "category": "offense", "position": Vector2(160, -300), "desc": "Repeatable Mortar explosion damage.", "max": -1, "base_cost": 110, "currency": "shards", "needs": ["mortar"], "effect": {"kind": "damage", "tower": "mortar", "amount": 0.08}},
	{"id": "mortar_blast", "name": "MORTAR BLAST", "category": "offense", "position": Vector2(340, -270), "desc": "Repeatable Mortar blast radius.", "max": -1, "base_cost": 120, "currency": "shards", "needs": ["mortar"], "effect": {"kind": "aoe", "tower": "mortar", "amount": 8.0}},
	{"id": "mortar_count", "name": "MORE MORTARS", "category": "utility", "position": Vector2(500, -200), "desc": "Add another Mortar placement.", "max": -1, "base_cost": 180, "currency": "shards", "needs": ["mortar"], "effect": {"kind": "tower_copies", "tower": "mortar", "amount": 1}},

	{"id": "flame", "name": "FLAMETHROWER", "category": "weapon", "position": Vector2(40, 20), "desc": "Short-range cone of continuous burn.", "max": 1, "costs": [{"crystals": 3}], "needs": ["weapon"], "effect": {"kind": "tower_copies", "tower": "flame", "amount": 1}},
	{"id": "flame_dmg", "name": "BURN DAMAGE", "category": "offense", "position": Vector2(200, 80), "desc": "Repeatable burn damage.", "max": -1, "base_cost": 115, "currency": "shards", "needs": ["flame"], "effect": {"kind": "damage", "tower": "flame", "amount": 0.06}},
	{"id": "flame_duration", "name": "BURN DURATION", "category": "offense", "position": Vector2(380, 100), "desc": "Keep damage-over-time effects on orcs longer.", "max": -1, "base_cost": 130, "currency": "shards", "needs": ["flame"], "effect": {"kind": "burn_duration", "amount": 0.25}},
	{"id": "flame_stack", "name": "MULTI-BURN", "category": "offense", "position": Vector2(540, 160), "desc": "Raise the number of simultaneous burn stacks.", "max": -1, "base_cost": 145, "currency": "shards", "needs": ["flame"], "effect": {"kind": "burn_stacks", "amount": 1}},

	{"id": "grenade", "name": "GRENADE", "category": "weapon", "position": Vector2(250, 20), "desc": "Impact shells that bounce and amplify damage taken.", "max": 1, "costs": [{"crystals": 4}], "needs": ["weapon"], "effect": {"kind": "tower_copies", "tower": "grenade", "amount": 1}},
	{"id": "grenade_dmg", "name": "GRENADE IMPACT", "category": "offense", "position": Vector2(420, 30), "desc": "Repeatable impact damage.", "max": -1, "base_cost": 140, "currency": "shards", "needs": ["grenade"], "effect": {"kind": "damage", "tower": "grenade", "amount": 0.08}},
	{"id": "grenade_bounce", "name": "WALL BOUNCE", "category": "offense", "position": Vector2(590, 30), "desc": "Add another grenade bounce.", "max": -1, "base_cost": 160, "currency": "shards", "needs": ["grenade"], "effect": {"kind": "bounces", "tower": "grenade", "amount": 1}},
	{"id": "grenade_debuff", "name": "SHATTER MARK", "category": "offense", "position": Vector2(740, 80), "desc": "Marked orcs take more damage from your other towers.", "max": -1, "base_cost": 190, "currency": "shards", "needs": ["grenade"], "effect": {"kind": "debuff", "amount": 0.05}},

	{"id": "tesla", "name": "TESLA", "category": "weapon", "position": Vector2(250, 190), "desc": "Chain lightning that cleans up weakened targets.", "max": 1, "costs": [{"crystals": 5}], "needs": ["weapon"], "effect": {"kind": "tower_copies", "tower": "tesla", "amount": 1}},
	{"id": "tesla_chain", "name": "CHAIN BOUNCES", "category": "offense", "position": Vector2(430, 230), "desc": "Add another lightning target.", "max": -1, "base_cost": 180, "currency": "shards", "needs": ["tesla"], "effect": {"kind": "chain", "tower": "tesla", "amount": 1}},
	{"id": "tesla_execute", "name": "EXECUTION", "category": "offense", "position": Vector2(600, 250), "desc": "Execute orcs below a percentage health threshold.", "max": -1, "base_cost": 220, "currency": "shards", "needs": ["tesla"], "effect": {"kind": "execute", "amount": 0.03}},

	{"id": "cryo", "name": "CRYOBEAM", "category": "weapon", "position": Vector2(250, 360), "desc": "Slow the horde inside kill zones.", "max": 1, "costs": [{"crystals": 4}], "needs": ["weapon"], "effect": {"kind": "tower_copies", "tower": "cryo", "amount": 1}},
	{"id": "cryo_slow", "name": "DEEP FREEZE", "category": "offense", "position": Vector2(430, 400), "desc": "Increase CryoBeam movement-speed reduction.", "max": -1, "base_cost": 160, "currency": "shards", "needs": ["cryo"], "effect": {"kind": "slow", "amount": 0.04}},
	{"id": "laser", "name": "LASER", "category": "weapon", "position": Vector2(250, 530), "desc": "Continuous beam with line penetration.", "max": 1, "costs": [{"crystals": 6}], "needs": ["weapon"], "effect": {"kind": "tower_copies", "tower": "laser", "amount": 1}},
	{"id": "laser_beam", "name": "BEAM MELT", "category": "offense", "position": Vector2(430, 560), "desc": "Increase continuous beam damage ticks.", "max": -1, "base_cost": 210, "currency": "shards", "needs": ["laser"], "effect": {"kind": "beam", "amount": 0.08}},
	{"id": "laser_falloff", "name": "PIERCING FALLoff", "category": "offense", "position": Vector2(620, 560), "desc": "Reduce line-penetration damage falloff.", "max": -1, "base_cost": 230, "currency": "shards", "needs": ["laser"], "effect": {"kind": "falloff", "amount": 0.08}},

	{"id": "ordnance", "name": "ORDNANCE", "category": "ability", "position": Vector2(40, -410), "desc": "Commander weapons and cursor-directed support.", "max": 1, "costs": [{"shards": 20}], "needs": ["core"], "effect": {"kind": "none"}},
	{"id": "missile_cd", "name": "FAST FUSE", "category": "ability", "position": Vector2(230, -500), "desc": "Reduce manual missile cooldown.", "max": -1, "base_cost": 75, "currency": "shards", "needs": ["ordnance"], "effect": {"kind": "missile_cd", "amount": 0.04}},
	{"id": "missile_dmg", "name": "BIG WARHEAD", "category": "ability", "position": Vector2(420, -500), "desc": "Increase missile damage.", "max": -1, "base_cost": 110, "currency": "shards", "needs": ["ordnance"], "effect": {"kind": "missile_damage", "amount": 0.08}},
	{"id": "missile_blast", "name": "WIDE BLAST", "category": "ability", "position": Vector2(610, -500), "desc": "Increase missile impact radius.", "max": -1, "base_cost": 100, "currency": "shards", "needs": ["ordnance"], "effect": {"kind": "missile_blast", "amount": 6.0}},
	{"id": "auto", "name": "AUTOMATIC MISSILE", "category": "ability", "position": Vector2(790, -430), "desc": "A milestone that fires emergency rockets automatically at the cursor.", "max": 1, "costs": [{"shards": 150}], "needs": ["missile_cd"], "requires_level": {"missile_cd": 8}, "effect": {"kind": "auto"}},
	{"id": "strafe", "name": "STRAFING RUN", "category": "ability", "position": Vector2(230, -340), "desc": "Aerial sweep across the cursor lane.", "max": 1, "costs": [{"crystals": 8}], "needs": ["ordnance"], "effect": {"kind": "ability_unlock", "ability": "strafe"}},
	{"id": "strafe_width", "name": "SWEEP WIDTH", "category": "ability", "position": Vector2(420, -330), "desc": "Increase aerial sweep width.", "max": -1, "base_cost": 250, "currency": "shards", "needs": ["strafe"], "effect": {"kind": "ability_stat", "ability": "strafe_width", "amount": 12.0}},
	{"id": "strafe_bombs", "name": "BOMB COUNT", "category": "ability", "position": Vector2(610, -330), "desc": "Drop more bombs during each sweep.", "max": -1, "base_cost": 280, "currency": "shards", "needs": ["strafe"], "effect": {"kind": "ability_stat", "ability": "strafe_bombs", "amount": 1}},
	{"id": "strafe_rate", "name": "STRAFE FREQUENCY", "category": "ability", "position": Vector2(800, -300), "desc": "Reduce the support-run cooldown.", "max": -1, "base_cost": 300, "currency": "shards", "needs": ["strafe"], "effect": {"kind": "ability_stat", "ability": "strafe_rate", "amount": 0.08}},
	{"id": "artillery", "name": "ARTILLERY", "category": "ability", "position": Vector2(230, -160), "desc": "Call heavy shells onto a cursor-directed choke point.", "max": 1, "costs": [{"crystals": 10}], "needs": ["ordnance"], "effect": {"kind": "ability_unlock", "ability": "artillery"}},
	{"id": "artillery_shells", "name": "HEAVY SHELLS", "category": "ability", "position": Vector2(430, -140), "desc": "Rain more shells per artillery call.", "max": -1, "base_cost": 320, "currency": "shards", "needs": ["artillery"], "effect": {"kind": "ability_stat", "ability": "artillery_shells", "amount": 1}},
	{"id": "orbital", "name": "ORBITAL LASER", "category": "ability", "position": Vector2(620, -120), "desc": "Hold a beam on a cursor target until heat runs out.", "max": 1, "costs": [{"crystals": 12}], "needs": ["ordnance"], "effect": {"kind": "ability_unlock", "ability": "orbital"}},
	{"id": "orbital_hold", "name": "BEAM HOLD", "category": "ability", "position": Vector2(800, -100), "desc": "Increase maximum orbital beam hold time.", "max": -1, "base_cost": 340, "currency": "shards", "needs": ["orbital"], "effect": {"kind": "ability_stat", "ability": "orbital_hold", "amount": 0.5}},
	{"id": "orbital_heat", "name": "HEAT TICKS", "category": "ability", "position": Vector2(800, 40), "desc": "Increase orbital beam damage ticks.", "max": -1, "base_cost": 360, "currency": "shards", "needs": ["orbital"], "effect": {"kind": "ability_stat", "ability": "orbital_heat", "amount": 0.1}},
	{"id": "nuke", "name": "NUCLEAR BOMB", "category": "ability", "position": Vector2(620, 150), "desc": "End-tier screen-wipe active skill. Perfect-clear gated.", "max": 1, "costs": [{"crystals": 25}], "needs": ["orbital", "artillery"], "effect": {"kind": "ability_unlock", "ability": "nuke"}},
	{"id": "nuke_blast", "name": "NUKE BLAST", "category": "ability", "position": Vector2(800, 190), "desc": "Increase the nuclear blast area.", "max": -1, "base_cost": 500, "currency": "shards", "needs": ["nuke"], "effect": {"kind": "ability_stat", "ability": "nuke_blast", "amount": 35.0}},

	{"id": "defense", "name": "DEFENSE", "category": "defense", "position": Vector2(-40, 650), "desc": "Keep the exit standing under pressure.", "max": 1, "costs": [{"shards": 20}], "needs": ["core"], "effect": {"kind": "none"}},
	{"id": "health", "name": "REINFORCED GATE", "category": "defense", "position": Vector2(150, 700), "desc": "Increase base health.", "max": -1, "base_cost": 80, "currency": "shards", "needs": ["defense"], "effect": {"kind": "base_hp", "amount": 5}},
	{"id": "range", "name": "SIGHTLINES", "category": "defense", "position": Vector2(340, 700), "desc": "Increase every tower's range.", "max": -1, "base_cost": 100, "currency": "shards", "needs": ["defense"], "effect": {"kind": "range", "amount": 0.04}},
	{"id": "utility", "name": "UTILITY", "category": "utility", "position": Vector2(-40, -650), "desc": "Long-term payout improvements.", "max": 1, "costs": [{"shards": 20}], "needs": ["core"], "effect": {"kind": "none"}},
	{"id": "spoils", "name": "SPOILS", "category": "utility", "position": Vector2(-230, -760), "desc": "Increase Shards earned from kills and clears.", "max": -1, "base_cost": 90, "currency": "shards", "needs": ["utility"], "effect": {"kind": "payout", "amount": 0.05}},
	{"id": "crystal_gain", "name": "PRISTINE", "category": "utility", "position": Vector2(-40, -800), "desc": "Increase Crystals earned from perfect clears.", "max": -1, "base_cost": 180, "currency": "shards", "needs": ["utility"], "effect": {"kind": "crystal_gain", "amount": 1}},
	{"id": "diamond_gain", "name": "TROPHY HUNT", "category": "utility", "position": Vector2(150, -760), "desc": "Increase Diamonds earned from kill-all clears.", "max": -1, "base_cost": 220, "currency": "shards", "needs": ["utility"], "effect": {"kind": "diamond_gain", "amount": 1}},
	{"id": "enemy_effects", "name": "ENEMY EFFECTS", "category": "enemy", "position": Vector2(340, 680), "desc": "Open enemy modifiers using Diamonds.", "max": 1, "costs": [{"diamonds": 1}], "needs": ["core"], "effect": {"kind": "none"}},
	{"id": "explosive_orcs", "name": "EXPLOSIVE ORCS", "category": "enemy", "position": Vector2(540, 700), "desc": "Defeated orcs detonate, pushing and damaging the trailing horde.", "max": 1, "costs": [{"diamonds": 3}], "needs": ["enemy_effects"], "effect": {"kind": "explosive_orcs"}},
]


static func node(id: String) -> Dictionary:
	for spec in NODES:
		if String(spec["id"]) == id:
			return spec
	return {}


static func ids() -> Array:
	var out := []
	for spec in NODES:
		out.append(String(spec["id"]))
	return out


static func color_for(category: String) -> Color:
	return CATEGORY_COLORS.get(category, Color.WHITE)


static func level(tree: Dictionary, id: String) -> int:
	return int(tree.get(id, 0))


static func is_infinite(spec: Dictionary) -> bool:
	return int(spec.get("max", 1)) < 0


static func max_label(spec: Dictionary) -> String:
	return "∞" if is_infinite(spec) else str(int(spec.get("max", 1)))


static func cost_for(id: String, level_index: int) -> Dictionary:
	var spec := node(id)
	if spec.is_empty():
		return {}
	var max_level := int(spec.get("max", 1))
	if max_level >= 0 and level_index >= max_level:
		return {}
	var costs: Array = spec.get("costs", [])
	if level_index >= 0 and level_index < costs.size():
		return costs[level_index]
	var base := int(spec.get("base_cost", 0))
	if base <= 0:
		return {}
	return {String(spec.get("currency", "shards")): maxi(1, roundi(float(base) * pow(COST_GROWTH, level_index)))}


static func resource_total(resources: Dictionary, id: String) -> int:
	return int(resources.get(id, 0))


static func requirements_met(tree: Dictionary, spec: Dictionary) -> bool:
	for need in spec.get("needs", []):
		var required := int(spec.get("requires_level", {}).get(String(need), 1))
		if level(tree, String(need)) < required:
			return false
	return true


static func can_afford(resources: Dictionary, cost: Dictionary) -> bool:
	for resource in cost:
		if resource_total(resources, String(resource)) < int(cost[resource]):
			return false
	return true


static func can_purchase(tree: Dictionary, resources: Dictionary, id: String) -> bool:
	var spec := node(id)
	if spec.is_empty():
		return false
	var current := level(tree, id)
	var max_level := int(spec.get("max", 1))
	return (max_level < 0 or current < max_level) and requirements_met(tree, spec) and can_afford(resources, cost_for(id, current))


static func state(tree: Dictionary, resources: Dictionary, id: String) -> String:
	var spec := node(id)
	if spec.is_empty():
		return "missing"
	var current := level(tree, id)
	var max_level := int(spec.get("max", 1))
	if max_level >= 0 and current >= max_level:
		return "maxed"
	if not requirements_met(tree, spec):
		return "prerequisite"
	if can_afford(resources, cost_for(id, current)):
		return "purchasable"
	return "blocked" if current > 0 else "available"


static func cheapest_available(tree: Dictionary, resources: Dictionary) -> String:
	var best := ""
	var best_cost := INF
	for spec in NODES:
		var id := String(spec["id"])
		if not requirements_met(tree, spec):
			continue
		var cost := cost_for(id, level(tree, id))
		if cost.size() != 1:
			continue
		var resource := String(cost.keys()[0])
		if resource != "shards" or not can_afford(resources, cost):
			continue
		var value := int(cost[resource])
		if value < best_cost:
			best = id
			best_cost = value
	return best


static func effects(tree: Dictionary) -> Dictionary:
	var tower_ids := ["scrapper", "gun", "cannon", "mortar", "flame", "grenade", "tesla", "cryo", "laser"]
	var copies := {}
	var damage_mult := {}
	var rate_mult := {}
	var range_mults := {}
	var aoe_bonus := {}
	var pierce := {}
	for tower in tower_ids:
		copies[tower] = 0
		damage_mult[tower] = 1.0
		rate_mult[tower] = 1.0
		range_mults[tower] = 1.0
		aoe_bonus[tower] = 0.0
		pierce[tower] = 1
	var out := {
		"copies": copies,
		"damage_mult": damage_mult,
		"rate_mult": rate_mult,
		"rate_add": {"gun": 0.0},
		"range_mult": 1.0,
		"range_mults": range_mults,
		"aoe_bonus": aoe_bonus,
		"pierce": pierce,
		"cone_width": 360.0,
		"burn_duration": 1.0,
		"burn_stacks": 1,
		"grenade_bounces": 0,
		"debuff_mult": 1.0,
		"tesla_chain": 1,
		"execute_threshold": 0.0,
		"slow": 0.0,
		"beam_mult": 1.0,
		"beam_falloff": 0.35,
		"missile_cooldown": 0.5,
		"missile_damage_mult": 1.0,
		"missile_blast": 45.0,
		"auto": false,
		"ability_unlocks": {},
		"ability_stats": {"strafe_width": 80.0, "strafe_bombs": 2, "strafe_rate": 1.0, "artillery_shells": 3, "orbital_hold": 2.0, "orbital_heat": 1.0, "nuke_blast": 220.0},
		"tower_count": 0,
		"payout_mult": 1.0,
		"base_hp": 20,
		"crystal_gain": 0,
		"diamond_gain": 0,
		"explosive_orcs": false,
	}
	for spec in NODES:
		var lv := level(tree, String(spec["id"]))
		if lv <= 0:
			continue
		var effect: Dictionary = spec.get("effect", {})
		var kind := String(effect.get("kind", "none"))
		var amount := float(effect.get("amount", 0.0)) * lv
		match kind:
			"tower_copies": out["copies"][String(effect["tower"])] += int(amount)
			"tower_count": out["tower_count"] += int(amount)
			"damage": out["damage_mult"][String(effect["tower"])] += amount
			"rate": out["rate_mult"][String(effect["tower"])] += amount
			"rate_add": out["rate_add"][String(effect["tower"])] += amount
			"tower_range": out["range_mults"][String(effect["tower"])] += amount
			"range": out["range_mult"] += amount
			"aoe": out["aoe_bonus"][String(effect["tower"])] += amount
			"pierce": out["pierce"][String(effect["tower"])] += int(amount)
			"cone": out["cone_width"] = maxf(25.0, float(out["cone_width"]) - amount)
			"burn_duration": out["burn_duration"] += amount
			"burn_stacks": out["burn_stacks"] += int(amount)
			"bounces": out["grenade_bounces"] += int(amount)
			"debuff": out["debuff_mult"] += amount
			"chain": out["tesla_chain"] += int(amount)
			"execute": out["execute_threshold"] += amount
			"slow": out["slow"] = minf(0.9, float(out["slow"]) + amount)
			"beam": out["beam_mult"] += amount
			"falloff": out["beam_falloff"] = maxf(0.02, float(out["beam_falloff"]) - amount)
			"missile_cd": out["missile_cooldown"] = maxf(0.15, float(out["missile_cooldown"]) - amount)
			"missile_damage": out["missile_damage_mult"] += amount
			"missile_blast": out["missile_blast"] += amount
			"auto": out["auto"] = true
			"ability_unlock": out["ability_unlocks"][String(effect["ability"])] = true
			"ability_stat":
				var ability := String(effect["ability"])
				if ability == "strafe_rate":
					out["ability_stats"][ability] = maxf(0.2, float(out["ability_stats"].get(ability, 1.0)) - amount)
				else:
					out["ability_stats"][ability] = float(out["ability_stats"].get(ability, 0.0)) + amount
			"payout": out["payout_mult"] += amount
			"base_hp": out["base_hp"] += int(amount)
			"crystal_gain": out["crystal_gain"] += int(amount)
			"diamond_gain": out["diamond_gain"] += int(amount)
			"explosive_orcs": out["explosive_orcs"] = true
	return out


static func cost_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return "Free"
	var bits := []
	for id in ["shards", "crystals", "diamonds"]:
		if cost.has(id):
			bits.append("%d %s" % [int(cost[id]), id.capitalize()])
	return ", ".join(bits)


static func effect_text(spec: Dictionary) -> String:
	var effect: Dictionary = spec.get("effect", {})
	var amount: float = float(effect.get("amount", 0))
	match String(effect.get("kind", "none")):
		"tower_copies": return "+%d %s placement" % [int(amount), String(effect["tower"]).capitalize()]
		"tower_count": return "+%d tower deployment capacity" % int(amount)
		"damage": return "+%d%% %s damage" % [int(amount * 100.0), String(effect["tower"]).capitalize()]
		"rate": return "+%d%% %s fire rate" % [int(amount * 100.0), String(effect["tower"]).capitalize()]
		"rate_add": return "+%0.1f shots/sec" % amount
		"tower_range": return "+%d%% %s range" % [int(amount * 100.0), String(effect["tower"]).capitalize()]
		"range": return "+%d%% tower range" % int(amount * 100.0)
		"aoe": return "+%d blast radius" % int(amount)
		"pierce": return "+%d sequential hit" % int(amount)
		"cone": return "-%d° legal firing arc" % int(amount)
		"burn_duration": return "+%0.2fs burn duration" % amount
		"burn_stacks": return "+%d burn stack" % int(amount)
		"bounces": return "+%d wall bounce" % int(amount)
		"debuff": return "+%d%% damage taken by marked orcs" % int(amount * 100.0)
		"chain": return "+%d lightning bounce" % int(amount)
		"execute": return "+%d%% execution threshold" % int(amount * 100.0)
		"slow": return "+%d%% movement slow" % int(amount * 100.0)
		"beam": return "+%d%% beam damage" % int(amount * 100.0)
		"falloff": return "-%d%% beam falloff" % int(amount * 100.0)
		"missile_cd": return "-%0.2fs missile cooldown" % amount
		"missile_damage": return "+%d%% missile damage" % int(amount * 100.0)
		"missile_blast": return "+%d missile radius" % int(amount)
		"auto": return "Unlock automatic missile fire"
		"ability_unlock": return "Unlock %s support" % String(effect["ability"]).capitalize()
		"ability_stat": return "+%0.1f %s" % [amount, String(effect["ability"]).replace("_", " ")]
		"payout": return "+%d%% Shard payout" % int(amount * 100.0)
		"base_hp": return "+%d base health" % int(amount)
		"crystal_gain": return "+%d Crystal on perfect clear" % int(amount)
		"diamond_gain": return "+%d Diamond on kill-all clear" % int(amount)
		"explosive_orcs": return "Defeated orcs explode"
	return "Core access"
