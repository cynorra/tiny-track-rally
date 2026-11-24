class_name WeatherFX



static func sun_for(weather: String, sun: DirectionalLight3D) -> void :
	match weather:
		"sunset":
			sun.light_color = Color(1.0, 0.62, 0.38);sun.light_energy = 0.95
			sun.rotation_degrees = Vector3(-14, -60, 0)
		"rain":
			sun.light_color = Color(0.8, 0.85, 0.95);sun.light_energy = 0.45
		"fog":
			sun.light_color = Color(0.95, 0.95, 0.95);sun.light_energy = 0.6
		"night":
			sun.light_color = Color(0.6, 0.7, 1.0);sun.light_energy = 0.3;sun.shadow_enabled = false
			sun.set_meta("no_shadow", true)


static func wet_library(ml: MeshLibrary) -> MeshLibrary:
	var wet: MeshLibrary = ml.duplicate()
	for id in [3, 4, 5, 6]:
		var m: Mesh = ml.get_item_mesh(id)
		if m == null: continue
		var nm: ArrayMesh = m.duplicate()
		for s in nm.get_surface_count():
			var base = nm.surface_get_material(s)
			if base is StandardMaterial3D:
				var w: StandardMaterial3D = base.duplicate()
				w.albedo_color = w.albedo_color * Color(0.62, 0.64, 0.7)
				w.roughness = 0.18;w.metallic_specular = 0.9
				nm.surface_set_material(s, w)
		wet.set_item_mesh(id, nm)
	return wet

static func rain(parent: Node3D, quality: int) -> GPUParticles3D:
	var p: = GPUParticles3D.new()
	p.amount = [250, 700, 1400][clamp(quality, 0, 2)]
	p.lifetime = 0.9;p.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	var pm: = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX;pm.emission_box_extents = Vector3(22, 1, 22)
	pm.direction = Vector3(0.15, -1, 0);pm.spread = 3.0;pm.initial_velocity_min = 24.0;pm.initial_velocity_max = 30.0
	pm.gravity = Vector3(0, -10, 0)
	p.process_material = pm
	var q: = QuadMesh.new();q.size = Vector2(0.03, 0.7)
	var mat: = StandardMaterial3D.new();mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.75, 0.82, 0.95, 0.45);mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	q.material = mat;p.draw_pass_1 = q
	p.position = Vector3(0, 14, 0)
	parent.add_child(p)
	return p

static var _mats: = {}
static func _emissive(c: Color, e: float) -> StandardMaterial3D:
	var key: = "%s_%s" % [c, e]
	if _mats.has(key): return _mats[key]
	var m: = StandardMaterial3D.new();_mats[key] = m;m.albedo_color = c;m.emission_enabled = true;m.emission = c;m.emission_energy_multiplier = e
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func car_lights(v: Vehicle, is_player: bool, bike: bool, quality: int) -> void :
	var c: Node3D = v.get_node("Container")
	var xs: = [0.0] if bike else [-0.22, 0.22]
	for x in xs:
		var h: = MeshInstance3D.new(); var hb: = BoxMesh.new();hb.size = Vector3(0.12, 0.07, 0.03);h.mesh = hb
		h.material_override = _emissive(Color(1, 0.95, 0.75), 3.0);h.position = Vector3(x, 0.42, 0.71 if not bike else 0.5);c.add_child(h)
		var t: = MeshInstance3D.new(); var tb: = BoxMesh.new();tb.size = Vector3(0.12, 0.06, 0.03);t.mesh = tb
		t.material_override = _emissive(Color(1, 0.08, 0.05), 2.5);t.position = Vector3(x, 0.4, -0.71 if not bike else -0.5);c.add_child(t)
	if is_player:
		var sl: = SpotLight3D.new();sl.light_color = Color(1, 0.95, 0.8);sl.light_energy = 6.0
		sl.spot_range = 26.0;sl.spot_angle = 32.0;sl.spot_attenuation = 0.8;sl.shadow_enabled = false
		sl.position = Vector3(0, 0.6, 0.8);sl.rotation_degrees = Vector3(-8, 180, 0)
		c.add_child(sl)


static func lamps(race: Node3D, points: Array, dirs: Array, quality: int, cells: Array = []) -> void :
	var lit: = 0
	var pole_m: StandardMaterial3D = _mats.get("pole")
	if pole_m == null: pole_m = StandardMaterial3D.new();pole_m.albedo_color = Color(0.25, 0.27, 0.32);_mats["pole"] = pole_m
	var bulb_m: = _emissive(Color(1, 0.85, 0.5), 4.0)
	for spot in lamp_spots(points, dirs, cells):
		var i: int = spot["i"]; var base: Vector3 = spot["pos"]; var toward: Vector3 = spot["toward"]
		var pole: = MeshInstance3D.new(); var cm: = CylinderMesh.new();cm.top_radius = 0.08;cm.bottom_radius = 0.1;cm.height = 4.2;pole.mesh = cm
		pole.material_override = pole_m;pole.position = base + Vector3(0, 2.1, 0);race.add_child(pole)
		var bulb: = MeshInstance3D.new(); var sm: = SphereMesh.new();sm.radius = 0.25;sm.height = 0.4;bulb.mesh = sm
		bulb.material_override = bulb_m;bulb.position = base + Vector3(0, 4.2, 0) + toward * 0.4;race.add_child(bulb)
		if quality >= 1 and (i / 3) % 2 == 0 and lit < 14:
			var o: = OmniLight3D.new();o.light_color = Color(1, 0.82, 0.55);o.light_energy = 2.2;o.omni_range = 11.0
			o.position = bulb.position - Vector3(0, 0.4, 0);o.shadow_enabled = false;race.add_child(o);lit += 1
		pole.set_meta("prop", "lamp")





static func lamp_spots(points: Array, dirs: Array, cells: Array) -> Array:
	var n: = points.size()
	var line: = TrackBuilder.centreline(cells) if cells.size() == n else PackedVector3Array()
	var out: Array = []
	for i in range(1, n, 3):
		var d: Vector3 = dirs[i]; var side: = d.cross(Vector3.UP)
		var s: = 1.0 if (i / 3) % 2 == 0 else -1.0
		var cands: Array = [points[i] + side * s * 6.6]
		if line.is_empty():
			out.append({"i": i, "pos": cands[0], "toward": - side * s});continue
		var c: Vector2i = cells[i]
		var a: Vector2i = cells[(i - 1 + n) % n] - c; var b: Vector2i = cells[(i + 1) % n] - c
		if a != - b:
			cands.append(TrackBuilder.cell_center(c) - Vector3(a.x + b.x, 0, a.y + b.y) * 0.5 * Game.CELL * 0.8)
		cands.append_array([points[i] - side * s * 6.6, points[i] + side * s * 7.6, points[i] - side * s * 7.6])
		for p in cands:
			var pos: Vector3 = p
			if not TrackBuilder.off_road(line, pos, 0.3): continue
			var clash: = false
			for o in out:
				if (o["pos"] as Vector3).distance_to(pos) < 3.0: clash = true
			for g in TrackBuilder.finish_posts(cells):
				if (g as Vector3).distance_to(pos) < 2.5: clash = true
			if clash: continue
			var tw: Vector3 = points[i] - pos;tw.y = 0.0
			out.append({"i": i, "pos": pos, "toward": tw.normalized()});break
	return out
