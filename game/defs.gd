extends RefCounted
## Gobhold stage and tower definitions.
## Progression data and effect calculation live in progression.gd.

const Progression = preload("res://game/progression.gd")

const TOWERS := {
	"scrapper": {"name": "Scrapper", "damage": 4.0, "rate": 3.0, "range": 170.0, "aoe": 0.0, "kind": "single", "cost": 25.0,
		"desc": "Cheap rapid-fire starter. Single-target cleanup."},
	"gun": {"name": "Gunner", "damage": 8.0, "rate": 2.0, "range": 230.0, "aoe": 0.0, "kind": "single", "cost": 40.0,
		"desc": "Rapid fire cleanup. Holds exits."},
	"cannon": {"name": "Cannon", "damage": 30.0, "rate": 0.55, "range": 190.0, "aoe": 95.0, "kind": "mortar", "cost": 80.0,
		"desc": "Legacy name for the Mortar shell."},
	"mortar": {"name": "Mortar", "damage": 34.0, "rate": 0.5, "range": 200.0, "aoe": 92.0, "kind": "mortar", "cost": 90.0,
		"desc": "Slow explosive shells for dense lanes."},
	"flame": {"name": "Flamethrower", "damage": 14.0, "rate": 2.5, "range": 150.0, "aoe": 70.0, "kind": "flame", "cost": 65.0,
		"desc": "Short cone of continuous burn."},
	"grenade": {"name": "Grenade Launcher", "damage": 22.0, "rate": 0.8, "range": 210.0, "aoe": 48.0, "kind": "grenade", "cost": 70.0,
		"desc": "Impact shells that bounce and mark orcs."},
	"tesla": {"name": "Tesla", "damage": 18.0, "rate": 1.25, "range": 180.0, "aoe": 0.0, "kind": "tesla", "cost": 85.0,
		"desc": "Chain lightning with execution cleanup."},
	"cryo": {"name": "CryoBeam", "damage": 4.0, "rate": 5.0, "range": 175.0, "aoe": 0.0, "kind": "cryo", "cost": 75.0,
		"desc": "Continuous beam that stalls the horde."},
	"laser": {"name": "Laser", "damage": 12.0, "rate": 8.0, "range": 260.0, "aoe": 0.0, "kind": "laser", "cost": 100.0,
		"desc": "Continuous line beam with penetration."},
}

