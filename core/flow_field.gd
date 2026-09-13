extends Node2D
class_name GobFlow
## CPU flow field, 5 Hz + interpolation (GDD 5.3 Android fallback).
## Grid 40px over 1280x720. BFS distance to base; towers add cost later.
## ponytail: waypoint-seeded distances, no compute shader. GPU Dijkstra
## only when CPU field costs >2ms on mid devices.

const CELL := 40.0
const GW := 32
const GH := 18

var _dist := PackedFloat32Array()
var _flow := PackedVector2Array()
var _timer := 0.0
var _base_cell := Vector2i(GW - 1, GH >> 1)
var _ready_done := false


func setup(base_world: Vector2) -> void:
	_dist.resize(GW * GH)
	_flow.resize(GW * GH)
	_base_cell = _to_cell(base_world)
	_recompute()
	_ready_done = true


func _process(delta: float) -> void:
	if not _ready_done:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.2 # 5 Hz
		_recompute()


func direction_at(world: Vector2) -> Vector2:
	if not _ready_done:
		return Vector2.RIGHT
	var c := _to_cell(world)
	return _flow[_idx(c.x, c.y)]


func _to_cell(w: Vector2) -> Vector2i:
	return Vector2i(clampi(int(w.x / CELL), 0, GW - 1), clampi(int(w.y / CELL), 0, GH - 1))


func _idx(x: int, y: int) -> int:
	return y * GW + x


func _recompute() -> void:
	# BFS from base over uniform-cost grid (tower costs added in Phase 1).
	for i in _dist.size():
		_dist[i] = 1e9
	var queue: Array[Vector2i] = [_base_cell]
	_dist[_idx(_base_cell.x, _base_cell.y)] = 0.0
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		var d: float = _dist[_idx(c.x, c.y)]
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + off
			if n.x < 0 or n.y < 0 or n.x >= GW or n.y >= GH:
				continue
			if _dist[_idx(n.x, n.y)] > d + 1.0:
				_dist[_idx(n.x, n.y)] = d + 1.0
				queue.append(n)
	# Gradient descent -> flow vectors.
	for y in GH:
		for x in GW:
			var best := Vector2.ZERO
			var best_d: float = _dist[_idx(x, y)]
			for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + off
				if n.x < 0 or n.y < 0 or n.x >= GW or n.y >= GH:
					continue
				if _dist[_idx(n.x, n.y)] < best_d:
					best_d = _dist[_idx(n.x, n.y)]
					best = Vector2(off)
			_flow[_idx(x, y)] = best.normalized() if best != Vector2.ZERO else Vector2.ZERO
