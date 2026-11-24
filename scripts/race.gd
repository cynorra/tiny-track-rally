class_name Race extends Node3D


signal race_finished(result: Dictionary)
signal quit_requested

const AI_NAMES: = ["Max", "Luna", "Rico", "Bea", "Kai", "Nova", "Ziggy"]
const FACTORY_LOOK: = {"yellow": 4, "red": 1, "green": 3}

var track_index: = 0
var mode: = "race"
var track_def: Dictionary
var points: Array = []
var racers: Array = []
var player: Dictionary
var view: ChaseCam
var hud: CanvasLayer
var race_time: = 0.0
var state: = "countdown"
var countdown: = 3.5
var last_count: = 4
var nitro: = 0.5
var drift_pts: = 0.0
var drift_total: = 0
var drift_cool: = 0.0
var ghost_rec: Array = []
var ghost_play: Array = []
var ghost_node: Node3D
var ghost_t: = 0.0
var lap_start: = 0.0
var best_lap: = 9999.0
var ai_boost: = 1.0
var LAPS: = 3
var weather: = "clear"
var _saved_envs: = []
var my_env: Environment
var quality: = 1
var pickups: Pickups
var skids: SkidMarks
var rain_fx: GPUParticles3D
var missions: Array = []
signal mission_completed(index: int)
var rs: = {"coins": 0, "drift": 0, "nitro_uses": 0, "pads": 0, "wall_hits": 0, "respawns": 0, "max_kmh": 0.0}
var pad_boost_t: = 0.0
var cps: Array = []
var time_left: = 0.0
var cp_next: = 0
var elim_done: = 0
var elim_seg: = 0
var fps_acc: = 0.0; var fps_frames: = 0; var fps_checked: = false
var flyby_cam: Camera3D; var flyby_t: = 0.0
var tips_layer: CanvasLayer
var mission_panel: Control
var l_toast: Label
var info: Dictionary
var finish_order: Array = []
var wp_offset: = {}
var obstacles: Array = []
var ai_paints: Array = []
var movers: Array = []


var l_pos: Label; var l_lap: Label; var l_time: Label; var l_speed: Label; var l_center: Label; var l_drift: Label; var l_best: Label
var nitro_bar: ProgressBar; var minimap: Minimap
var pause_layer: CanvasLayer
var touch: TouchControls

class AIDriver:
	var race; var racer: Dictionary; var lane: = 0.0; var skill: = 1.0
	func get_drive_input(v) -> Vector2:
		var pts: Array = race.points
		var n: = pts.size()
		var i: int = racer["wp"] %n
		var p: Vector3 = v.get_vehicle_position()
		var target: Vector3 = pts[i]
		var nxt: Vector3 = pts[(i + 1) % n]
		var d: = Vector2(p.x - target.x, p.z - target.z).length()
		var la: float = Game.CELL * 0.9
		if d < la: target = target.lerp(nxt, clamp(1.0 - d / la, 0.0, 0.7))
		var seg: Vector3 = (nxt - pts[i]).normalized()
		var off: float = race.wp_offset.get(i, lane)
		if d < la and race.wp_offset.has((i + 1) % n): off = race.wp_offset[(i + 1) % n]
		target += seg.cross(Vector3.UP) * off
		var to: Vector3 = target - p;to.y = 0
		var fwd: Vector3 = v.forward();fwd.y = 0
		var ang: = fwd.normalized().signed_angle_to(to.normalized(), Vector3.UP)
		var steer: float = clamp( - ang * 2.5, -1.0, 1.0)
		var throttle: = 1.0 if abs(ang) < 0.9 else 0.5
		return Vector2(steer, throttle)

func setup(t_index: int, m: String) -> void :
	track_index = t_index;mode = m
	track_def = Game.TRACKS[t_index]
	LAPS = Game.laps_for(t_index)
	weather = Game.weather_for(t_index)
	if mode == "daily":
		ai_boost = float(Game.daily_info()["ai_boost"]);weather = String(Game.daily_info().get("weather", weather))
	if OS.get_environment("TTR_WEATHER") != "": weather = OS.get_environment("TTR_WEATHER")
	quality = int(Game.data["settings"]["quality"])
	var rng: = RandomNumberGenerator.new();rng.randomize()
	missions = Progress.pick_missions(mode, t_index, rng)

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if mode == "elimination": LAPS = 99
	_build_world()
	_spawn_racers()
	_build_hud();_update_hud()
	_build_mission_panel()
	_begin_loading()
	if mode == "time_trial": _load_ghost()
	Sound.play_music("race")
	if OS.get_environment("TTR_TOPDOWN") != "": _debug_topdown()