# Each entry is a playable battle stage. `requires` and `unlocks` form the
# stage graph shown by the progression shell.
const LEVELS := [
	{
		"id": "T", "name": "Field Test", "tutorial": true, "base_hp": 10,
		"orcs": 60, "diff": "Training", "branch": "core", "requires": [], "unlocks": ["1.1"],
		"about": "Missile only. Learn the crosshair, cooldown, and battle start.",
		"path": [Vector2(-40, 360), Vector2(1320, 360)],
		"waves": [{"n": 180, "hp": 16.0, "speed": 78.0, "gap": 0.1, "enemy": "runner"}],
		"shard": 1, "bonus": 0, "preview": "TRAINING",
	},
	{
		"id": "1.1", "name": "First Blood", "tutorial": false, "base_hp": 50,
		"orcs": 225, "diff": "Mild", "branch": "weapon", "requires": ["T"], "unlocks": ["1.2", "2.1"],
		"about": "Three waves on a winding road. Hold the chokepoints and mind the exit.",
		"path": [Vector2(-40, 180), Vector2(320, 180), Vector2(320, 540), Vector2(640, 540), Vector2(640, 180), Vector2(960, 180), Vector2(960, 540), Vector2(1320, 540)],
		"waves": [{"n": 45, "hp": 28.0, "speed": 55.0, "gap": 0.3, "enemy": "grunt"}, {"n": 75, "hp": 34.0, "speed": 58.0, "gap": 0.22, "enemy": "grunt"}, {"n": 105, "hp": 40.0, "speed": 60.0, "gap": 0.16, "enemy": "runner"}],
		"shard": 1, "bonus": 50, "preview": "FIRST BLOOD",
	},
	{
		"id": "1.2", "name": "Forked Road", "tutorial": false, "base_hp": 22,
		"orcs": 400, "diff": "Warm", "branch": "weapon", "requires": ["1.1"], "unlocks": ["2.2"],
		"about": "A longer route with a late split. Keep one tower in reserve for the weak lane.",
		"path": [Vector2(-40, 360), Vector2(220, 360), Vector2(430, 160), Vector2(700, 160), Vector2(940, 360), Vector2(1320, 360)],
		"waves": [{"n": 120, "hp": 34.0, "speed": 58.0, "gap": 0.2}, {"n": 140, "hp": 42.0, "speed": 61.0, "gap": 0.17}, {"n": 140, "hp": 50.0, "speed": 64.0, "gap": 0.14}],
		"shard": 1, "bonus": 80, "preview": "FORKED ROAD",
	},
	{
		"id": "2.1", "name": "Crossfire", "tutorial": false, "base_hp": 24,
		"orcs": 650, "diff": "Tense", "branch": "offense", "requires": ["1.1"], "unlocks": ["3.1"],
		"about": "Dense lanes reward penetration and a concentrated firing arc.",
		"path": [Vector2(-40, 120), Vector2(240, 120), Vector2(240, 600), Vector2(520, 600), Vector2(520, 120), Vector2(800, 120), Vector2(800, 600), Vector2(1320, 600)],
		"waves": [{"n": 180, "hp": 40.0, "speed": 60.0, "gap": 0.15}, {"n": 210, "hp": 48.0, "speed": 63.0, "gap": 0.12, "enemy": "explosive", "explosive": true}, {"n": 260, "hp": 58.0, "speed": 66.0, "gap": 0.1}],
		"shard": 1, "bonus": 120, "preview": "CROSSFIRE",
	},
	{
		"id": "2.2", "name": "Long Burn", "tutorial": false, "base_hp": 24,
		"orcs": 800, "diff": "Tense", "branch": "offense", "requires": ["1.2"], "unlocks": ["3.1"],
		"about": "A long straight gives burn and direct fire time to stack damage.",
		"path": [Vector2(-40, 210), Vector2(400, 210), Vector2(400, 500), Vector2(900, 500), Vector2(900, 300), Vector2(1320, 300)],
		"waves": [{"n": 220, "hp": 44.0, "speed": 62.0, "gap": 0.14}, {"n": 260, "hp": 54.0, "speed": 65.0, "gap": 0.11}, {"n": 320, "hp": 66.0, "speed": 68.0, "gap": 0.09}],
		"shard": 1, "bonus": 140, "preview": "LONG BURN",
	},
	{
		"id": "3.1", "name": "Three Routes", "tutorial": false, "base_hp": 26,
		"orcs": 1100, "diff": "Hard", "branch": "defense", "requires": ["2.1", "2.2"], "unlocks": ["3.2"],
		"about": "Three pressure points converge on the final approach.",
		"path": [Vector2(-40, 100), Vector2(260, 100), Vector2(260, 320), Vector2(620, 320), Vector2(620, 100), Vector2(980, 100), Vector2(980, 520), Vector2(1320, 520)],
		"waves": [{"n": 300, "hp": 52.0, "speed": 64.0, "gap": 0.11}, {"n": 350, "hp": 64.0, "speed": 67.0, "gap": 0.09}, {"n": 450, "hp": 78.0, "speed": 70.0, "gap": 0.07}],
		"shard": 1, "bonus": 180, "preview": "THREE ROUTES",
	},
	{
		"id": "3.2", "name": "Last Stand", "tutorial": false, "base_hp": 28,
		"orcs": 1500, "diff": "Severe", "branch": "defense", "requires": ["3.1"], "unlocks": [],
		"about": "The final rush tests permanent coverage, reserve towers, and timing.",
		"path": [Vector2(-40, 560), Vector2(260, 560), Vector2(260, 180), Vector2(580, 180), Vector2(580, 560), Vector2(900, 560), Vector2(900, 180), Vector2(1320, 180)],
		"waves": [{"n": 420, "hp": 62.0, "speed": 66.0, "gap": 0.09}, {"n": 480, "hp": 76.0, "speed": 70.0, "gap": 0.07}, {"n": 600, "hp": 92.0, "speed": 74.0, "gap": 0.055}],
		"shard": 1, "bonus": 250, "preview": "LAST STAND",
	},
]


static func level(id: String) -> Dictionary:
	for stage in LEVELS:
		if String(stage["id"]) == id:
			return stage
	return {}


static func copies_for(tree: Dictionary) -> Dictionary:
	return Progression.effects(tree)["copies"].duplicate()


static func dmg_mult(tree: Dictionary, tower: String) -> float:
	return float(Progression.effects(tree)["damage_mult"].get(tower, 1.0))


static func rate_mult(tree: Dictionary, tower: String) -> float:
	return float(Progression.effects(tree)["rate_mult"].get(tower, 1.0))


static func range_mult(tree: Dictionary) -> float:
	return float(Progression.effects(tree)["range_mult"])


static func missile_cd(tree: Dictionary) -> float:
	return float(Progression.effects(tree)["missile_cooldown"])


static func missile_mult(tree: Dictionary) -> float:
	return float(Progression.effects(tree)["missile_damage_mult"])


static func missile_blast(tree: Dictionary) -> float:
	return float(Progression.effects(tree)["missile_blast"])


static func payout_mult(tree: Dictionary) -> float:
	return float(Progression.effects(tree)["payout_mult"])
