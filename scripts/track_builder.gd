class_name TrackBuilder


const ITEM_EMPTY: = 0
const ITEM_FOREST: = 1
const ITEM_TENTS: = 2
const ITEM_CORNER: = 3
const ITEM_FINISH: = 4
const ITEM_STRAIGHT: = 6

static func path_cells(def: Dictionary) -> Array:
	var cells: Array = []
	var p: Vector2i = def["start"]
	for ch in String(def["moves"]):
		cells.append(p)
		match ch:
			"R": p += Vector2i(1, 0)
			"L": p += Vector2i(-1, 0)
			"D": p += Vector2i(0, 1)
			"U": p += Vector2i(0, -1)
	assert (p == def["start"], "track not closed")

	var n: = cells.size()
	var best: = 0
	for i in n:
		if _is_straight(cells, i) and _is_straight(cells, i - 1) and _is_straight(cells, i - 2):
			best = i;break
	var out: Array = []
	for i in n: out.append(cells[(best + i) % n])
	return out

static func _is_straight(cells: Array, i: int) -> bool:
	var n: = cells.size()
	var a: Vector2i = cells[(i - 1 + n) % n] - cells[(i + n) % n]
	var b: Vector2i = cells[(i + 1) % n] - cells[(i + n) % n]
	return a == - b

static func corner_rot(a: Vector2i, b: Vector2i) -> float:
	var s: = [a, b]
	if Vector2i(-1, 0) in s and Vector2i(0, 1) in s: return 0.0
	if Vector2i(0, 1) in s and Vector2i(1, 0) in s: return 90.0
	if Vector2i(1, 0) in s and Vector2i(0, -1) in s: return 180.0
	return 270.0


static func build(def: Dictionary, gm: GridMap, thin: = false) -> Dictionary:
	var cells: = path_cells(def)
	var n: = cells.size()
	var points: Array = []
	var dirs: Array = []
	var cell_world: = Game.CELL
	var used: = {}
	for i in n:
		var c: Vector2i = cells[i]
		used[c] = true
		var a: Vector2i = cells[(i - 1 + n) % n] - c
		var b: Vector2i = cells[(i + 1) % n] - c
		var item: = ITEM_STRAIGHT
		var rot: = 0.0
		if a == - b:
			item = ITEM_FINISH if i == 0 else ITEM_STRAIGHT
			rot = 90.0 if b.x != 0 else 0.0
		else:
			item = ITEM_CORNER
			rot = corner_rot(a, b)
		var ori: = gm.get_orthogonal_index_from_basis(Basis(Vector3.UP, deg_to_rad(rot)))
		gm.set_cell_item(Vector3i(c.x, 0, c.y), item, ori)
		var center: = gm.to_global(gm.map_to_local(Vector3i(c.x, 0, c.y)))
		center.y = 0.0
		var wp: = center
		if item == ITEM_CORNER:
			var inner: = center + Vector3(a.x + b.x, 0, a.y + b.y) * 0.5 * cell_world
			wp = inner + (center - inner).normalized() * 0.5 * cell_world
		points.append(wp)
		dirs.append(Vector3(b.x, 0, b.y))

	var rng: = RandomNumberGenerator.new();rng.seed = hash(def["id"])
	var minc: = Vector2i(999, 999); var maxc: = Vector2i(-999, -999)
	for c in cells:
		minc = Vector2i(min(minc.x, c.x), min(minc.y, c.y));maxc = Vector2i(max(maxc.x, c.x), max(maxc.y, c.y))
	for x in range(minc.x - 2, maxc.x + 3):
		for z in range(minc.y - 2, maxc.y + 3):
			if used.has(Vector2i(x, z)): continue
			var inside: = x > minc.x and x < maxc.x and z > minc.y and z < maxc.y
			var r: = rng.randf()
			var it: = ITEM_FOREST
			if inside and r < 0.35: it = ITEM_TENTS
			elif r < 0.15: it = ITEM_EMPTY

			if thin and it != ITEM_EMPTY:
				var near_road: = false
				for nb in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
					if used.has(Vector2i(x, z) + nb): near_road = true;break
				var outer: = x < minc.x - 1 or x > maxc.x + 1 or z < minc.y - 1 or z > maxc.y + 1
				if outer or ( not near_road and rng.randf() < 0.5): it = ITEM_EMPTY
			gm.set_cell_item(Vector3i(x, 0, z), it, gm.get_orthogonal_index_from_basis(Basis(Vector3.UP, deg_to_rad(90.0 * rng.randi_range(0, 3)))))
	var lo: = gm.to_global(gm.map_to_local(Vector3i(minc.x - 2, 0, minc.y - 2)))
	var hi: = gm.to_global(gm.map_to_local(Vector3i(maxc.x + 2, 0, maxc.y + 2)))
	return {"cells": cells, "points": points, "dirs": dirs, "lo": lo, "hi": hi}




const ROAD_HALF: = 6.25

static func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * Game.CELL, 0.0, (c.y + 0.5) * Game.CELL)



static func centreline(cells: Array) -> PackedVector3Array:
	var out: = PackedVector3Array()
	var n: = cells.size()
	var C: float = Game.CELL
	for i in n:
		var c: Vector2i = cells[i]
		var a: Vector2i = cells[(i - 1 + n) % n] - c
		var b: Vector2i = cells[(i + 1) % n] - c
		var ctr: = cell_center(c)
		var p_in: = ctr + Vector3(a.x, 0, a.y) * 0.5 * C
		var p_out: = ctr + Vector3(b.x, 0, b.y) * 0.5 * C
		if a == - b:
			for k in 12: out.append(p_in.lerp(p_out, k / 12.0))
		else:
			var inner: = ctr + Vector3(a.x + b.x, 0, a.y + b.y) * 0.5 * C
			var v0: = p_in - inner; var v1: = p_out - inner
			for k in 12: out.append(inner + v0.slerp(v1, k / 12.0))
	return out


static func road_dist(line: PackedVector3Array, pos: Vector3) -> float:
	var p: = Vector2(pos.x, pos.z)
	var best: = INF
	var n: = line.size()
	for i in n:
		var a: = Vector2(line[i].x, line[i].z); var b: = Vector2(line[(i + 1) % n].x, line[(i + 1) % n].z)
		var ab: = b - a
		var t: = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-06), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


static func off_road(line: PackedVector3Array, pos: Vector3, radius: = 0.3) -> bool:
	return road_dist(line, pos) >= ROAD_HALF + radius


static func finish_posts(cells: Array) -> Array:
	if cells.size() < 2: return []
	var c: Vector2i = cells[0]; var b: Vector2i = cells[1] - c
	var side: = Vector3(b.x, 0, b.y).cross(Vector3.UP)
	return [cell_center(c) + side * 8.77, cell_center(c) - side * 8.77]