func _debug_topdown() -> void :
	for i in points.size():
		var mi: = MeshInstance3D.new(); var sm: = SphereMesh.new();sm.radius = 0.8;sm.height = 1.6;mi.mesh = sm
		var mat: = StandardMaterial3D.new();mat.albedo_color = Color(1, 0, 0) if i == 0 else Color(0, 0, 1).lerp(Color(1, 1, 0), float(i) / points.size());mi.material_override = mat
		mi.position = points[i] + Vector3(0, 1, 0);add_child(mi)
	var c: = Camera3D.new();c.projection = Camera3D.PROJECTION_ORTHOGONAL;c.size = float(OS.get_environment("TTR_TD_SIZE")) if OS.get_environment("TTR_TD_SIZE") != "" else 60.0
	var mid: = Vector3.ZERO
	for p in points: mid += p
	mid /= points.size()
	if OS.get_environment("TTR_TD_CENTER") != "":
		var xz: = OS.get_environment("TTR_TD_CENTER").split(",")
		mid = Vector3(float(xz[0]), 0, float(xz[1]))
	c.position = mid + Vector3(0, 50, 0);c.rotation_degrees.x = -90;c.far = 200;add_child(c);c.current = true
	await get_tree().create_timer(float(OS.get_environment("TTR_TD_WAIT")) if OS.get_environment("TTR_TD_WAIT") != "" else 1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/topdown_%d.png" % track_index)
	get_tree().quit()

func _build_world() -> void :

	var race_env: = Game.make_env(weather)
	for we in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_saved_envs.append([we, we.get_meta("base_env", we.environment)]);we.set_meta("base_env", we.get_meta("base_env", we.environment));we.environment = race_env;my_env = race_env
	if _saved_envs.is_empty():
		var env: = WorldEnvironment.new();env.environment = race_env;add_child(env)
	var sun: = DirectionalLight3D.new()
	sun.transform = Transform3D(Basis(Vector3(-0.422618, 0, -0.906308), Vector3(-0.694272, 0.642788, 0.323744), Vector3(0.582564, 0.766044, -0.271654)), Vector3.ZERO)
	sun.shadow_enabled = Game.shadows_enabled();sun.directional_shadow_max_distance = 22.0 if Game.perf_mode and quality == 1 else 30.0
	sun.shadow_bias = 0.2;sun.shadow_normal_bias = 1.0;sun.shadow_opacity = 0.75
	WeatherFX.sun_for(weather, sun)
	add_child(sun)
	var gm: = GridMap.new()
	gm.mesh_library = Game.scene("res://models/Library/mesh-library.tres")
	if weather == "rain": gm.mesh_library = WeatherFX.wet_library(gm.mesh_library)
	gm.cell_size = Vector3(9.99, 1, 9.99)
	gm.transform = Transform3D(Basis().scaled(Vector3.ONE * Game.TILE_SCALE), Vector3(0, -0.5 * Game.TILE_SCALE, 0))
	var pm: = PhysicsMaterial.new();pm.friction = 0.0;pm.bounce = 0.1
	gm.physics_material = pm
	add_child(gm)
	info = TrackBuilder.build(track_def, gm, Game.perf_mode and quality == 0)
	points = info["points"]
	var lo: Vector3 = info["lo"]; var hi: Vector3 = info["hi"]
	var plane: = StaticBody3D.new(); var cs: = CollisionShape3D.new(); var box: = BoxShape3D.new()
	box.size = Vector3(hi.x - lo.x + 40, 0, hi.z - lo.z + 40);cs.shape = box
	plane.position = Vector3((lo.x + hi.x) / 2, -0.02, (lo.z + hi.z) / 2)
	plane.add_child(cs);add_child(plane)
	if track_def.get("obstacles", false): _build_obstacles(info)
	pickups = Pickups.new();add_child(pickups);pickups.build(self, info)
	skids = SkidMarks.new();add_child(skids)
	if weather == "night": WeatherFX.lamps(self, points, info["dirs"], quality, info["cells"])
	if mode == "checkpoint": _build_checkpoints()


static var _mats: = {}
func _mat(c: Color) -> StandardMaterial3D:
	if _mats.has(c): return _mats[c]
	var m: = StandardMaterial3D.new();m.albedo_color = c;m.roughness = 0.8;_mats[c] = m;return m

func _static_box(pos: Vector3, size: Vector3, yaw: float, col: Color) -> StaticBody3D:
	var b: = StaticBody3D.new();b.collision_layer = 1;b.collision_mask = 0
	var cs: = CollisionShape3D.new(); var sh: = BoxShape3D.new();sh.size = size;cs.shape = sh;b.add_child(cs)
	var mi: = MeshInstance3D.new(); var bm: = BoxMesh.new();bm.size = size;mi.mesh = bm;mi.material_override = _mat(col);b.add_child(mi)
	b.position = pos;b.rotation.y = yaw;add_child(b);obstacles.append(b);return b

func _barrel(pos: Vector3) -> void :
	var b: = StaticBody3D.new();b.collision_mask = 0
	var cs: = CollisionShape3D.new(); var sh: = CylinderShape3D.new();sh.radius = 0.55;sh.height = 1.2;cs.shape = sh;b.add_child(cs)
	var mi: = MeshInstance3D.new(); var cm: = CylinderMesh.new();cm.top_radius = 0.55;cm.bottom_radius = 0.55;cm.height = 1.2;mi.mesh = cm;mi.material_override = _mat(Color(0.85, 0.2, 0.15));b.add_child(mi)
	var ring: = MeshInstance3D.new(); var rm: = CylinderMesh.new();rm.top_radius = 0.57;rm.bottom_radius = 0.57;rm.height = 0.12;ring.mesh = rm;ring.material_override = _mat(Color(0.95, 0.95, 0.95));b.add_child(ring)
	b.position = pos + Vector3(0, 0.6, 0);add_child(b);obstacles.append(b)

func _cone(pos: Vector3) -> void :
	var b: = RigidBody3D.new();b.mass = 0.4;b.collision_layer = 16;b.collision_mask = 1 | 8 | 16
	b.angular_damp = 1.0;b.linear_damp = 0.4
	var cs: = CollisionShape3D.new(); var sh: = CylinderShape3D.new();sh.radius = 0.28;sh.height = 0.75;cs.shape = sh;b.add_child(cs)
	var mi: = MeshInstance3D.new(); var cm: = CylinderMesh.new();cm.top_radius = 0.04;cm.bottom_radius = 0.3;cm.height = 0.75;mi.mesh = cm;mi.material_override = _mat(Color(1, 0.45, 0.05));b.add_child(mi)
	var band: = MeshInstance3D.new(); var bm: = CylinderMesh.new();bm.top_radius = 0.15;bm.bottom_radius = 0.2;bm.height = 0.14;band.mesh = bm;band.material_override = _mat(Color.WHITE);band.position.y = 0.08;b.add_child(band)
	b.position = pos + Vector3(0, 0.4, 0);add_child(b);obstacles.append(b)

func _bump(pos: Vector3, dir: Vector3) -> void :

	var b: = StaticBody3D.new();b.collision_mask = 0
	var cs: = CollisionShape3D.new(); var sh: = CylinderShape3D.new();sh.radius = 5.0;sh.height = 11.0;cs.shape = sh;b.add_child(cs)
	var mi: = MeshInstance3D.new(); var cm: = CylinderMesh.new();cm.top_radius = 5.0;cm.bottom_radius = 5.0;cm.height = 11.0;cm.radial_segments = 48;mi.mesh = cm
	mi.material_override = _mat(Color(0.36, 0.37, 0.42));b.add_child(mi)
	var stripe: = MeshInstance3D.new(); var sm: = CylinderMesh.new();sm.top_radius = 5.01;sm.bottom_radius = 5.01;sm.height = 1.0;sm.radial_segments = 48;stripe.mesh = sm;stripe.material_override = _mat(Color(1, 0.8, 0.1));b.add_child(stripe)
	var side: = dir.cross(Vector3.UP)
	b.basis = Basis.looking_at(side, Vector3.UP) * Basis(Vector3.RIGHT, PI / 2)
	b.position = pos + Vector3(0, -5.0 + 0.45, 0);add_child(b);obstacles.append(b)

func _mover(pos: Vector3, side: Vector3, s: float, phase: float) -> void :
	var b: = AnimatableBody3D.new();b.collision_mask = 0;b.sync_to_physics = true
	var cs: = CollisionShape3D.new(); var sh: = BoxShape3D.new();sh.size = Vector3(2.2, 1.0, 1.0);cs.shape = sh;b.add_child(cs)
	var mi: = MeshInstance3D.new(); var bm: = BoxMesh.new();bm.size = sh.size;mi.mesh = bm;mi.material_override = _mat(Color(0.95, 0.85, 0.15));b.add_child(mi)
	var dm: = MeshInstance3D.new(); var dbm: = BoxMesh.new();dbm.size = Vector3(2.25, 0.3, 1.02);dm.mesh = dbm;dm.material_override = _mat(Color(0.1, 0.1, 0.12));b.add_child(dm)
	b.basis = Basis.looking_at(side, Vector3.UP).rotated(Vector3.UP, PI / 2)
	add_child(b);obstacles.append(b)
	movers.append({"b": b, "base": pos + Vector3(0, 0.5, 0), "side": side * s, "phase": phase})

func _process_movers() -> void :
	var t: = race_time + 3.0
	for m in movers:

		var lat: float = 3.3 + 1.8 * sin(t * 1.3 + m["phase"])
		m["b"].global_position = m["base"] + m["side"] * lat

func _build_obstacles(info: Dictionary) -> void :
	var cells: Array = info["cells"]; var dirs: Array = info["dirs"]
	var n: = cells.size()
	var rng: = RandomNumberGenerator.new();rng.seed = hash(track_def["id"] + "obs")
	var hard: = track_index >= Game.TRACKS.size() - 2
	var kinds: = ["crates", "cones", "narrow", "barrels", "bump", "cones"]
	if hard: kinds.append("mover")
	var k: = 0
	var i: = 5
	while i < n - 2:
		var straight: bool = dirs[i] == dirs[i - 1] and dirs[i] == dirs[(i + 1) % n]
		if not straight: i += 1;continue
		var dir: Vector3 = dirs[i]; var side: = dir.cross(Vector3.UP)
		var c: Vector3 = points[i]
		var s: = 1.0 if rng.randf() < 0.5 else -1.0
		var kind: String = kinds[k % kinds.size()];k += 1
		var first: = obstacles.size()
		match kind:
			"crates":
				_static_box(c + side * s * 3.7 + Vector3(0, 0.7, 0), Vector3(1.4, 1.4, 1.4), rng.randf() * 0.4, Color(0.62, 0.42, 0.22))
				_static_box(c + side * s * 3.9 + dir * 1.6 + Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 1.2), rng.randf(), Color(0.55, 0.37, 0.2))
				_static_box(c + side * s * 3.75 + dir * 0.6 + Vector3(0, 1.75, 0), Vector3(1.0, 0.7, 1.0), 0.3, Color(0.7, 0.5, 0.27))
				wp_offset[i] = - s * 1.8
			"barrels":
				for q in 3: _barrel(c + side * s * (3.2 + 0.9 * (q % 2)) + dir * (q - 1) * 1.3)
				wp_offset[i] = - s * 1.8
			"cones":

				for q in 5: _cone(c + side * s * (1.2 + q * 0.75) + dir * (q * 1.4 - 2.8))
				wp_offset[i] = - s * 2.6
			"narrow":
				_static_box(c + side * 4.5 + Vector3(0, 0.5, 0), Vector3(2.4, 1.0, 5.0) if dir.x == 0 else Vector3(5.0, 1.0, 2.4), 0.0, Color(0.85, 0.85, 0.88))
				_static_box(c - side * 4.5 + Vector3(0, 0.5, 0), Vector3(2.4, 1.0, 5.0) if dir.x == 0 else Vector3(5.0, 1.0, 2.4), 0.0, Color(0.85, 0.85, 0.88))
				for q in 2: _cone(c + side * (3.2 if q == 0 else -3.2) - dir * 3.4)
				wp_offset[i] = 0.0
			"bump":
				_bump(c, dir)
				wp_offset[i] = 0.0
			"mover":
				_mover(c, side, s, rng.randf() * TAU)
				wp_offset[i] = - s * 3.0
		for oi in range(first, obstacles.size()): obstacles[oi].set_meta("kind", kind)
		i += 3 if hard else 4

func _make_vehicle(car_id: String, paint: int, shared: = false) -> Vehicle:
	var c: = Game.car_def(car_id)
	var scene_path: = "res://scenes/vehicle-motorcycle.tscn" if c["bike"] else "res://scenes/vehicle.tscn"
	var v: Vehicle = Game.scene(scene_path).instantiate()
	if not c["bike"]:
		var cont: = v.get_node("Container")
		var old: = cont.get_node("Model")
		cont.remove_child(old);old.free()
		var m: Node3D = Game.scene(c["model"]).instantiate();m.name = "Model"
		cont.add_child(m);cont.move_child(m, 0)
	Paint.apply(v.get_node("Container/Model"), car_id, paint, shared)
	return v

func _spawn_racers() -> void :
	var p0: Vector3 = points[0]
	var d: Vector3 = (points[1] - points[0]).normalized()
	var side: = d.cross(Vector3.UP)
	var ai_cars: = ["red", "purple", "green", "yellow"]
	var cup2: bool = int(track_def.get("cup", 1)) == 2
	var count: = 1 if mode in ["time_trial", "checkpoint"] else (4 if mode == "elimination" else (8 if cup2 else 5))

	var pid: String = Game.data["car"]
	var plook: int = Game.paint_of(pid) if Game.paint_of(pid) > 0 else int(FACTORY_LOOK.get(pid, -1))
	var pool: Array = []
	for ci in range(1, Paint.COLORS.size()):
		if ci != plook: pool.append(ci)
	pool.shuffle()
	ai_cars.shuffle()
	ai_paints = []
	for k in count:

		var is_player: = k == (1 if mode == "elimination" else count - 1)
		var car_id: String = Game.data["car"] if is_player else ai_cars[k % ai_cars.size()]
		var ap: int = Game.paint_of(car_id) if is_player else int(pool[k % pool.size()])
		if not is_player: ai_paints.append(ap)
		var v: = _make_vehicle(car_id, ap, is_player)
		add_child(v)
		v.sphere.collision_mask = 1 | 8 | 16
		if weather == "night": WeatherFX.car_lights(v, is_player, bool(Game.car_def(car_id)["bike"]), quality)
		var row: = k / 2
		var s: = (1.0 if k % 2 == 0 else -1.0) * (1.6 if count > 1 else 0.0)
		v.place(p0 - d * (1.5 + row * 3.6) + side * s, d)
		var r: = {"v": v, "wp": 0, "lap": 0, "done": false, "time": 0.0, "name": "YOU" if is_player else AI_NAMES[k], 
			"player": is_player, "stuck": 0.0, "progress": 0.0}
		r["out"] = false
		v.sphere.body_entered.connect( func(b): _on_hit(r, b))
		if is_player:
			v.stats = Game.car_stats(car_id)
			v.assist = true;v.steer_sens = float(Game.data["settings"].get("steer", 1.0))
			if weather == "rain": v.stats["handling"] *= 0.92;v.stats["drift"] *= 1.12
			player = r
			if Game.autotest and OS.get_environment("TTR_PSKILL") != "":
				v.stats["speed"] *= float(OS.get_environment("TTR_PSKILL"));v.stats["accel"] *= float(OS.get_environment("TTR_PSKILL"))
		else:
			v.stats = Game.car_stats(car_id) if false else Game.car_def(car_id)["base"].duplicate()
			v.volume_offset = -12.0
		if not is_player or (Game.autotest and not Game.autotest_human):
			var ai: = AIDriver.new();ai.race = self;ai.racer = r
			var dd: Dictionary = Game.difficulty()
			ai.lane = randf_range(-0.9, 0.9);ai.skill = randf_range(dd["skill"][0], dd["skill"][1]) if not is_player else 1.0
			r["ai"] = ai;v.ai = ai
		racers.append(r)
	var cam: = ChaseCam.new();cam.target = player["v"];cam.mode = clamp(int(Game.data["settings"].get("camera", 1)), 0, ChaseCam.MODES.size() - 1);cam.current = true
	view = cam;add_child(cam)


	cam._process(0.0)
	if weather == "rain":
		rain_fx = WeatherFX.rain(cam, quality)

		if Game.perf_mode and Game.is_mobile() and not (Game.native_mobile() and quality >= 2): rain_fx.amount = int(rain_fx.amount * 0.6)
	if mode == "elimination": elim_seg = points.size() if int(track_def.get("cup", 1)) == 1 else points.size() / 2


