extends Node2D
class_name GobHorde
## Gobhold horde: SoA pool + single MultiMeshInstance2D draw call.
## Replaces per-goblin PathFollow2D nodes (ceiling ~50) with flat arrays.
## Same signals as orc.gd (died/leaked) so game.gd economy is untouched.
## ponytail: O(n) spatial-hash separation; per-instance eyes/HP bars skipped,
## hp shown as instance-color tint. Add when close-up LOD matters.

signal died(reward: int)
signal leaked(damage: int)

const MAX := 2000
const RADIUS := 13.0
const CELL := 28.0 # 2 x RADIUS, per GDD spatial hash

var active_cap := 500
var alive := 0
var pos := PackedVector2Array()
var hp := PackedFloat32Array()
var max_hp_arr := PackedFloat32Array()
var speed_arr := PackedFloat32Array()
var dist := PackedFloat32Array()
var reward_arr := PackedInt32Array()
var leak_arr := PackedInt32Array()
var wobble := PackedFloat32Array()
var slow_arr := PackedFloat32Array()
var burn_arr := PackedFloat32Array()
var burn_dps_arr := PackedFloat32Array()
var mark_arr := PackedFloat32Array()
var explosive_arr := PackedByteArray()
var enemy_type := PackedStringArray()
var spawned_total := 0
var leaked_total := 0

var _pts := PackedVector2Array()
var _cum := PackedFloat32Array()
var _total := 1.0
var _mm: MultiMeshInstance2D
var _mesh_tex: Texture2D
var _hash := {}
var _time := 0.0

func _ready() -> void:
	add_to_group("horde")
	pos.resize(MAX)
	hp.resize(MAX)
	max_hp_arr.resize(MAX)
	speed_arr.resize(MAX)
	dist.resize(MAX)
	reward_arr.resize(MAX)
	leak_arr.resize(MAX)
	wobble.resize(MAX)
	slow_arr.resize(MAX)
	burn_arr.resize(MAX)
	burn_dps_arr.resize(MAX)
	mark_arr.resize(MAX)
	explosive_arr.resize(MAX)
	enemy_type.resize(MAX)
	_mesh_tex = _make_dot_texture()
	var quad := QuadMesh.new()
	quad.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	_mm = MultiMeshInstance2D.new()
	_mm.multimesh = mm
	_mm.texture = _mesh_tex
	add_child(_mm)


func setup(points: PackedVector2Array) -> void:
	_pts = points
	_cum = PackedFloat32Array()
	_cum.resize(_pts.size())
	var run := 0.0
	for i in _pts.size():
		if i == 0:
			_cum[i] = 0.0
		else:
			run += _pts[i - 1].distance_to(_pts[i])
			_cum[i] = run
	_total = maxf(run, 1.0)


func clear_all() -> void:
	alive = 0
	spawned_total = 0
	leaked_total = 0
	_mm.multimesh.visible_instance_count = 0


func spawn_wave(n: int, p_hp: float, p_speed: float, p_reward: int, p_leak: int, p_type := "grunt", p_explosive := false) -> int:
	var room: int = mini(active_cap, MAX) - alive
	var want: int = mini(n, room)
	for i in want:
		var idx := alive + i
		dist[idx] = -float(i) * 30.0 # stagger behind portal
		hp[idx] = p_hp
		max_hp_arr[idx] = p_hp
		speed_arr[idx] = p_speed * randf_range(0.9, 1.1)
		reward_arr[idx] = p_reward
		leak_arr[idx] = p_leak
		wobble[idx] = randf() * TAU
		slow_arr[idx] = 0.0
		burn_arr[idx] = 0.0
		burn_dps_arr[idx] = 0.0
		mark_arr[idx] = 1.0
		explosive_arr[idx] = 1 if p_explosive else 0
		enemy_type[idx] = p_type
		pos[idx] = _sample(dist[idx])
	alive += want
	spawned_total += want
	return want


func count_alive() -> int:
	return alive


func closest_in_range(p: Vector2, r: float) -> int:
	return query_in_range(p, r, 0)


