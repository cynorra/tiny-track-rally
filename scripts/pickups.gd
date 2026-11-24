class_name Pickups extends Node3D



var race
var items: Array = []
var spin: = 0.0
var coin_mesh: Mesh; var coin_mat: Material; var nitro_mat: Material; var pad_mat: Material

func build(r, info: Dictionary) -> void :
	race = r
	var pts: Array = r.points; var dirs: Array = info["dirs"]; var n: = pts.size()
	var cm: = CylinderMesh.new();cm.top_radius = 0.38;cm.bottom_radius = 0.38;cm.height = 0.1;coin_mesh = cm
	coin_mat = _mat(Color(1, 0.8, 0.15), 0.6)
	nitro_mat = _mat(Color(0.25, 0.7, 1.0), 0.9)
	var sm: = ShaderMaterial.new();sm.shader = preload("res://scripts/boost_pad.gdshader");pad_mat = sm
	var rng: = RandomNumberGenerator.new();rng.seed = hash(String(r.track_def["id"]) + "pick")
	for i in range(3, n - 1):
		var straight: bool = dirs[i] == dirs[i - 1] and dirs[i] == dirs[(i + 1) % n]
		if not straight: continue
		var d: Vector3 = dirs[i]; var side: = d.cross(Vector3.UP)
		var off: float = float(r.wp_offset.get(i, 0.0))
		var c: Vector3 = pts[i]
		if i % 7 == 0:
			_add("pad", c + side * off + Vector3(0, 0.03, 0), d)
		elif i % 5 == 0:
			_add("nitro", c + side * (off + (1.6 if rng.randf() < 0.5 else -1.6)) + Vector3(0, 0.6, 0), d)
		elif i % 2 == 1:
			var lane: = off + rng.randf_range(-2.0, 2.0)
			for k in 3: _add("coin", c + side * lane + d * (k - 1) * 2.2 + Vector3(0, 0.6, 0), d)

static var _mats: = {}
func _mat(col: Color, e: float) -> StandardMaterial3D:
	var key: = "%s_%s" % [col, e]
	if _mats.has(key): return _mats[key]
	var m: = StandardMaterial3D.new();_mats[key] = m;m.albedo_color = col;m.emission_enabled = true;m.emission = col;m.emission_energy_multiplier = e
	m.metallic = 0.3;m.roughness = 0.4
	return m

func _add(kind: String, pos: Vector3, d: Vector3) -> void :
	var node: Node3D
	match kind:
		"coin":
			var mi: = MeshInstance3D.new();mi.mesh = coin_mesh;mi.material_override = coin_mat;mi.rotation.x = PI / 2
			node = Node3D.new();node.add_child(mi)
		"nitro":
			node = Node3D.new()
			var b: = MeshInstance3D.new(); var cm: = CylinderMesh.new();cm.top_radius = 0.28;cm.bottom_radius = 0.28;cm.height = 0.8;b.mesh = cm;b.material_override = nitro_mat;node.add_child(b)
			var cap: = MeshInstance3D.new(); var cc: = CylinderMesh.new();cc.top_radius = 0.12;cc.bottom_radius = 0.2;cc.height = 0.2;cap.mesh = cc;cap.position.y = 0.5
			cap.material_override = _mat(Color(0.9, 0.95, 1), 0.3);node.add_child(cap)
		"pad":


			node = Node3D.new()
			var p: = MeshInstance3D.new(); var pm: = PlaneMesh.new();pm.size = Vector2(2.6, 3.2);p.mesh = pm
			p.material_override = pad_mat;p.position.y = 0.02;node.add_child(p)
			node.basis = Basis.looking_at(d, Vector3.UP)
	node.position = pos
	add_child(node)
	items.append({"node": node, "kind": kind, "pos": pos, "active": true, "t": 0.0})

func update(delta: float) -> void :
	spin += delta * 3.0
	for it in items:
		if not it["active"]:
			it["t"] -= delta
			if it["t"] <= 0.0: it["active"] = true;it["node"].visible = true
			continue
		if it["kind"] != "pad": it["node"].rotation.y = spin
		var p: Vector3 = it["pos"]
		for r in race.racers:
			if r.get("out", false) or r["done"]: continue
			var vp: Vector3 = r["v"].get_vehicle_position()
			var dx: = vp.x - p.x; var dz: = vp.z - p.z
			var rad: = 1.9 if it["kind"] == "pad" else 1.25
			if dx * dx + dz * dz > rad * rad: continue
			if it["kind"] == "pad":
				race.on_boost_pad(r);it["active"] = false;it["t"] = 0.6
				break
			if not r["player"]: continue
			it["active"] = false;it["node"].visible = false
			it["t"] = 14.0 if it["kind"] == "coin" else 18.0
			race.on_pickup(it["kind"])
			break