func _physics_process(delta: float) -> void :
	match state:
		"loading":
			_ld_phys += 1;_process_movers();return
		"flyby", "tips":
			_process_movers();return
		"countdown":


			if _drawn_frames < 4 or _prewarm_left != 0: _process_movers();return
			countdown -= delta
			var c: = int(ceil(countdown))
			if c != last_count and c <= 3:
				last_count = c
				if c > 0: l_center.text = str(c);Sound.play("beep")
				else:
					l_center.text = tr("GO!");Sound.play("go");state = "racing"
					for r in racers: r["v"].enabled = true
					Ads.gameplay_start()
					if touch and touch.active and not bool(Game.data.get("tip_pause_controls", false)) and l_toast:
						Game.data["tip_pause_controls"] = true;Game.save_game()
						l_toast.text = tr("Change controls anytime in Pause  II");l_toast.modulate.a = 1.0
						var ttw: = l_toast.create_tween();ttw.tween_interval(3.5);ttw.tween_property(l_toast, "modulate:a", 0.0, 0.6)
		"racing", "done":
			if state == "done" and countdown < -1.5: l_center.text = ""
			race_time += delta
			if countdown < -1.0 and l_center.text == "GO!": l_center.text = ""
			countdown -= delta
	_process_movers()
	if state == "countdown": return
	pickups.update(delta)
	for r in racers:
		if not r["out"]: skids.mark(r["v"], r["v"].drift_intensity > 0.45 and r["v"].speed_mps() > 4.0)
	if mode == "checkpoint" and state == "racing":
		time_left -= delta
		if time_left <= 0.0: time_left = 0.0;_checkpoint_failed()
	_update_racers(delta)
	if state == "racing": _player_drift_nitro(delta)
	_update_ghost(delta)
	_update_hud()

func _update_racers(delta: float) -> void :
	var n: = points.size()
	for r in racers:
		var v: Vehicle = r["v"]
		var p: = v.get_vehicle_position()
		var target: Vector3 = points[r["wp"] %n]
		var nxt: Vector3 = points[(r["wp"] + 1) % n]
		var dist: = Vector2(p.x - target.x, p.z - target.z).length()
		var passed: = dist < Game.CELL * 0.43 or (dist < Game.CELL and (p - target).dot((nxt - target).normalized()) > 0.0)
		if passed and not r["done"] and not r["out"]:
			if mode == "checkpoint" and r["player"] and cp_next < cps.size() and r["wp"] %n == cps[cp_next] and r["wp"] > 0:
				_checkpoint_passed()
			if r["wp"] %n == 0:
				r["lap"] += 1
				if r["player"]:
					if r["lap"] > 1:
						best_lap = min(best_lap, race_time - lap_start)
						if r["lap"] <= LAPS and mode != "elimination": Sound.play("lap");_flash(tr("LAP %d/%d") % [r["lap"], LAPS])
					lap_start = race_time
				if r["lap"] > LAPS:
					r["done"] = true;r["time"] = race_time;finish_order.append(r)
					v.enabled = false if not r["player"] else v.enabled
					if r["player"]: _player_finished()
			r["wp"] = (r["wp"] + 1)
			r["stuck"] = 0.0

		r["progress"] = float(r["wp"]) - clamp(dist / Game.CELL, 0.0, 1.0) + (1000.0 - r["time"] if r["done"] else 0.0) - (100000.0 - r.get("out_order", 0) if r["out"] else 0.0)
		if passed and mode == "elimination" and not r["out"]: _check_elimination()

		if v.enabled and not r["done"] and not r["out"]:
			if v.speed_mps() < 1.0: r["stuck"] += delta
			else: r["stuck"] = max(0.0, r["stuck"] - delta)
			var manual: bool = r["player"] and Input.is_action_just_pressed("reset")
			if r["stuck"] > 2.5 or p.y < -4.0 or v.vehicle_model.global_basis.y.y < 0.2 or manual:
				_respawn(r)
				if r["player"]: rs["respawns"] += 1

	for r in racers:
		if r["player"] or not r.has("ai"): continue
		var diff: float = player["progress"] - r["progress"]
		var band: Array = Game.difficulty()["band"]
		r["v"].boost = clamp(1.0 + diff * 0.035, band[0], band[1]) * r["ai"].skill * ai_boost * (1.4 if r.get("pad_t", 0.0) > 0.0 else 1.0)
		r["pad_t"] = max(0.0, r.get("pad_t", 0.0) - delta)
		if r["done"]: r["v"].boost = 0.6

func _respawn(r: Dictionary) -> void :
	var n: = points.size()
	var i: int = max(r["wp"] - 1, 0) % n
	var a: Vector3 = points[i]; var b: Vector3 = points[(i + 1) % n]
	r["v"].place(a, (b - a).normalized())
	r["stuck"] = 0.0

func _player_drift_nitro(delta: float) -> void :
	var v: Vehicle = player["v"]
	if v.drift_intensity > 0.35 and v.speed_mps() > 4.0:
		drift_pts += delta * 60.0 * v.drift_intensity;drift_cool = 0.35
	else:
		drift_cool -= delta
		if drift_cool <= 0.0 and drift_pts > 0.0:
			if drift_pts >= 15.0:
				var pts: = int(drift_pts)
				drift_total += pts;rs["drift"] = drift_total
				nitro = min(1.0, nitro + pts / 250.0)
				l_drift.text = "+%d DRIFT!" % pts;l_drift.modulate.a = 1.0
			drift_pts = 0.0
	v.touch_input = touch.drive_input() if touch else Vector2.ZERO
	v.tilt_steer = touch != null and touch.active and touch.tilt
	v.steer_sens = float(Game.data["settings"].get("steer", 1.0))
	if touch: touch.set_nitro_charge(nitro)
	var held: bool = Input.is_action_pressed("nitro") or (touch != null and touch.nitro)
	v.nitro_held = held and not player["done"]
	var want: bool = (held or (Game.autotest and not Game.autotest_human and nitro > 0.6)) and nitro > 0.0 and not player["done"]
	if want and not v.nitro_active: Sound.play("nitro");rs["nitro_uses"] += 1;Game.stat_add("nitro_uses")
	v.nitro_active = want or pad_boost_t > 0.0
	if want: nitro = max(0.0, nitro - delta * 0.35)
	else: nitro = min(1.0, nitro + delta * 0.01)
	pad_boost_t = max(0.0, pad_boost_t - delta)
	v.boost = (1.35 if want else 1.0) * (1.3 if pad_boost_t > 0.0 else 1.0)
	rs["max_kmh"] = max(float(rs["max_kmh"]), v.speed_mps() * 3.6 * 1.6)
	l_drift.modulate.a = max(0.0, l_drift.modulate.a - delta * 0.7)

func _player_finished() -> void :
	state = "done"
	Ads.gameplay_stop()
	player["v"].ai = AIDriver.new();player["v"].ai.race = self;player["v"].ai.racer = player
	player["v"].boost = 0.6
	_flash(tr("FINISH!"))
	Sound.play("lap", 1.2)
	var fpos: = position_of(player)
	if (mode in ["time_trial", "checkpoint"]) or fpos <= 3:
		FX.confetti(hud, get_viewport().get_visible_rect().size, quality)
	if mode == "time_trial": _save_ghost_if_best()
	await get_tree().create_timer(2.0).timeout
	hud.visible = false
	for c in hud.get_children():
		if c is CanvasLayer: c.visible = false
	race_finished.emit(_result())

func position_of(r: Dictionary) -> int:
	var sorted: = racers.duplicate()
	sorted.sort_custom( func(a, b): return a["progress"] > b["progress"])
	return sorted.find(r) + 1

func _result() -> Dictionary:
	var pos: = position_of(player)
	var res: = {"mode": mode, "track": track_index, "position": pos, "racers": racers.size(), "time": player["time"], 
		"best_lap": best_lap, "drift": drift_total, "weather": weather, "finished": not player.get("failed", false) and not player["out"]}
	var coins: = 0; var stars: = 1
	if mode == "checkpoint":
		var par: float = Game.track_par(track_index)
		if res["finished"]:
			stars = 3 if player["time"] <= par * 1.03 else (2 if player["time"] <= par * 1.15 else 1)
			coins = 70 + int(time_left) * 2
		else:
			stars = 0;coins = 15 + cp_next * 5
	elif mode == "elimination":
		coins = [170, 110, 70, 40][clamp(pos - 1, 0, 3)]
		stars = 3 if pos == 1 else (2 if pos == 2 else 1)
	elif mode == "time_trial":
		var par: float = Game.track_par(track_index)
		stars = 3 if player["time"] <= par else (2 if player["time"] <= par * 1.15 else 1)
		coins = 60 + (60 if res.get("new_record", false) else 0)
	else:
		coins = [200, 145, 110, 85, 65, 50, 40, 30][clamp(pos - 1, 0, 7)] if racers.size() > 5 else [150, 105, 75, 50, 30][clamp(pos - 1, 0, 4)]
		stars = 3 if pos == 1 else (2 if pos <= 3 else 1)
	coins += min(drift_total / 25, 60)
	coins = int(round(coins * float(Game.difficulty()["reward"])))
	res["pickup_coins"] = int(rs["coins"]) * Progress.COIN_VALUE
	coins += res["pickup_coins"]
	missions = Progress.evaluate(missions, rs, res)
	res["missions"] = missions
	res["mission_bonus"] = 0
	for m in missions:
		if m["done"]: res["mission_bonus"] += Progress.MISSION_BONUS
	coins += res["mission_bonus"]
	res["stats"] = rs.duplicate()
	var prev_best: float = float(Game.data["best"].get(track_def["id"], 99999.0))
	res["new_record"] = res["finished"] and mode in ["race", "time_trial", "daily", "checkpoint"] and player["time"] < prev_best
	if mode == "time_trial" and res["new_record"]: coins += 60
	if mode == "daily" and pos == 1 and Game.data["daily_done"] != Game.today():
		res["daily_bonus"] = int(Game.daily_info()["reward"]);coins += res["daily_bonus"]
	res["coins"] = coins;res["stars"] = stars
	res["xp"] = 20 + (racers.size() - pos) * 10 if res["finished"] else 10
	return res