func query_in_range(p: Vector2, r: float, mode: int, aim := 0.0, arc := TAU) -> int:
	# mode 0: near tower, 1: first (furthest along path), 2: strongest (max hp).
	# Narrow arcs only engage inside the aim cone (sweep-arc aiming).
	var best := -1
	var best_key := 0.0
	var started := false
	for i in alive:
		var to: Vector2 = pos[i] - p
		var d := to.length()
		if d > r:
			continue
		if arc < TAU and absf(angle_difference(aim, to.angle())) > arc * 0.5:
			continue
		var key := d
		if mode == 1:
			key = dist[i]
		elif mode == 2:
			key = hp[i]
		var better := false
		if not started:
			better = true
		elif mode == 0:
			better = key < best_key
		else:
			better = key > best_key
		if better:
			best = i
			best_key = key
			started = true
	return best


func damage_single(idx: int, amount: float) -> void:
	if idx < 0 or idx >= alive:
		return
	hp[idx] -= amount * mark_arr[idx]
	if hp[idx] <= 0.0:
		_kill(idx)


func damage_at(point: Vector2, radius: float, amount: float) -> void:
	var i := 0
	while i < alive:
		if pos[i].distance_to(point) <= radius:
			hp[i] -= amount * mark_arr[i]
			if hp[i] <= 0.0:
				_kill(i)
				continue # swapped element, recheck same i
		i += 1


func damage_piercing(idx: int, amount: float, hits: int, falloff := 0.08) -> void:
	if idx < 0 or idx >= alive:
		return
	var center_dist := dist[idx]
	var candidates := []
	for i in alive:
		if absf(dist[i] - center_dist) <= 115.0:
			candidates.append(i)
	candidates.sort_custom(func(a: int, b: int) -> bool: return absf(dist[a] - center_dist) < absf(dist[b] - center_dist))
	candidates.sort_custom(func(a: int, b: int) -> bool: return int(a) > int(b))
	var count := mini(hits, candidates.size())
	for i in count:
		var target := int(candidates[i])
		if target < alive:
			damage_single(target, amount * (1.0 - falloff * i))


func apply_slow(idx: int, amount: float) -> void:
	if idx >= 0 and idx < alive:
		slow_arr[idx] = maxf(slow_arr[idx], clampf(amount, 0.0, 0.9))


func apply_burn(idx: int, dps: float, duration: float) -> void:
	if idx >= 0 and idx < alive:
		burn_dps_arr[idx] = maxf(burn_dps_arr[idx], dps)
		burn_arr[idx] = maxf(burn_arr[idx], duration)


func apply_mark(idx: int, multiplier: float) -> void:
	if idx >= 0 and idx < alive:
		mark_arr[idx] = maxf(mark_arr[idx], multiplier)


func apply_slow_at(point: Vector2, radius: float, amount: float) -> void:
	for i in alive:
		if pos[i].distance_to(point) <= radius:
			apply_slow(i, amount)


func apply_burn_at(point: Vector2, radius: float, dps: float, duration: float) -> void:
	for i in alive:
		if pos[i].distance_to(point) <= radius:
			apply_burn(i, dps, duration)


func apply_mark_at(point: Vector2, radius: float, multiplier: float) -> void:
	for i in alive:
		if pos[i].distance_to(point) <= radius:
			apply_mark(i, multiplier)


func chain_damage(start_idx: int, amount: float, bounces: int, execute_threshold := 0.0) -> void:
	if start_idx < 0 or start_idx >= alive:
		return
	var used := {}
	var current := start_idx
	for bounce in bounces:
		if current < 0 or current >= alive or used.has(current):
			break
		used[current] = true
		damage_single(current, amount * (1.0 - 0.12 * bounce))
		if current < alive and execute_threshold > 0.0 and hp[current] / max_hp_arr[current] <= execute_threshold:
			damage_single(current, max_hp_arr[current] * 2.0)
		var next := -1
		var best := 999999.0
		if current < alive:
			for i in alive:
				if used.has(i):
					continue
				var d := pos[i].distance_to(pos[current])
				if d < best and d <= 150.0:
					best = d
					next = i
		current = next


func nearest_index(point: Vector2) -> int:
	return closest_in_range(point, 100000.0)


func _kill(idx: int) -> void:
	var death_pos := pos[idx]
	var explode := explosive_arr[idx] == 1
	var explosion_damage := max_hp_arr[idx] * 0.35
	died.emit(reward_arr[idx])
	_remove_at(idx)
	if explode:
		damage_at(death_pos, 76.0, explosion_damage)


