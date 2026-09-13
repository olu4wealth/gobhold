extends Node2D
## Fixed-arc tower. Build phase owns placement and aim; combat owns attacks.

var type := "gun"
var kind := "single"
var damage := 8.0
var rate := 2.0
var attack_range := 230.0
var aoe := 0.0
var pierce_hits := 1
var burn_duration := 1.0
var burn_stacks := 1
var slow_amount := 0.0
var chain_bounces := 1
var execute_threshold := 0.0
var debuff_multiplier := 1.0
var beam_multiplier := 1.0
var beam_falloff := 0.35
var grenade_bounces := 0
var accent := Color(1.0, 0.6, 0.2)
var priority := "near"
var aim_angle := 0.0
var arc := TAU
var show_scope := false

var _cooldown := 0.0
var _aim := Vector2.RIGHT
var _flash := 0.0
var _flash_to := Vector2.ZERO
var _ring := 0.0
var _ring_at := Vector2.ZERO
var _beam := 0.0

const PRIORITIES := ["near", "first", "strong"]


func setup(p_type: String, stats: Dictionary, dmg_mult := 1.0, rate_mult := 1.0, range_mult := 1.0, effects := {}) -> void:
	type = p_type
	kind = String(stats.get("kind", "single"))
	damage = float(stats.get("damage", 1.0)) * dmg_mult
	rate = float(stats.get("rate", 1.0)) * rate_mult
	attack_range = float(stats.get("range", 100.0)) * range_mult
	var progression_effects: Dictionary = effects as Dictionary
	var aoe_bonuses: Dictionary = progression_effects.get("aoe_bonus", {})
	var pierce_levels: Dictionary = progression_effects.get("pierce", {})
	aoe = float(stats.get("aoe", 0.0)) + float(aoe_bonuses.get(type, 0.0))
	pierce_hits = int(pierce_levels.get(type, 1))
	burn_duration = float(progression_effects.get("burn_duration", 1.0))
	burn_stacks = int(progression_effects.get("burn_stacks", 1))
	slow_amount = float(progression_effects.get("slow", 0.0))
	chain_bounces = int(progression_effects.get("tesla_chain", 1))
	execute_threshold = float(progression_effects.get("execute_threshold", 0.0))
	debuff_multiplier = float(progression_effects.get("debuff_mult", 1.0))
	beam_multiplier = float(progression_effects.get("beam_mult", 1.0))
	beam_falloff = float(progression_effects.get("beam_falloff", 0.35))
	grenade_bounces = int(progression_effects.get("grenade_bounces", 0))
	if effects.has("range_mults"):
		attack_range *= float((effects["range_mults"] as Dictionary).get(type, 1.0))
	if effects.has("rate_add"):
		rate += float((effects["rate_add"] as Dictionary).get(type, 0.0))
	accent = Color(1.0, 0.6, 0.2)
	match kind:
		"mortar": accent = Color(1.0, 0.25, 0.2)
		"flame": accent = Color(1.0, 0.45, 0.1)
		"grenade": accent = Color(0.45, 0.95, 0.3)
		"tesla": accent = Color(0.4, 0.8, 1.0)
		"cryo": accent = Color(0.55, 0.9, 1.0)
		"laser": accent = Color(1.0, 0.25, 0.65)
	_cooldown = 0.2


func mode_idx() -> int:
	return maxi(PRIORITIES.find(priority), 0)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	_flash = maxf(0.0, _flash - delta)
	_ring = maxf(0.0, _ring - delta)
	_beam = maxf(0.0, _beam - delta)
	var horde = get_tree().get_first_node_in_group("horde")
	if horde == null or horde.count_alive() <= 0:
		return
	var idx: int = horde.query_in_range(global_position, attack_range, mode_idx(), aim_angle, arc)
	if idx < 0:
		return
	var hit: Vector2 = horde.pos[idx]
	var to: Vector2 = hit - global_position
	if to.length() > 1.0:
		_aim = to.normalized()
	if _cooldown <= 0.0:
		_cooldown = 1.0 / maxf(rate, 0.05)
		_attack(horde, idx, hit, to)
	queue_redraw()


func _attack(horde, idx: int, hit: Vector2, to: Vector2) -> void:
	match kind:
		"mortar":
			horde.damage_at(hit, aoe, damage)
			_ring = 0.25
			_ring_at = to_local(hit)
		"grenade":
			horde.damage_at(hit, aoe, damage)
			horde.apply_mark_at(hit, aoe, debuff_multiplier)
			for bounce in grenade_bounces:
				var bounce_point := hit + _aim * float(bounce + 1) * 44.0
				horde.damage_at(bounce_point, aoe * 0.75, damage * 0.7)
			_ring = 0.3
			_ring_at = to_local(hit)
		"flame":
			horde.damage_at(hit, maxf(aoe, 38.0), damage * 0.4)
			horde.apply_burn_at(hit, maxf(aoe, 38.0), damage * 0.35 * burn_stacks, burn_duration)
			_ring = 0.18
			_ring_at = to_local(hit)
		"tesla":
			horde.chain_damage(idx, damage, chain_bounces, execute_threshold)
			_flash = 0.12
			_flash_to = to_local(hit)
		"cryo":
			horde.damage_single(idx, damage * 0.2)
			horde.apply_slow(idx, slow_amount)
			_beam = 0.12
			_flash_to = to_local(hit)
		"laser":
			horde.damage_piercing(idx, damage * beam_multiplier, pierce_hits, beam_falloff)
			_beam = 0.16
			_flash_to = to_local(hit)
		_:
			if pierce_hits > 1:
				horde.damage_piercing(idx, damage, pierce_hits)
			else:
				horde.damage_single(idx, damage)
			_flash = 0.08
			_flash_to = to_local(hit)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 20.0, Color(0.16, 0.18, 0.22))
	draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 20, accent, 3.0)
	var slim := kind in ["single", "cryo", "laser"]
	var tip: Vector2 = _aim * (26.0 if slim else 20.0)
	draw_line(Vector2.ZERO, tip, accent, 9.0 if slim else 13.0)
	if _flash > 0.0:
		draw_line(Vector2.ZERO, _flash_to, Color(1, 0.9, 0.5, _flash / 0.12), 3.0)
	if _beam > 0.0:
		draw_line(Vector2.ZERO, _flash_to, Color(accent.r, accent.g, accent.b, _beam / 0.16), 5.0)
	if _ring > 0.0:
		var frac: float = 1.0 - _ring / 0.3
		draw_arc(_ring_at, aoe * frac, 0.0, TAU, 24, Color(1, 0.6, 0.2, 1.0 - frac), 4.0)
	if show_scope:
		var rc := Color(accent.r, accent.g, accent.b, 0.4)
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.22), 2.0)
		if arc < TAU - 0.01:
			draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(aim_angle - arc * 0.5) * attack_range, rc, 2.0)
			draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(aim_angle + arc * 0.5) * attack_range, rc, 2.0)
			draw_arc(Vector2.ZERO, attack_range * 0.99, aim_angle - arc * 0.5, aim_angle + arc * 0.5, 32, rc, 2.0)
		else:
			draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(aim_angle) * (attack_range + 12.0), rc, 3.0)