func _ghost_path() -> String: return "user://ghost_%s.json" % track_def["id"]

func _update_ghost(delta: float) -> void :
	if mode != "time_trial": return
	ghost_t += delta
	var v: Vehicle = player["v"]
	if not player["done"] and int(race_time * 10) >= ghost_rec.size():
		var p: = v.get_vehicle_position()
		ghost_rec.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01), snappedf(v.vehicle_model.global_rotation.y, 0.001)])
	if ghost_node and ghost_play.size() > 1:
		var f: = race_time * 10.0
		var i: int = min(int(f), ghost_play.size() - 2)
		var a: Array = ghost_play[i]; var b: Array = ghost_play[i + 1]
		var t: float = clamp(f - i, 0.0, 1.0)
		ghost_node.global_position = Vector3(a[0], a[1], a[2]).lerp(Vector3(b[0], b[1], b[2]), t)
		ghost_node.global_rotation.y = lerp_angle(float(a[3]), float(b[3]), t)

func _load_ghost() -> void :
	if not FileAccess.file_exists(_ghost_path()): return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_ghost_path()))
	if not (parsed is Dictionary): return
	ghost_play = parsed["frames"]
	ghost_node = Game.scene(Game.car_def(parsed.get("car", "yellow"))["model"]).instantiate()
	add_child(ghost_node)
	for m in ghost_node.find_children("*", "MeshInstance3D", true, false):
		var mat: = StandardMaterial3D.new();mat.albedo_color = Color(0.6, 0.85, 1.0, 0.45)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material_override = mat;m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _save_ghost_if_best() -> void :
	var prev: float = float(Game.data["best"].get(track_def["id"], 99999.0))
	if player["time"] < prev:
		var f: = FileAccess.open(_ghost_path(), FileAccess.WRITE)
		f.store_string(JSON.stringify({"time": player["time"], "car": Game.data["car"], "frames": ghost_rec}))


func _build_hud() -> void :
	hud = CanvasLayer.new();add_child(hud)
	var root: = Control.new();root.set_anchors_preset(Control.PRESET_FULL_RECT);root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.make_theme();hud.add_child(root)
	_hud_root = root
	if Game.native_mobile():
		_fit_hud_safe_area();get_viewport().size_changed.connect(_fit_hud_safe_area)

	var tl: = UI.panel();tl.position = Vector2(20, 16);root.add_child(tl)
	var h: = UI.hbox(24);tl.add_child(h)
	var v1: = UI.vbox(0);v1.add_child(UI.label("POS", 18, Color(1, 0.82, 0.3)));l_pos = UI.label("1/5", 44);v1.add_child(l_pos);h.add_child(v1)
	var v2: = UI.vbox(0);v2.add_child(UI.label("OUT" if mode == "elimination" else "LAP", 18, Color(1, 0.82, 0.3)));l_lap = UI.label("1/3", 44);v2.add_child(l_lap);h.add_child(v2)
	if mode in ["time_trial", "checkpoint"]: l_pos.get_parent().visible = false

	var tc: = UI.panel();tc.set_anchors_preset(Control.PRESET_CENTER_TOP);tc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tc.position.y = 16;root.add_child(tc)
	var tv: = UI.vbox(0);tc.add_child(tv)
	l_time = UI.label("00:00.00", 36);l_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;tv.add_child(l_time)
	var best: float = float(Game.data["best"].get(track_def["id"], 0.0))
	l_best = UI.label((tr("BEST") + " " + fmt_time(best)) if best > 0 else track_def["name"], 16, Color(0.75, 0.85, 1));l_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;tv.add_child(l_best)

	var mp: = UI.panel();mp.set_anchors_preset(Control.PRESET_TOP_RIGHT);mp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mp.position = Vector2(-20, 16);root.add_child(mp)
	minimap = Minimap.new();minimap.race = self;minimap.custom_minimum_size = Vector2(210, 160);mp.add_child(minimap)

	var np: = UI.panel();np.set_anchors_preset(Control.PRESET_CENTER_BOTTOM);np.grow_horizontal = Control.GROW_DIRECTION_BOTH;np.grow_vertical = Control.GROW_DIRECTION_BEGIN
	np.position.y = -16;root.add_child(np)
	var bh: = UI.hbox(20);np.add_child(bh)
	var nv: = UI.vbox(2);bh.add_child(nv)
	nv.add_child(UI.label("NITRO", 16, Color(0.5, 0.85, 1)))
	nitro_bar = ProgressBar.new();nitro_bar.custom_minimum_size = Vector2(180, 20);nitro_bar.show_percentage = false;nitro_bar.max_value = 1.0
	var fill: = StyleBoxFlat.new();fill.bg_color = Color(0.3, 0.8, 1);fill.set_corner_radius_all(8);nitro_bar.add_theme_stylebox_override("fill", fill)
	var bgb: = StyleBoxFlat.new();bgb.bg_color = Color(0.2, 0.25, 0.4);bgb.set_corner_radius_all(8);nitro_bar.add_theme_stylebox_override("background", bgb)
	nitro_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nv.add_child(nitro_bar)
	var sv: = UI.vbox(0);bh.add_child(sv)
	l_speed = UI.label("0", 40);l_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;l_speed.custom_minimum_size.x = 110;sv.add_child(l_speed)
	var kmh: = UI.label("KM/H", 14, Color(1, 0.82, 0.3));kmh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;sv.add_child(kmh)

	l_center = UI.label("", 120, Color(1, 0.82, 0.25));l_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	l_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;l_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER;l_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l_center)
	l_drift = UI.label("", 40, Color(1, 0.78, 0.25));l_drift.set_anchors_preset(Control.PRESET_CENTER);l_drift.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l_drift.position.y = 110;l_drift.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;root.add_child(l_drift)

	var tr: = UI.hbox(10);tr.anchor_left = 1;tr.anchor_right = 1;tr.offset_left = -420;tr.offset_right = -270;tr.offset_top = 20
	tr.alignment = BoxContainer.ALIGNMENT_END;root.add_child(tr)
	var cb: = UI.button("CAM", _cycle_camera, 18, 70, "grey");cb.custom_minimum_size = Vector2(76, 64);cb.focus_mode = Control.FOCUS_NONE;tr.add_child(cb)
	var pb: = UI.button("II", _toggle_pause, 26, 64, "grey");pb.custom_minimum_size = Vector2(64, 64);pb.focus_mode = Control.FOCUS_NONE;tr.add_child(pb)
	touch = TouchControls.new();hud.add_child(touch)
	_build_pause()
	if TouchControls.layout_from_settings(Game.data["settings"]) == 2: TouchControls.tilt_probe(self, _tilt_unavailable)


var _hud_root: Control
func _fit_hud_safe_area() -> void :
	if not is_instance_valid(_hud_root): return
	var ins: = TouchControls.safe_insets(get_viewport().get_visible_rect().size)
	_hud_root.offset_left = ins.x;_hud_root.offset_right = - ins.y

func _cycle_camera() -> void :
	var o: Array = ChaseCam.ORDER
	var m: int = o[(max(0, o.find(int(Game.data["settings"].get("camera", 1)))) + 1) % o.size()]
	Game.data["settings"]["camera"] = m;Game.save_game()
	view.mode = m;view.snap()
	_flash(ChaseCam.display_name(m))

func _flash(t: String) -> void :
	l_center.text = t;countdown = 0.0

func _update_hud() -> void :
	l_lap.text = "%d/%d" % [clamp(player["lap"], 1, LAPS), LAPS]
	l_pos.text = "%d/%d" % [position_of(player), racers.filter( func(r): return not r["out"]).size()]
	l_time.text = fmt_time(race_time)
	if mode == "elimination":
		l_lap.text = "%d/%d" % [elim_done, racers.size() - 1]
	elif mode == "checkpoint":
		l_time.text = fmt_time(time_left)
		l_time.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if time_left < 5.0 else Color.WHITE)
	l_speed.text = str(int(player["v"].speed_mps() * 3.6 * 1.6))
	nitro_bar.value = nitro
	if countdown < -1.2 and state == "racing" and not player["done"] and l_center.text != "": l_center.text = ""
	minimap.queue_dots()

static func fmt_time(t: float) -> String:
	return "%02d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]

func _unhandled_input(e: InputEvent) -> void :
	if e.is_action_pressed("pause"): _toggle_pause()
	if e.is_action_pressed("camera") and not e.is_echo(): _cycle_camera()