func _remove_at(idx: int) -> void:
	alive -= 1
	if idx != alive:
		pos[idx] = pos[alive]
		hp[idx] = hp[alive]
		max_hp_arr[idx] = max_hp_arr[alive]
		speed_arr[idx] = speed_arr[alive]
		dist[idx] = dist[alive]
		reward_arr[idx] = reward_arr[alive]
		leak_arr[idx] = leak_arr[alive]
		wobble[idx] = wobble[alive]
		slow_arr[idx] = slow_arr[alive]
		burn_arr[idx] = burn_arr[alive]
		burn_dps_arr[idx] = burn_dps_arr[alive]
		mark_arr[idx] = mark_arr[alive]
		explosive_arr[idx] = explosive_arr[alive]
		enemy_type[idx] = enemy_type[alive]


func _physics_process(delta: float) -> void:
	if alive <= 0:
		_mm.multimesh.visible_instance_count = 0
		return
	_time += delta
	var effect_idx := 0
	while effect_idx < alive:
		if burn_arr[effect_idx] > 0.0:
			burn_arr[effect_idx] = maxf(0.0, burn_arr[effect_idx] - delta)
			hp[effect_idx] -= burn_dps_arr[effect_idx] * delta * mark_arr[effect_idx]
			if hp[effect_idx] <= 0.0:
				_kill(effect_idx)
				continue
		if burn_arr[effect_idx] <= 0.0:
			burn_dps_arr[effect_idx] = 0.0
		effect_idx += 1
	# Advance along baked path.
	for i in alive:
		dist[i] += speed_arr[i] * (1.0 - slow_arr[i]) * delta
		slow_arr[i] = maxf(0.0, slow_arr[i] - delta * 0.15)
	# Leaks from the front (dist sorted-ish but not guaranteed; scan).
	var i := 0
	while i < alive:
		if dist[i] >= _total:
			leaked.emit(leak_arr[i])
			leaked_total += 1
			_remove_at(i)
			continue
		i += 1
	_sample_all()
	_separate()
	_push_instances()


func _sample(d: float) -> Vector2:
	var dd: float = clampf(d, 0.0, _total)
	# Binary search segment.
	var lo := 0
	var hi := _cum.size() - 1
	while lo < hi:
		var mid := (lo + hi) >> 1
		if _cum[mid] < dd:
			lo = mid + 1
		else:
			hi = mid
	var seg := maxi(lo, 1)
	var seg_len: float = _cum[seg] - _cum[seg - 1]
	var t := 0.0 if seg_len <= 0.0 else (_cum[seg] - dd) / seg_len
	return _pts[seg - 1].lerp(_pts[seg], 1.0 - t)


func _sample_all() -> void:
	for i in alive:
		var base := _sample(dist[i])
		var w: float = sin(_time * 6.0 + wobble[i]) * 6.0
		pos[i] = base + Vector2(0, w)


func _separate() -> void:
	# ponytail: single pass, radius push only. Full 8-neighbor
	# narrowphase when crowds exceed 1000 and pile visibly.
	_hash.clear()
	for i in alive:
		var key := Vector2i((pos[i] / CELL).floor())
		if _hash.has(key):
			(_hash[key] as Array).append(i)
		else:
			_hash[key] = [i]
	for i in alive:
		var key := Vector2i((pos[i] / CELL).floor())
		var cell: Array = _hash.get(key, [])
		for j in cell:
			if j <= i:
				continue
			var delta: Vector2 = pos[j] - pos[i]
			var d := delta.length()
			if d > 0.01 and d < RADIUS * 2.0:
				var push: Vector2 = delta / d * (RADIUS * 2.0 - d) * 0.25
				pos[i] -= push
				pos[j] += push


func _push_instances() -> void:
	var mm_res: MultiMesh = _mm.multimesh
	mm_res.visible_instance_count = alive
	for i in alive:
		var frac: float = clampf(hp[i] / max_hp_arr[i], 0.0, 1.0)
		var t := Transform2D(0.0, pos[i] - global_position)
		mm_res.set_instance_transform_2d(i, t)
		mm_res.set_instance_color(i, Color(1.0 - frac * 0.75, 0.25 + frac * 0.35, 0.25))


func _make_dot_texture() -> Texture2D:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c + Vector2(0.5, 0.5))
			if d <= 15.0:
				var edge := smoothstep(15.0, 12.0, d)
				img.set_pixel(x, y, Color(0.25, 0.55, 0.25, edge))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