func _build_pause() -> void :
	pause_layer = CanvasLayer.new();pause_layer.layer = 10;pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS;pause_layer.visible = false
	var pk: = PauseKey.new();pk.race = self;pk.process_mode = Node.PROCESS_MODE_WHEN_PAUSED;add_child(pk)
	add_child(pause_layer)
	var bg: = ColorRect.new();bg.color = Color(0, 0, 0, 0.55);bg.set_anchors_preset(Control.PRESET_FULL_RECT);bg.theme = UI.make_theme()
	pause_layer.add_child(bg)
	var v: = UI.vbox(16);v.add_child(UI.label("PAUSED", 56))
	v.add_child(UI.button("RESUME", _toggle_pause))
	v.add_child(UI.button("RESTART", func(): get_tree().paused = false;race_finished.emit({"restart": true}), 26, 280, "yellow"))
	v.add_child(UI.button("QUIT", func(): get_tree().paused = false;quit_requested.emit(), 26, 280, "grey"))
	if Game.perf_mode: v.add_child(_pause_graphics())
	var h: = UI.hbox(36);h.alignment = BoxContainer.ALIGNMENT_CENTER;h.add_child(v)
	pause_controls = _build_pause_controls();h.add_child(pause_controls)
	bg.add_child(UI.center(h))
	_show_pause_tab(0)



var _gfx_btns: Array = []
func _pause_graphics() -> Control:
	var v: = UI.vbox(6);v.name = "PauseGraphics"
	var l: = UI.label("GRAPHICS", 18, Color(1, 0.82, 0.3));l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;v.add_child(l)
	var row: = UI.hbox(4);row.alignment = BoxContainer.ALIGNMENT_CENTER;v.add_child(row)
	_gfx_btns.clear()
	for i in 4:
		var b: = Button.new();b.name = "Gfx%d" % i;b.text = tr(["AUTO", "LOW", "MED", "HIGH"][i]);b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(68, 48);b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect( func(): Game.set_quality_choice(i);Game.save_game();quality = Game.quality_level();_sync_gfx())
		row.add_child(b);_gfx_btns.append(b)
	_sync_gfx()
	return v

func _sync_gfx() -> void :
	var cur: = Game.quality_choice()
	for i in _gfx_btns.size():
		var b: Button = _gfx_btns[i]; var on: = i == cur
		var sb: = StyleBoxFlat.new();sb.set_corner_radius_all(10);sb.set_border_width_all(3 if on else 2)
		sb.bg_color = Color(1.0, 0.78, 0.18) if on else Color(0.12, 0.15, 0.26, 0.95)
		sb.border_color = Color(1, 1, 1) if on else Color(1, 1, 1, 0.25)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]: b.add_theme_stylebox_override(st, sb)
		var fc: = Color(0.12, 0.1, 0.05) if on else Color(0.9, 0.92, 1.0)
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]: b.add_theme_color_override(st, fc)





var pause_controls: Control
var _preset_btns: Array = []
var _pause_tab_btns: Array = []
var _pause_pages: Array = []
var _pause_tab: = 0
var _pause_pages_box: Control
var _nitro_btns: Array = []
var _cam_btn: Button
const PRESET_INFO: = [["MANUAL GAS", "pedal"], ["AUTO GAS", "brake"], ["TILT", "tilt"]]
const PAUSE_TABS: = ["CONTROLS", "BUTTONS", "SOUND & CAMERA"]
func _build_pause_controls() -> Control:
	var s: Dictionary = Game.data["settings"]
	var p: = UI.panel();p.name = "PauseControls"; var v: = UI.vbox(12);p.add_child(v)
	var tabs: = UI.hbox(8);tabs.name = "PauseTabs";tabs.alignment = BoxContainer.ALIGNMENT_CENTER;v.add_child(tabs)
	_pause_tab_btns.clear();_pause_pages.clear()
	for i in PAUSE_TABS.size():
		var tb: = Button.new();tb.name = "Tab%d" % i;tb.text = tr(PAUSE_TABS[i]);tb.focus_mode = Control.FOCUS_NONE
		tb.custom_minimum_size = Vector2(150, 50);tb.add_theme_font_size_override("font_size", 16)
		tb.pressed.connect( func(): _show_pause_tab(i))
		tabs.add_child(tb);_pause_tab_btns.append(tb)
	var pages: = Control.new();pages.name = "Pages";v.add_child(pages);_pause_pages_box = pages

	var c: = UI.vbox(10);c.name = "PageControls"
	var row: = UI.hbox(10);c.add_child(row)
	_preset_btns.clear()
	for i in 3:
		var b: = Button.new();b.name = "Preset%d" % i;b.toggle_mode = true;b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 108);b.text = tr(PRESET_INFO[i][0]);b.icon = TouchControls.icon(PRESET_INFO[i][1])
		b.expand_icon = true;b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER;b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 17);b.add_theme_constant_override("icon_max_width", 54)
		b.pressed.connect( func(): _set_preset(i))
		row.add_child(b);_preset_btns.append(b)
	c.add_child(_pause_slider("STEERING SENSITIVITY", 0.5, 1.5, "steer", 1.0))
	c.add_child(_pause_slider("TILT SENSITIVITY", 0.5, 2.0, "tilt_sens", 1.0))
	c.add_child(_pause_check("InvertTilt", "INVERT TILT", "tilt_invert", false))
	var rc: = UI.recalibrate_button(18);rc.focus_mode = Control.FOCUS_NONE;c.add_child(rc)

	var bt: = UI.vbox(10);bt.name = "PageButtons"
	bt.add_child(_pause_slider("BUTTON SIZE", 0.7, 1.4, "touch_size", 1.0))
	bt.add_child(_pause_slider("BUTTON OPACITY", 0.3, 1.0, "touch_opacity", 0.7))
	var nl: = UI.label("NITRO BUTTON", 18);bt.add_child(nl)
	var nrow: = UI.hbox(8);nrow.name = "NitroPos";bt.add_child(nrow)
	_nitro_btns.clear()
	for i in TouchControls.NITRO_POS_NAMES.size():
		var nb: = Button.new();nb.name = "Nitro%d" % i;nb.text = tr(TouchControls.NITRO_POS_NAMES[i]);nb.focus_mode = Control.FOCUS_NONE
		nb.custom_minimum_size = Vector2(146, 50);nb.add_theme_font_size_override("font_size", 15)
		nb.pressed.connect( func(): s["nitro_pos"] = i;_sync_pause_settings();_controls_changed())
		nrow.add_child(nb);_nitro_btns.append(nb)
	bt.add_child(_pause_check("Lefty", "LEFT-HANDED", "touch_lefty", false))
	bt.add_child(_pause_check("Vibration", "VIBRATION", "haptics", true))

	var g: = UI.vbox(10);g.name = "PageSound"
	g.add_child(_pause_slider("MUSIC", 0.0, 1.0, "music", 0.7, true))
	g.add_child(_pause_slider("SFX", 0.0, 1.0, "sfx", 0.8, true))
	g.add_child(_pause_check("Mute", "MUTE ALL", "mute", false, true))
	_cam_btn = UI.button("", func(): _cycle_camera();_sync_pause_settings(), 20, 420, "grey");_cam_btn.name = "Camera"
	_cam_btn.focus_mode = Control.FOCUS_NONE;_cam_btn.custom_minimum_size.y = 56;_cam_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	g.add_child(_cam_btn)
	g.add_child(_pause_check("Shake", "SCREEN SHAKE", "shake", true))
	for pg in [c, bt, g]: pages.add_child(pg);_pause_pages.append(pg)
	_sync_presets();_sync_pause_settings()
	return p


func _show_pause_tab(i: int) -> void :
	var has_touch: = touch != null and touch.active
	if not has_touch: i = 2
	_pause_tab = i
	_pause_tab_btns[0].get_parent().visible = has_touch
	var big: = Vector2.ZERO
	for k in _pause_pages.size():
		var pg: Control = _pause_pages[k]
		pg.visible = k == i
		big = big.max(pg.get_combined_minimum_size())
	_pause_pages_box.custom_minimum_size = big if has_touch else _pause_pages[2].get_combined_minimum_size()
	for k in _pause_tab_btns.size(): _style_choice(_pause_tab_btns[k], k == i)

func _pause_check(node_name: String, title: String, key: String, dflt: bool, audio: = false) -> CheckButton:
	var s: Dictionary = Game.data["settings"]
	var cb: = CheckButton.new();cb.name = node_name;cb.text = tr(title);cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = bool(s.get(key, dflt));cb.add_theme_font_size_override("font_size", 20)
	cb.set_meta("key", key);cb.set_meta("dflt", dflt)
	cb.toggled.connect( func(x):
		s[key] = x
		if audio: Game.apply_audio();Game.save_game()
		else: _controls_changed())
	return cb



func _sync_pause_settings() -> void :
	if pause_controls == null: return
	var s: Dictionary = Game.data["settings"]
	for n in pause_controls.find_children("*", "HSlider", true, false):
		var sl: = n as HSlider
		if s.has(sl.name): sl.set_value_no_signal(float(s[sl.name]))
	for n in pause_controls.find_children("*", "CheckButton", true, false):
		if n.has_meta("key"): (n as CheckButton).set_pressed_no_signal(bool(s.get(n.get_meta("key"), n.get_meta("dflt"))))
	var np: = clampi(int(s.get("nitro_pos", 0)), 0, 2)
	for i in _nitro_btns.size(): _style_choice(_nitro_btns[i], i == np)
	if _cam_btn: _cam_btn.text = tr("CAMERA") + ": " + ChaseCam.display_name(int(s.get("camera", 1)))
	_sync_presets();_sync_gfx()

func _style_choice(b: Button, on: bool) -> void :
	var sb: = StyleBoxFlat.new();sb.set_corner_radius_all(10);sb.set_border_width_all(3 if on else 2)
	sb.bg_color = Color(1.0, 0.78, 0.18) if on else Color(0.12, 0.15, 0.26, 0.95)
	sb.border_color = Color(1, 1, 1) if on else Color(1, 1, 1, 0.25)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]: b.add_theme_stylebox_override(st, sb)
	var fc: = Color(0.12, 0.1, 0.05) if on else Color(0.9, 0.92, 1.0)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]: b.add_theme_color_override(st, fc)

func _pause_slider(title: String, lo: float, hi: float, key: String, dflt: float, audio: = false) -> Control:
	var s: Dictionary = Game.data["settings"]
	var row: = UI.hbox(12); var l: = UI.label(title, 18);l.custom_minimum_size.x = 190;row.add_child(l)
	var sl: = HSlider.new();sl.name = key;sl.min_value = lo;sl.max_value = hi;sl.step = 0.05;sl.value = float(s.get(key, dflt))
	sl.custom_minimum_size = Vector2(250, 44);sl.focus_mode = Control.FOCUS_NONE
	if audio: sl.value_changed.connect( func(x): s[key] = x;Game.apply_audio();Game.save_game())
	else: sl.value_changed.connect( func(x): s[key] = x;_controls_changed())
	row.add_child(sl)
	return row

func _set_preset(i: int) -> void :
	var s: Dictionary = Game.data["settings"]
	s["touch_layout"] = i;s["auto_accel"] = i == 1;s["steer_mode"] = 1 if i == 2 else 0
	_sync_presets();_controls_changed()
	if i == 2: TouchControls.tilt_probe(self, _tilt_unavailable)


func _tilt_unavailable() -> void :
	if TouchControls.layout_from_settings(Game.data["settings"]) != 2: return
	print("[tilt] no sensor events -> Auto Gas")
	_set_preset(1)
	if l_toast:
		l_toast.text = tr("Tilt not available on this device/browser");l_toast.modulate.a = 1.0
		var tw: = l_toast.create_tween();tw.tween_interval(3.0);tw.tween_property(l_toast, "modulate:a", 0.0, 0.5)

func _sync_presets() -> void :
	var cur: = TouchControls.layout_from_settings(Game.data["settings"])
	for i in _preset_btns.size():
		var b: Button = _preset_btns[i]; var on: = i == cur;b.set_pressed_no_signal(on)
		var sb: = StyleBoxFlat.new();sb.set_corner_radius_all(12);sb.set_border_width_all(4 if on else 2)
		sb.bg_color = Color(1.0, 0.78, 0.18) if on else Color(0.12, 0.15, 0.26, 0.95)
		sb.border_color = Color(1, 1, 1) if on else Color(1, 1, 1, 0.25)
		sb.content_margin_top = 10;sb.content_margin_bottom = 8
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]: b.add_theme_stylebox_override(st, sb)
		var fc: = Color(0.12, 0.1, 0.05) if on else Color(0.9, 0.92, 1.0)
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]: b.add_theme_color_override(st, fc)


func _controls_changed() -> void :
	if touch: touch.reload_settings()
	Game.save_game()


class PauseKey extends Node:
	var race
	func _unhandled_input(e: InputEvent) -> void :
		if e.is_action_pressed("pause") and race.pause_layer.visible and not Ads.is_held():
			get_viewport().set_input_as_handled();race._toggle_pause()



var pause_by: = ""
func _toggle_pause(src: = "player") -> void :
	if state == "done" or state == "loading": return
	get_tree().paused = not get_tree().paused
	pause_by = src if get_tree().paused else ""
	pause_layer.visible = get_tree().paused
	if pause_controls and get_tree().paused: _sync_pause_settings();_show_pause_tab(_pause_tab)
	if touch: touch.reload_settings()
	if get_tree().paused: Ads.gameplay_stop()
	else: Ads.gameplay_start()

func _notification(what: int) -> void :


	var bg: = what == NOTIFICATION_APPLICATION_PAUSED and state in ["racing", "countdown"]
	if (bg or what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "racing") and not get_tree().paused and not Game.autotest:
		_toggle_pause("blur")


func on_pickup(kind: String) -> void :
	match kind:
		"coin":
			rs["coins"] += 1;Game.stat_add("coins_picked");Sound.play("coin", 1.3)
		"nitro":
			nitro = min(1.0, nitro + 0.35);Sound.play("nitro", 1.4);_toast_small(tr("NITRO +"))

func on_boost_pad(r: Dictionary) -> void :
	if r["player"]:
		pad_boost_t = 1.2;rs["pads"] += 1;Sound.play("nitro", 0.8)
		if view: view.add_shake(0.25)
	else:
		r["pad_t"] = 1.2

func _on_hit(r: Dictionary, body: Node) -> void :
	if state == "countdown" or r["out"]: return
	var v: Vehicle = r["v"]
	var spd: = v.speed_mps()
	if spd < 3.0: return
	var is_wall: = body is GridMap or body is StaticBody3D or body is AnimatableBody3D
	if not is_wall: return
	var pos: = v.sphere.global_position + v.forward() * 0.4
	FX.sparks(self, pos, - v.forward(), quality)
	if r["player"]:
		rs["wall_hits"] += 1
		if view: view.add_shake(clamp(spd / 14.0, 0.2, 0.9))

func _toast_small(t: String) -> void :
	if l_toast == null: return
	l_toast.text = t;l_toast.modulate.a = 1.0
	var tw: = l_toast.create_tween();tw.tween_interval(1.0);tw.tween_property(l_toast, "modulate:a", 0.0, 0.5)


const CP_EVERY: = 6
func _cp_seconds_per_tile() -> float:

	var per_tile: float = Game.track_par(track_index) / float(Game.laps_for(track_index) * points.size())
	return per_tile * [1.3, 1.17, 1.07][clamp(int(Game.data["settings"].get("difficulty", 1)), 0, 2)]

func _build_checkpoints() -> void :
	var n: = points.size()
	var i: = CP_EVERY
	while i < n - 2:
		cps.append(i);i += CP_EVERY
	cps.append(0)
	var dirs: Array = info["dirs"]
	for idx in cps:
		var c: Vector3 = points[idx]; var d: Vector3 = dirs[idx]


		var cl: Array = info["cells"]
		var into: Vector2i = cl[idx] - cl[(idx - 1 + n) % n]
		if Vector3(into.x, 0, into.y) != d: d = (Vector3(into.x, 0, into.y) + d).normalized()
		var side: = d.cross(Vector3.UP)
		var gate: = Node3D.new();gate.set_meta("prop", "gate");add_child(gate)
		var mat: StandardMaterial3D = _mats.get("gate")
		if mat == null:
			mat = StandardMaterial3D.new();mat.albedo_color = Color(0.2, 0.9, 1.0);mat.emission_enabled = true;mat.emission = Color(0.1, 0.7, 1.0);mat.emission_energy_multiplier = 1.5;_mats["gate"] = mat
		for sgn in [-1.0, 1.0]:
			var post: = MeshInstance3D.new(); var pm: = BoxMesh.new();pm.size = Vector3(0.3, 3.2, 0.3);post.mesh = pm;post.material_override = mat
			post.position = c + side * sgn * 5.4 + Vector3(0, 1.6, 0);gate.add_child(post)
		var bar: = MeshInstance3D.new(); var bm: = BoxMesh.new();bm.size = Vector3(11.0, 0.4, 0.2);bar.mesh = bm;bar.material_override = mat
		bar.rotation.y = atan2( - side.z, side.x);bar.position = c + Vector3(0, 3.2, 0);gate.add_child(bar)
	cp_next = 0
	time_left = CP_EVERY * _cp_seconds_per_tile() + 4.0

func _checkpoint_passed() -> void :
	var n: = points.size()
	var from_idx: int = cps[cp_next - 1] if cp_next > 0 else 0
	cp_next += 1
	if cp_next >= cps.size(): cp_next = 0
	var to_idx: int = cps[cp_next]
	var tiles: = (to_idx - from_idx + n) % n
	if tiles == 0: tiles = n
	var add: = tiles * _cp_seconds_per_tile()
	time_left += add
	Sound.play("lap", 1.4)
	_toast_small("+%.1f s" % add)

func _checkpoint_failed() -> void :
	if player["done"]: return
	player["failed"] = true;player["done"] = true;player["time"] = race_time
	_flash(tr("TIME UP!"))
	_player_finished()


var _out_count: = 0
func _check_elimination() -> void :
	var lead: = 0.0
	var alive: Array = racers.filter( func(r): return not r["out"])
	for r in alive: lead = max(lead, float(r["wp"] - 1))
	var seg: = int(lead / float(elim_seg)) if elim_seg > 0 else 0
	while seg > elim_done and alive.size() > 1:
		elim_done += 1
		alive.sort_custom( func(a, b): return a["progress"] > b["progress"])
		var last: Dictionary = alive.pop_back()
		_out_count += 1
		last["out"] = true;last["out_order"] = _out_count;last["v"].enabled = false
		last["v"].visible = false;last["v"].sphere.freeze = true;last["v"].sphere.collision_layer = 0
		_flash(tr("%s OUT!") % (tr("YOU") if last["player"] else last["name"]))
		Sound.play("beep", 0.6)
		if last["player"]:
			player["time"] = race_time;player["done"] = true
			_player_finished();return
	if alive.size() == 1 and alive[0]["player"] and not player["done"]:
		player["done"] = true;player["time"] = race_time
		_player_finished()


func _start_flyby() -> void :
	state = "flyby";flyby_t = 0.0
	flyby_cam = Camera3D.new();flyby_cam.far = 400;add_child(flyby_cam);flyby_cam.current = true
	l_center.text = ""
	_toast_small(tr("TAP TO SKIP"))

var _drawn_frames: = 0
func _process(delta: float) -> void :
	if _drawn_frames < 4: _drawn_frames += 1
	if _prewarm_left > 0:
		_prewarm_left -= 1
		if _prewarm_left == 0: _prewarm_done()
	if state == "loading": _loading_tick()
	_mission_check_t -= delta
	if _mission_check_t <= 0.0 and mission_panel and state == "racing": _mission_check_t = 0.15;_update_missions()
	if state == "flyby":
		flyby_t += delta
		var T: = 4.5
		var k: float = clamp(flyby_t / T, 0.0, 1.0)
		var lo: Vector3 = info["lo"]; var hi: Vector3 = info["hi"]
		var mid: = (lo + hi) / 2.0
		var ext: float = max(hi.x - lo.x, hi.z - lo.z)
		var start: Vector3 = player["v"].get_vehicle_position()
		var a: = lerpf(0.0, PI * 0.9, k)
		var far_pos: = mid + Vector3(cos(a) * ext * 0.6, ext * 0.45, sin(a) * ext * 0.6)
		var near_pos: Vector3 = view.global_position if view.global_position != Vector3.ZERO else start + Vector3(0, 4, -8)
		var e: = k * k * (3.0 - 2.0 * k)
		flyby_cam.global_position = far_pos.lerp(near_pos, pow(e, 3.0))
		flyby_cam.look_at(mid.lerp(start, e), Vector3.UP)
		if flyby_t >= T: _end_flyby()
	elif state == "racing" and Game.perf_mode:
		_auto_perf(delta)
	elif state == "racing" and not fps_checked:
		fps_acc += delta;fps_frames += 1
		if fps_acc >= 6.0:
			fps_checked = true
			var fps: = fps_frames / fps_acc
			if fps < 24.0 and bool(Game.data["settings"].get("auto_quality", true)) and int(Game.data["settings"]["quality"]) > 0 and not Game.autotest:
				Game.data["settings"]["quality"] = int(Game.data["settings"]["quality"]) - 1
				Game.apply_settings();Game.save_game()
				quality = int(Game.data["settings"]["quality"])
				if rain_fx: rain_fx.amount = max(150, rain_fx.amount / 2)
				for n in get_children():
					if n is DirectionalLight3D and quality == 0: n.shadow_enabled = false
				_toast_small(tr("Graphics lowered for smoother play"))



var _perf_win: = 0.0; var _perf_n: = 0; var _perf_steps: = 0
func _auto_perf(delta: float) -> void :
	if Game.quality_choice() != 0 or Game.autotest and not OS.has_feature("web") and OS.get_environment("TTR_AUTOPERF") != "1": return


	if delta > 0.25: _perf_win = 0.0;_perf_n = 0;return
	_perf_win += delta;_perf_n += 1
	if _perf_win < 5.0: return
	var fps: = _perf_n / _perf_win
	_perf_win = 0.0;_perf_n = 0
	var s: Dictionary = Game.data["settings"]
	var cap: = Engine.max_fps if Engine.max_fps > 0 else 60
	var floor_fps: = 50.0 if Game.native_mobile() else 40.0
	if fps >= min(floor_fps, cap * 0.9) or _perf_steps >= 6: return
	_perf_steps += 1
	if quality > 0:
		s["auto_level"] = quality - 1
	elif float(s.get("auto_scale", 1.0)) > 0.62:
		s["auto_scale"] = max(0.6, float(s.get("auto_scale", 1.0)) * 0.85)
	else:
		return
	Game.apply_settings();Game.save_game()
	quality = Game.quality_level()
	if rain_fx and quality == 0: rain_fx.amount = max(120, rain_fx.amount / 2)
	print("[perf] auto: fps %.0f -> level %d scale %.2f cap %d" % [fps, quality, get_viewport().scaling_3d_scale, Engine.max_fps])
	if _perf_steps == 1: _toast_small(tr("Graphics lowered for smoother play"))









const _PW_LAYERS: = [1 << 9, 1 << 10, 1 << 11, (1 << 10) | (1 << 11)]
var _prewarm_left: = -1
var _pw_root: Node3D
var _pw_masks: = {}
func _prewarm() -> void :
	var cam: = get_viewport().get_camera_3d()
	if cam == null or not is_inside_tree(): _prewarm_left = 0;return
	var at: = cam.global_position - cam.global_basis.z * 4.0
	FX.sparks(self, at, Vector3.UP, max(1, quality))

	for r in racers: r["v"].smoke_t = 0.2
	var meshes: = {}
	var parts: Array = []
	var stack: Array = [self]
	while stack.size():
		var n: Node = stack.pop_back()
		for ch in n.get_children(): stack.append(ch)
		if n is GPUParticles3D:
			if n != rain_fx: parts.append(n)
			for i in n.draw_passes:
				var dm: Mesh = n.get_draw_pass_mesh(i)
				if dm: meshes["p%d_%d" % [dm.get_instance_id(), (n.material_override.get_instance_id() if n.material_override else 0)]] = [dm, n.material_override]
		elif n is MeshInstance3D and n.mesh:
			var ov: Material = n.material_override
			if ov == null and n.get_surface_override_material_count() > 0: ov = n.get_surface_override_material(0)
			meshes["m%d_%d" % [n.mesh.get_instance_id(), ov.get_instance_id() if ov else 0]] = [n.mesh, ov]
		elif n is MultiMeshInstance3D and n.multimesh and n.multimesh.mesh:
			var ov2: Material = n.material_override
			meshes["m%d_%d" % [n.multimesh.mesh.get_instance_id(), ov2.get_instance_id() if ov2 else 0]] = [n.multimesh.mesh, ov2]
		elif n is GridMap and n.mesh_library:
			for id in n.mesh_library.get_item_list():
				var gm: Mesh = n.mesh_library.get_item_mesh(id)
				if gm: meshes["g%d" % gm.get_instance_id()] = [gm, null]
	_pw_root = Node3D.new();_pw_root.name = "ShaderWarmup"
	cam.add_child(_pw_root);_pw_root.position = Vector3(0, 0, -3.0)

	var has_omni: = false; var has_spot: = false
	for n in find_children("*", "Light3D", true, false):
		if n is OmniLight3D: has_omni = true
		if n is SpotLight3D: has_spot = true
		if not (n is DirectionalLight3D): _pw_masks[n] = n.light_cull_mask;n.light_cull_mask &= ~ ((1 << 9) | (1 << 10) | (1 << 11))

	var sets: = [0]
	if has_omni: sets.append(1)
	if has_spot: sets.append(2)
	if has_omni and has_spot: sets.append(3)
	var omni: = OmniLight3D.new();omni.omni_range = 3.0;omni.light_energy = 0.01;omni.light_cull_mask = 1 << 10;_pw_root.add_child(omni)
	var spot: = SpotLight3D.new();spot.spot_range = 6.0;spot.spot_angle = 60.0;spot.light_energy = 0.01;spot.light_cull_mask = 1 << 11
	_pw_root.add_child(spot);spot.position = Vector3(0, 0, 1.5)
	var k: = 0
	for key in meshes.keys():
		var mesh: Mesh = meshes[key][0]; var ov: Material = meshes[key][1]
		for li in sets:
			var pos: = Vector3(((k % 10) - 4.5) * 0.004, ((k / 10) % 10 - 4.5) * 0.004, -0.05 * li)
			var mi: = MeshInstance3D.new();mi.mesh = mesh;mi.material_override = ov;mi.layers = _PW_LAYERS[li]
			mi.scale = Vector3.ONE * 0.002;mi.position = pos;_pw_root.add_child(mi)
			var mm: = MultiMesh.new();mm.transform_format = MultiMesh.TRANSFORM_3D;mm.mesh = mesh;mm.instance_count = 1
			mm.set_instance_transform(0, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.002), pos + Vector3(0, 0.03, 0)))
			var mmi: = MultiMeshInstance3D.new();mmi.multimesh = mm;mmi.material_override = ov;mmi.layers = _PW_LAYERS[li];_pw_root.add_child(mmi)
		k += 1
	for pnode in parts:
		var d: GPUParticles3D = pnode.duplicate()
		d.one_shot = true;d.amount = 1;d.emitting = true;d.position = Vector3(0, 0, 0);d.scale = Vector3.ONE * 0.01
		_pw_root.add_child(d)
	_prewarm_left = 4

func _prewarm_done() -> void :
	for n in _pw_masks.keys(): if is_instance_valid(n): n.light_cull_mask = _pw_masks[n]
	_pw_masks.clear()
	if _pw_root and is_instance_valid(_pw_root): _pw_root.queue_free()
	_pw_root = null

func _end_flyby() -> void :
	if state != "flyby": return
	state = "countdown"
	if flyby_cam: flyby_cam.queue_free();flyby_cam = null
	view.current = true;view.snap()

func _input(e: InputEvent) -> void :
	if state == "flyby" and ((e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed) or (e is InputEventKey and e.pressed)):
		_end_flyby();get_viewport().set_input_as_handled()


const TIPS: = [
	["HOW TO PLAY", "Steer with the left side of the screen (or A/D, arrow keys). The car accelerates by itself on touch screens."], 
	["DRIFT & NITRO", "Hold a turn at speed to drift. Drifting fills your nitro - press NITRO (Shift) for a burst of speed."], 
	["PICKUPS", "Grab coins for cash, blue canisters for nitro, and drive over orange pads for a speed boost."], 
]
var _tip_i: = 0
func _show_tips() -> void :
	state = "tips"
	tips_layer = CanvasLayer.new();tips_layer.layer = 20;add_child(tips_layer)
	_render_tip()

func _render_tip() -> void :
	for c in tips_layer.get_children(): c.queue_free()
	var bg: = ColorRect.new();bg.color = Color(0, 0, 0, 0.6);bg.set_anchors_preset(Control.PRESET_FULL_RECT);bg.theme = UI.make_theme();tips_layer.add_child(bg)
	var p: = UI.panel(); var v: = UI.vbox(16);p.add_child(v);p.custom_minimum_size = Vector2(640, 0)
	var t: = UI.label(TIPS[_tip_i][0], 40, Color(1, 0.82, 0.3));t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;v.add_child(t)
	var body: = UI.label(TIPS[_tip_i][1], 24);body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;body.custom_minimum_size.x = 600;v.add_child(body)
	v.add_child(UI.label("%d / %d" % [_tip_i + 1, TIPS.size()], 18, Color(0.8, 0.85, 1)))
	var last: = _tip_i == TIPS.size() - 1
	var b: = UI.button("GOT IT!" if last else "NEXT", func():
		if last:
			Game.data["tips_seen"] = true;Game.save_game();tips_layer.queue_free();tips_layer = null
			state = "countdown"
			if bool(Game.data["settings"].get("flyby", true)): _start_flyby()
		else:
			_tip_i += 1;_render_tip(), 24, 260)
	b.name = "TipNext";b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER;v.add_child(b)
	bg.add_child(UI.center(p))




var mission_rows: = {}
var l_mission_done: Label
var _mission_check_t: = 0.0
func _build_mission_panel() -> void :
	var p: = PanelContainer.new();p.name = "MissionPanel";p.position = Vector2(16, 112);p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: = StyleBoxFlat.new();sb.bg_color = Color(0.05, 0.07, 0.16, 0.55);sb.set_corner_radius_all(10)
	sb.content_margin_left = 10;sb.content_margin_right = 10;sb.content_margin_top = 6;sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	var v: = UI.vbox(2);v.mouse_filter = Control.MOUSE_FILTER_IGNORE;p.add_child(v)
	v.add_child(UI.label("MISSIONS", 14, Color(1, 0.82, 0.3)))
	for i in missions.size():
		var m: Dictionary = missions[i]
		var row: = UI.hbox(8);row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t: = UI.label("• " + Progress.mission_text(m), 14, Color(0.92, 0.94, 1));t.custom_minimum_size.x = 0
		row.add_child(t)
		var pr: = UI.label("", 14, Color(0.6, 0.95, 1));row.add_child(pr)
		v.add_child(row)
		mission_rows[i] = {"row": row, "text": t, "prog": pr, "done": false}
	hud.get_child(0).add_child(p)
	mission_panel = p
	l_mission_done = UI.label("", 34, Color(0.45, 1, 0.55));l_mission_done.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l_mission_done.grow_horizontal = Control.GROW_DIRECTION_BOTH;l_mission_done.position.y = 170;l_mission_done.modulate.a = 0.0
	l_mission_done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;l_mission_done.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l_mission_done.add_theme_color_override("font_outline_color", Color(0.05, 0.25, 0.08));l_mission_done.add_theme_constant_override("outline_size", 8)
	hud.get_child(0).add_child(l_mission_done)
	_update_missions(true)

func _update_missions(force: = false) -> void :
	for i in mission_rows.keys():
		var r: Dictionary = mission_rows[i]
		if r["done"]: continue
		var m: Dictionary = missions[i]
		var lp: = Progress.live_progress(m, rs)
		if int(lp[1]) <= 0: continue
		var cur: int = min(int(lp[0]), int(lp[1]))
		var txt: = "%d/%d" % [cur, int(lp[1])]
		if (r["prog"] as Label).text != txt or force: (r["prog"] as Label).text = txt
		if int(lp[0]) >= int(lp[1]) and state == "racing": _mission_complete(i)

func _mission_complete(i: int) -> void :
	var r: Dictionary = mission_rows[i];r["done"] = true
	missions[i]["live_done"] = true
	var row: HBoxContainer = r["row"]; var t: Label = r["text"]; var pr: Label = r["prog"]
	t.text = "✔ " + Progress.mission_text(missions[i]);t.add_theme_color_override("font_color", Color(0.45, 1, 0.55))
	pr.text = ""
	Sound.play("lap", 1.25);Sound.play("coin", 1.6)
	row.pivot_offset = row.size * Vector2(0, 0.5)
	var tw: = row.create_tween()
	tw.tween_property(row, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(row, "modulate", Color(1.6, 1.9, 1.6, 1), 0.12)
	tw.tween_property(row, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(row, "modulate", Color(1, 1, 1, 1), 0.25)
	tw.tween_interval(1.6)
	tw.tween_property(row, "modulate:a", 0.0, 0.5)
	tw.tween_callback( func(): row.visible = false)

	l_mission_done.text = "✔ " + tr("MISSION COMPLETE!")
	l_mission_done.pivot_offset = Vector2(l_mission_done.size.x / 2.0, 20)
	l_mission_done.scale = Vector2(0.4, 0.4);l_mission_done.modulate.a = 1.0
	var t2: = l_mission_done.create_tween()
	t2.tween_property(l_mission_done, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_property(l_mission_done, "scale", Vector2.ONE, 0.12)
	t2.tween_interval(1.1);t2.tween_property(l_mission_done, "modulate:a", 0.0, 0.4)
	if Game.autotest: print("[mission] complete during race: %s" % missions[i]["id"])
	mission_completed.emit(i)

	l_toast = UI.label("", 28, Color(0.6, 0.95, 1));l_toast.set_anchors_preset(Control.PRESET_CENTER_TOP);l_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l_toast.position.y = 120;l_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;l_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.get_child(0).add_child(l_toast)

func _exit_tree() -> void :
	for p in _saved_envs:

		if is_instance_valid(p[0]) and p[0].environment == my_env: p[0].environment = p[1]











const LD_MIN_S: = 0.5
const LD_TIPS: = ["Tip: let go of nitro before tight corners.", "Tip: drift through corners to fill the nitro bar.", 
	"Tip: press R to get back on the track.", "Tip: press C to change the camera.", "Tip: win races for coins and unlock new cars in the garage.", 
	"Tip: in Time Trial you race against your best lap.", "Tip: some keyboards can't take Space + two arrow keys at once. Use Shift for nitro."]
var ld_layer: CanvasLayer
var ld_bar: ProgressBar
var _ld_t0: = 0
var _ld_last: = 0
var _ld_good: = 0
var _ld_phys: = 0
var _ld_shown: = 0.0
var _ld_wait_since: = 0
var _ld_min_dt: = 100000
static var ld_last_ms: = 0

func _begin_loading() -> void :
	state = "loading"
	_ld_t0 = Time.get_ticks_msec();_ld_last = _ld_t0
	ld_layer = CanvasLayer.new();ld_layer.layer = 30;ld_layer.name = "Loading";add_child(ld_layer)
	var bg: = ColorRect.new();bg.color = Color(0.07, 0.09, 0.16);bg.set_anchors_preset(Control.PRESET_FULL_RECT);bg.theme = UI.make_theme()
	bg.mouse_filter = Control.MOUSE_FILTER_STOP;ld_layer.add_child(bg)
	var p: = UI.panel(); var v: = UI.vbox(14);p.add_child(v);p.custom_minimum_size = Vector2(620, 0)
	var t: = UI.label(String(track_def["name"]).to_upper(), 44, Color(1, 0.82, 0.3));t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;v.add_child(t)
	UI.fit_font(t, 580, 44, 22)
	var mode_names: = {"race": "RACE", "time_trial": "TIME TRIAL", "elimination": "ELIMINATION", "checkpoint": "CHECKPOINT", "daily": "DAILY CHALLENGE"}
	var sub: = UI.label(tr(mode_names.get(mode, mode.to_upper())) + "   •   " + tr(String(weather).to_upper()), 22, Color(0.8, 0.88, 1))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;v.add_child(sub);UI.fit_font(sub, 580, 22, 12)
	var cd: Dictionary = Game.car_def(Game.data["car"])
	var cl: = UI.label(String(cd.get("name", "")), 28);cl.name = "Car";cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;v.add_child(cl)
	ld_bar = ProgressBar.new();ld_bar.name = "Bar";ld_bar.min_value = 0;ld_bar.max_value = 1;ld_bar.step = 0.0;ld_bar.show_percentage = false
	ld_bar.custom_minimum_size = Vector2(560, 22)
	var fill: = StyleBoxFlat.new();fill.bg_color = Color(0.35, 0.85, 0.35);fill.set_corner_radius_all(8)
	var back: = StyleBoxFlat.new();back.bg_color = Color(0, 0, 0, 0.45);back.set_corner_radius_all(8)
	ld_bar.add_theme_stylebox_override("fill", fill);ld_bar.add_theme_stylebox_override("background", back)
	v.add_child(ld_bar)
	var l: = UI.label(tr("LOADING") + "…", 18, Color(0.8, 0.85, 1));l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;v.add_child(l)
	var tips: Array = LD_TIPS.duplicate()
	if Game.is_mobile(): tips = tips.filter( func(x): return not ("press" in x or "Space" in x))
	var tip: = UI.label(tr(tips[randi() % tips.size()]), 20, Color(1, 1, 1, 0.9));tip.name = "Tip"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;tip.custom_minimum_size.x = 580;tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;v.add_child(tip)
	var cc: = UI.center(p);cc.set_anchors_preset(Control.PRESET_FULL_RECT);bg.add_child(cc)
	Sound.warm()
	var pv = player["v"]
	for snd in [pv.screech_sound, pv.impact_sound]:
		if snd and snd.stream:
			var vol: float = snd.volume_db;snd.volume_db = -80.0;snd.play()
			get_tree().create_timer(0.15, false).timeout.connect( func(): if is_instance_valid(snd): snd.stop();snd.volume_db = vol)
	_prewarm.call_deferred()

func _loading_tick() -> void :
	var now: = Time.get_ticks_msec()
	var dt: = now - _ld_last;_ld_last = now
	var warm_done: = _prewarm_left == 0
	if warm_done:
		if _ld_wait_since == 0: _ld_wait_since = now

		if now != _ld_wait_since: _ld_min_dt = mini(_ld_min_dt, dt)
		_ld_good = _ld_good + 1 if (dt < 50 or dt < _ld_min_dt * 1.6) and now != _ld_wait_since else 0

	var target: = 0.15
	if _prewarm_left > 0: target = 0.15 + 0.6 * (4.0 - _prewarm_left) / 4.0
	elif warm_done: target = 0.75 + 0.25 * min(1.0, min(_ld_good / 3.0, _ld_phys / 30.0))
	_ld_shown = max(_ld_shown, target) if target >= 1.0 else lerpf(_ld_shown, target, 0.35)
	if ld_bar: ld_bar.value = _ld_shown
	var settled: = _ld_good >= 3 or (warm_done and now - _ld_wait_since > 2500)
	if warm_done and settled and _ld_phys >= 30 and now - _ld_t0 >= LD_MIN_S * 1000: _end_loading()

func _end_loading() -> void :
	ld_last_ms = Time.get_ticks_msec() - _ld_t0
	print("loading screen %d ms" % ld_last_ms)
	state = "countdown"
	get_viewport().gui_release_focus()
	view.snap()
	if ld_layer:
		var lay: = ld_layer;ld_layer = null;ld_bar = null
		var bg: Control = lay.get_child(0)
		var tw: = bg.create_tween();tw.tween_property(bg, "modulate:a", 0.0, 0.18);tw.tween_callback(lay.queue_free)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not bool(Game.data.get("tips_seen", false)) and not Game.autotest: _show_tips()
	elif bool(Game.data["settings"].get("flyby", true)) and ( not Game.autotest or OS.get_environment("TTR_FLYBY") == "1"): _start_flyby()
