class_name AutoTest extends RefCounted



var main
var dir: = ""

func run(m) -> void :
	main = m
	dir = OS.get_environment("TTR_SHOTS")
	if dir == "": dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	var track: = int(OS.get_environment("TTR_TRACK")) if OS.get_environment("TTR_TRACK") != "" else 0
	if OS.has_feature("web"):
		var q: = str(JavaScriptBridge.eval("location.search", true))
		var rm: = RegEx.create_from_string("track=(\\d+)").search(q)
		if rm: track = int(rm.get_string(1))
	var mode: = OS.get_environment("TTR_MODE") if OS.get_environment("TTR_MODE") != "" else "race"
	if OS.has_feature("web"):
		var mm: = RegEx.create_from_string("mode=(\\w+)").search(str(JavaScriptBridge.eval("location.search", true)))
		if mm: mode = mm.get_string(1)
	if OS.get_environment("TTR_TOUCH") == "1": Game.data["settings"]["touch"] = 1
	var tree: SceneTree = main.get_tree()
	if mode == "paintstress": await _paint_stress();return
	if mode == "touchpresets": await _touch_presets();return
	if mode == "adtest": await _ad_test();return
	if mode == "perftest": await _perf_test(track);return
	if mode == "tilttest": await _tilt_test();return
	if mode == "hero": await _hero_shot(track);return
	if mode == "nitrotest": await _nitro_test();return
	if mode == "camtest": await _cam_test();return
	if mode == "steertest": await _steer_test();return
	if mode == "tiltdrive": await _tilt_drive_test();return
	if mode == "starttest": await _start_test();return
	if mode == "androidtest": await _android_test();return
	if mode == "playshots": await _play_shots();return
	if mode == "gfxtest": await _gfx_test();return
	if mode == "soaktest": await _soak_test();return
	if mode == "propcheck": await _prop_check();return
	if mode == "pausetest": await _pause_test();return
	if mode == "proftest": await _prof_test();return
	if mode == "web":
		var w: = AutoTestWeb.new();main.add_child(w);w.setup(main);return
	if mode in ["matrix", "unit", "shots", "toastshot", "missionshots", "uishots", "padtest", "v7shots"]: await AutoTest4.new().run(main, mode, dir);return
	await tree.create_timer(2.0).timeout
	await _shot("1_title")
	if OS.get_environment("TTR_PAINT") != "": Game.data["paint"][Game.data["car"]] = int(OS.get_environment("TTR_PAINT"))
	main.show_garage(); await tree.create_timer(1.5).timeout; await _shot("2_garage")
	main.track_cup = 2 if track >= 5 else 1
	main.show_tracks("race"); await tree.create_timer(0.8).timeout; await _shot("3_tracks")
	main.show_settings(); await tree.create_timer(0.5).timeout; await _shot("3b_settings")
	main.start_race(track, mode)
	var t0: = Time.get_ticks_msec()
	await tree.create_timer(1.0).timeout; await _shot("4a_countdown")
	await tree.create_timer(22.0).timeout; await _shot("4_race_hud")
	var rr = main.race
	if main.race.touch and main.race.touch.active: await _touch_test()
	if OS.get_environment("TTR_OBSSHOT") != "":
		var rr2 = main.race
		var seen: = {}
		var shots: = 0
		for o in rr2.obstacles:
			var key: String = o.get_meta("kind", "x")
			if seen.has(key) or shots >= 6: continue
			seen[key] = true;shots += 1
			var oc: = Camera3D.new();rr2.add_child(oc);oc.fov = 55
			var op: Vector3 = o.global_position;op.y = 0
			oc.global_position = op + Vector3(7, 5, 7);oc.look_at(op + Vector3(0, 0.5, 0));oc.current = true
			await tree.create_timer(0.5).timeout; await _shot("obs_%d_%s" % [shots, key])
			oc.queue_free()
		rr2.view.current = true
	if OS.get_environment("TTR_CAMSHOTS") == "1":
		main.race._cycle_camera(); await tree.create_timer(2.0).timeout; await _shot("4b_cam_far")
		main.race._cycle_camera(); await tree.create_timer(2.0).timeout; await _shot("4c_cam_topdown")
		main.race._cycle_camera()
	while main.screen == null or not is_instance_valid(main.screen):
		await tree.create_timer(1.0).timeout
		if main.race and is_instance_valid(main.race):
			var r = main.race
			var v = r.player["v"]
			print("[autotest] fps=%d t=%.0f lap=%d wp=%d pos=%d p=%s in=%s ls=%.2f gnd=%s stuck=%.1f" % [Engine.get_frames_per_second(), r.race_time, r.player["lap"], r.player["wp"], r.position_of(r.player), v.get_vehicle_position().snapped(Vector3.ONE * 0.1), v.input.snapped(Vector3.ONE * 0.01), v.linear_speed, v.raycast.is_colliding(), r.player["stuck"]])
		if Time.get_ticks_msec() - t0 > 2400000:
			print("[autotest] FAIL: race did not finish");tree.quit(1);return
	await tree.create_timer(1.0).timeout
	await _shot("5_results")
	print("[autotest] PASS race finished. coins=%d xp=%d stars=%s best=%s" % [Game.data["coins"], Game.data["xp"], Game.data["stars"], Game.data["best"]])
	tree.quit(0)

func _touch(idx: int, pos: Vector2, pressed: bool) -> void :
	var e: = InputEventScreenTouch.new();e.index = idx;e.position = pos;e.pressed = pressed
	Input.parse_input_event(e)
	await main.get_tree().process_frame

func _drag(idx: int, pos: Vector2) -> void :
	var e: = InputEventScreenDrag.new();e.index = idx;e.position = pos
	Input.parse_input_event(e)
	await main.get_tree().process_frame

func _check(label: String, steer: float, brake: bool, nitro: bool) -> bool:
	var t = main.race.touch
	var ok: bool = t.steer == steer and t.brake == brake and t.nitro == nitro
	print("[touchtest] %s %s (steer=%d brake=%s nitro=%s)" % ["OK  " if ok else "FAIL", label, t.steer, t.brake, t.nitro])
	return ok

func _touch_test() -> void :
	var sh: Dictionary = main.race.touch.shapes()
	var brake: Vector2 = sh["brake"]["c"]; var nitro: Vector2 = sh["nitro"]["c"]
	var left: Vector2 = sh["left"]["c"]; var right: Vector2 = sh["right"]["c"]
	var all: = true
	await _touch(0, brake, true);all = _check("brake only", 0, true, false) and all
	await _touch(1, left, true);all = _check("brake + steer left", -1, true, false) and all
	await _touch(0, brake, false); await _touch(2, nitro, true);all = _check("nitro + left, brake released", -1, false, true) and all
	await _drag(1, right);all = _check("slide steer finger to right", 1, false, true) and all
	await _drag(2, brake);all = _check("nitro finger dragged onto brake stays nitro", 1, false, true) and all
	await main.get_tree().create_timer(0.3).timeout; await _shot("4d_touch_active")
	await _touch(1, right, false); await _touch(2, brake, false);all = _check("all released", 0, false, false) and all
	var gap: float = nitro.distance_to(brake) - sh["nitro"]["hs"].x - sh["brake"]["hs"].length()
	print("[touchtest] nitro/brake gap px = %.0f" % gap)
	print("[touchtest] %s" % ("PASS" if all else "FAIL"))

func _shot(name: String) -> void :
	await RenderingServer.frame_post_draw
	var img: Image = main.get_viewport().get_texture().get_image()
	if img: img.save_png(dir.path_join(name + ".png"));print("[autotest] shot ", name)



var _fails: = 0
func _ok(cond: bool, what: String) -> void :
	if not cond: _fails += 1;print("[paint] FAIL ", what)

func _frame_us() -> int:
	var t: = Time.get_ticks_usec(); await main.get_tree().process_frame;return Time.get_ticks_usec() - t

func _saved_paint() -> Dictionary:
	var f: = FileAccess.open(Game.SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text());return d["paint"] if d is Dictionary else {}

func _paint_stress() -> void :
	var tree: SceneTree = main.get_tree()
	var cycles: = int(OS.get_environment("TTR_CYCLES")) if OS.get_environment("TTR_CYCLES") != "" else 50
	await tree.create_timer(1.5).timeout
	print("[paint] warmup done=", main.paint_warm)
	Game.data["coins"] = 10000000;Game.data["xp"] = 100000
	for car in Game.CARS:
		if not Game.car_owned(car["id"]): Game.data["owned"].append(car["id"])

	main.garage_sel = "yellow";main.show_garage();for k in 5: await _frame_us()

	var idle: Array[int] = []
	for k in 60: idle.append( await _frame_us())
	idle.sort(); var base: int = idle[30]
	print("[paint] idle garage frame median %.1f ms" % (base / 1000.0))
	var old_max: = 0; var old_sum: = 0; var old_cpu: = 0
	for k in 20:
		var t0: = Time.get_ticks_usec();main.show_garage();old_cpu = max(old_cpu, Time.get_ticks_usec() - t0)
		var ft: int = await _frame_us();old_sum += ft;old_max = max(old_max, ft)
	print("[paint] old-style full rebuild per click: handler max %.1f ms, frame avg %.1f ms max %.1f ms" % [old_cpu / 1000.0, old_sum / 20000.0, old_max / 1000.0])
	var click_cpu_max: = 0; var click_cpu_sum: = 0
	var all_max: = 0; var spikes: = 0; var clicks: = 0; var sum: = 0; var frames: Array[int] = []
	var finals: = {}
	var ci: = 0
	for car in Game.CARS:
		var id: String = car["id"]
		main.garage_sel = id;main.show_garage()
		var sw: int = 0
		for k in 3: sw = max(sw, await _frame_us())
		print("[paint] open %s: first frames max %.1f ms" % [id, sw / 1000.0])
		for c in cycles:
			for i in Paint.COLORS.size():
				var idx: = (i + c) % Paint.COLORS.size()
				var tc: = Time.get_ticks_usec()
				main._swatches[idx].pressed.emit()
				var cc: int = Time.get_ticks_usec() - tc;click_cpu_max = max(click_cpu_max, cc);click_cpu_sum += cc
				if cc > 15000: print("[paint] slow click %s c=%d i=%d %.1f ms" % [id, c, idx, cc / 1000.0])

				_ok(Game.paint_of(id) == idx, "%s data %d" % [id, idx])
				_ok(Paint.current(id) == Paint.color_of(idx), "%s material %d" % [id, idx])
				var ft: int = await _frame_us()
				clicks += 1;sum += ft;all_max = max(all_max, ft);frames.append(ft)
				if ft > max(base * 2, base + 50000): spikes += 1

		var tgt: = 1 + ci % 8
		main._swatches[tgt].pressed.emit();main._swatches[tgt].pressed.emit()
		_ok(Game.paint_of(id) == tgt, "double fire")
		finals[id] = tgt;ci += 1
		await tree.create_timer(0.5).timeout
		_ok(int(_saved_paint().get(id, -1)) == tgt, "%s saved on disk" % id)

		var mat: = Paint.material_for(id)
		for b in main._previews[id].find_children("body", "MeshInstance3D", true, false): _ok(b.material_override == mat, "%s single material" % id)
	frames.sort()
	print("[paint] clicks=%d handler avg %.3f ms max %.3f ms | frame avg %.2f ms p99 %.2f ms max %.2f ms | spikes(>2x idle)=%d" % [clicks, click_cpu_sum / 1000.0 / clicks, click_cpu_max / 1000.0, sum / 1000.0 / clicks, frames[int(clicks * 0.99)] / 1000.0, all_max / 1000.0, spikes])
	_ok(spikes == 0, "frame spikes")
	_ok(click_cpu_max < 16000, "click handler stall")

	Game.data["coins"] = 0;main.garage_sel = "red";main.show_garage(); await tree.process_frame
	main._swatches[(finals["red"] %8) + 1].pressed.emit()
	_ok(Game.paint_of("red") == finals["red"] and main.last_toast.begins_with("Not enough coins: need $"), "paint no-coins toast")
	print("[paint] toast: ", main.last_toast)
	await tree.create_timer(0.3).timeout; await _shot("paint_no_coins_toast")
	var up_ok: bool = main._buy_upgrade("speed")
	_ok( not up_ok and main.last_toast.begins_with("Not enough coins"), "upgrade no-coins toast")
	Game.data["owned"].erase("purple")
	_ok( not main._buy_car(Game.car_def("purple")) and main.last_toast.begins_with("Not enough coins"), "car no-coins toast")
	Game.data["coins"] = 10000000
	_ok(main._buy_car(Game.car_def("purple")) and main.last_toast.begins_with("Bought"), "car bought toast")
	main.garage_sel = "purple";main.show_garage(); await tree.process_frame
	_ok(main._buy_upgrade("speed") and main.last_toast.contains("upgraded"), "upgrade toast")
	print("[paint] toast: ", main.last_toast)
	Game.data["coins"] = 10000000;Game.data["car"] = "yellow";Game.save_game()

	for id in ["yellow", "purple", "bike"]:
		Game.data["car"] = id;Game.save_game()
		main.start_race(0, "race"); await tree.create_timer(1.5).timeout
		var pv = main.race.player["v"]
		var bodies: Array = pv.get_node("Container/Model").find_children("body", "MeshInstance3D", true, false)
		_ok(bodies.size() > 0, "%s has body" % id)
		for b in bodies:
			var m: ShaderMaterial = b.material_override
			_ok(m != null and m.get_shader_parameter("paint") == Paint.color_of(finals[id]), "%s race colour" % id)
		if id == "yellow": await _shot("paint_race_%s" % id)
		main.race.queue_free();main.race = null;main.show_title(); await tree.create_timer(0.3).timeout

	Game.data = {};Game.load_game()
	for id in finals: _ok(Game.paint_of(id) == finals[id], "%s after reload" % id)
	print("[paint] finals=", finals, " reloaded=", Game.data["paint"])
	if _fails == 0: print("[paint] PASS");tree.quit(0)
	else: print("[paint] FAIL count=", _fails);tree.quit(1)



func _state() -> String:
	var t = main.race.touch
	return "s%d g%d b%d n%d" % [int(t.steer), int(t.gas), int(t.brake), int(t.nitro)]

func _expect(label: String, want: String) -> void :
	var got: = _state(); var ok: = got == want
	if not ok: _fails += 1
	print("[touchpreset] %s %s want=%s got=%s" % ["OK  " if ok else "FAIL", label, want, got])

func _touch_presets() -> void :
	var tree: SceneTree = main.get_tree()
	var s: Dictionary = Game.data["settings"]
	s["touch"] = 1;Game.data["tips_seen"] = true
	var cfgs: = [["A_manual", 0, false, 1.0, 0.7], ["B_auto", 1, false, 1.0, 0.7], ["C_tilt", 2, false, 1.0, 0.7], ["A_lefty", 0, true, 1.0, 0.7], ["B_big_opaque", 1, false, 1.35, 1.0], ["A_small_faint", 0, false, 0.75, 0.35]]
	for cf in cfgs:
		s["touch_layout"] = cf[1];s["touch_lefty"] = cf[2];s["touch_size"] = cf[3];s["touch_opacity"] = cf[4]
		main.start_race(0, "race"); await tree.create_timer(5.0).timeout
		var t = main.race.touch
		var sh: Dictionary = t.shapes()
		var vs: Vector2 = main.get_viewport().get_visible_rect().size
		var names: Array = sh.keys();names.sort()
		print("[touchpreset] %s controls=%s" % [cf[0], names])

		for a in names:
			var ra: = Rect2(sh[a]["c"] - sh[a]["hs"], sh[a]["hs"] * 2.0)
			if not Rect2(Vector2.ZERO, vs).encloses(ra): _fails += 1;print("[touchpreset] FAIL %s off screen" % a)
			for b in names:
				if a < b and Rect2(sh[a]["c"] - sh[a]["hs"] * 1.18, sh[a]["hs"] * 2.36).intersects(Rect2(sh[b]["c"] - sh[b]["hs"] * 1.18, sh[b]["hs"] * 2.36)):
					_fails += 1;print("[touchpreset] FAIL %s overlaps %s" % [a, b])
		await _shot_v5("%s_idle" % cf[0])

		var bit: = {"left": "s-1 g0 b0 n0", "right": "s1 g0 b0 n0", "gas": "s0 g1 b0 n0", "brake": "s0 g0 b1 n0", "nitro": "s0 g0 b0 n1"}
		for n in names:
			await _touch(0, sh[n]["c"], true);_expect("%s %s alone" % [cf[0], n], bit[n]); await _touch(0, sh[n]["c"], false)
		_expect("%s all released" % cf[0], "s0 g0 b0 n0")

		var i: = 0
		for n in names: await _touch(i, sh[n]["c"], true);i += 1
		var want: = "s%d g%d b%d n%d" % [(-1 if "left" in names else 0) + (1 if "right" in names else 0), int("gas" in names), int("brake" in names), int("nitro" in names)]
		_expect("%s all %d fingers" % [cf[0], names.size()], want)
		if "left" in names:
			await _touch(names.find("right"), sh["right"]["c"], false);_expect("%s right released" % cf[0], want.replace("s0", "s-1"))

			await _drag(names.find("left"), sh["right"]["c"]);_expect("%s steer slide" % cf[0], want.replace("s0", "s1"))
			await _drag(names.find("left"), sh["left"]["c"])
		if t.has_method("set_nitro_charge"): t.set_nitro_charge(1.0)
		await tree.create_timer(0.25).timeout; await _shot_v5("%s_pressed" % cf[0])
		for k in 8: await _touch(k, Vector2.ZERO, false)
		_expect("%s cleared" % cf[0], "s0 g0 b0 n0")

		var di: Vector2 = t.drive_input()
		var thr_ok: bool = (di.y == 1.0) == (cf[1] == 1)
		if not thr_ok: _fails += 1
		print("[touchpreset] %s %s idle throttle=%.0f (auto=%s)" % ["OK  " if thr_ok else "FAIL", cf[0], di.y, cf[1] == 1])
		main.race.queue_free();main.race = null;main.show_title(); await tree.create_timer(0.5).timeout
	main.show_settings(); await tree.create_timer(0.6).timeout
	var sc: Array = main.screen.find_children("*", "ScrollContainer", true, false)
	if sc.size() > 0: sc[0].scroll_vertical = 10000
	await tree.create_timer(0.3).timeout; await _shot_v5("settings_controls")
	print("[touchpreset] DONE fails=%d" % _fails)
	tree.quit(0 if _fails == 0 else 1)

func _shot_v5(name: String) -> void :
	await RenderingServer.frame_post_draw
	var img: Image = main.get_viewport().get_texture().get_image()
	if img: img.save_png(dir.path_join(name + ".png"));print("[autotest] shot ", name)



func _ad_test() -> void :
	var tree: SceneTree = main.get_tree()
	await tree.create_timer(2.0).timeout
	print("[adtest] provider=%s sdk_available=%s paused_at_boot=%s" % [Ads.provider, Ads.sdk_available(), tree.paused])
	var tw: = 0
	while tree.paused and tw < 200: await tree.create_timer(0.1, true, false, true).timeout;tw += 1
	Ads.test_force = true
	Ads._last_interstitial = -1000.0
	var probe: = {"paused": false, "muted": false}
	var watch: = func():
		if tree.paused: probe["paused"] = true
		if AudioServer.is_bus_mute(0): probe["muted"] = true
	tree.process_frame.connect(watch)
	var res: = {"inter": false, "inter2": false, "rew": null}
	print("[adtest] t=%.1f start interstitial" % (Time.get_ticks_msec() / 1000.0))
	Ads.show_interstitial( func(): res["inter"] = true)
	var t0: = Time.get_ticks_msec()
	while not res["inter"] and Time.get_ticks_msec() - t0 < 20000: await tree.create_timer(0.1, true, false, true).timeout
	print("[adtest] interstitial done=%s paused_during=%s muted_during=%s paused_after=%s muted_after=%s" % [res["inter"], probe["paused"], probe["muted"], tree.paused, AudioServer.is_bus_mute(0)])
	Ads.show_interstitial( func(): res["inter2"] = true)
	print("[adtest] second interstitial within 90s skipped immediately=%s" % res["inter2"])
	t0 = Time.get_ticks_msec()
	while not res["inter2"] and Time.get_ticks_msec() - t0 < 20000: await tree.create_timer(0.1, true, false, true).timeout
	print("[adtest] second interstitial done=%s paused_after=%s muted_after=%s" % [res["inter2"], tree.paused, AudioServer.is_bus_mute(0)])
	probe["paused"] = false;probe["muted"] = false
	t0 = Time.get_ticks_msec()
	while not Ads.rewarded_ready() and Time.get_ticks_msec() - t0 < 4000: await tree.create_timer(0.2, true, false, true).timeout
	print("[adtest] rewarded_gated=%s rewarded_ready=%s" % [Ads.rewarded_gated(), Ads.rewarded_ready()])
	Ads.show_rewarded( func(ok): res["rew"] = ok)
	t0 = Time.get_ticks_msec()
	while res["rew"] == null and Time.get_ticks_msec() - t0 < 30000: await tree.create_timer(0.1, true, false, true).timeout
	print("[adtest] rewarded ok=%s paused_during=%s muted_during=%s paused_after=%s muted_after=%s" % [res["rew"], probe["paused"], probe["muted"], tree.paused, AudioServer.is_bus_mute(0)])
	main.show_title();Sound.play_music("menu")
	print("[adtest] DONE")




func _perf_test(track: int) -> void :
	var tree: SceneTree = main.get_tree()
	var q: = str(JavaScriptBridge.eval("location.search", true)) if OS.has_feature("web") else ""
	var secs: = 12.0
	var m: = RegEx.create_from_string("secs=(\\d+)").search(q); if m: secs = float(m.get_string(1))
	m = RegEx.create_from_string("[?&]q=(\\d)").search(q)
	if m:
		if Game.has_method("set_quality_choice"): Game.call("set_quality_choice", int(m.get_string(1)))
		else: Game.data["settings"]["quality"] = clampi(int(m.get_string(1)) - 1, 0, 2);Game.apply_settings()
	Game.data["settings"]["flyby"] = false;Game.data["tips_seen"] = true
	await tree.create_timer(1.0).timeout
	print("[perf] quality_choice=%s level=%s scale3d=%.2f msaa=%d fps_cap=%d mobile=%s screen=%s" % [Game.data["settings"].get("quality_choice", -1), Game.data["settings"]["quality"], main.get_viewport().scaling_3d_scale, main.get_viewport().msaa_3d, Engine.max_fps, Game.call("is_mobile") if Game.has_method("is_mobile") else "n/a", DisplayServer.window_get_size()])
	var t_load: = Time.get_ticks_msec()
	main.start_race(track, "race")
	var r = main.race
	while r.state != "racing": await tree.process_frame
	print("[perf] race loaded+countdown in %d ms" % (Time.get_ticks_msec() - t_load))
	var ft: Array = []; var last: = Time.get_ticks_usec()
	var t0: = Time.get_ticks_msec()
	var dc: = 0.0; var prim: = 0.0; var tp: = 0.0; var tph: = 0.0
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		await tree.process_frame
		var now: = Time.get_ticks_usec();ft.append((now - last) / 1000.0);last = now
		dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME);prim += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		tp += Performance.get_monitor(Performance.TIME_PROCESS);tph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var nf: = float(max(1, ft.size()))
	print("[perf] per-frame: draw_calls=%.0f primitives=%.0f process_ms=%.2f physics_ms=%.2f" % [dc / nf, prim / nf, tp / nf * 1000.0, tph / nf * 1000.0])
	ft.remove_at(0)
	var sorted: = ft.duplicate();sorted.sort()
	var tot: = 0.0
	for x in ft: tot += x
	var hitch: = 0
	for x in ft: if x > 50.0: hitch += 1
	print("[perf] RESULT frames=%d avg_fps=%.1f avg_ms=%.1f p50_ms=%.1f p95_ms=%.1f p99_ms=%.1f max_ms=%.1f hitches_over_50ms=%d level_end=%s scale_end=%.2f" % [ft.size(), ft.size() / (tot / 1000.0), tot / ft.size(), sorted[int(sorted.size() * 0.5)], sorted[int(sorted.size() * 0.95)], sorted[int(sorted.size() * 0.99)], sorted[-1], hitch, Game.data["settings"]["quality"], main.get_viewport().scaling_3d_scale])
	print("[perf] DONE")



func _tilt_test() -> void :
	var tree: SceneTree = main.get_tree()
	var s: Dictionary = Game.data["settings"]
	s["touch"] = 1;s["touch_layout"] = 2;s["auto_accel"] = false;s["steer_mode"] = 1;s["flyby"] = false;Game.data["tips_seen"] = true
	await tree.create_timer(1.0).timeout
	main.start_race(0, "race")
	var r = main.race
	while r.state != "racing": await tree.process_frame
	print("[tilttest] racing tilt=%s events=%d" % [r.touch.tilt, TouchControls.tilt_events()])
	if str(JavaScriptBridge.eval("location.search", true)).contains("nosensor"):
		var tw: = Time.get_ticks_msec()
		while TouchControls.layout_from_settings(s) == 2 and Time.get_ticks_msec() - tw < 8000: await tree.create_timer(0.25, true, false, true).timeout
		print("[tilttest] fallback after %d ms" % (Time.get_ticks_msec() - tw))
		print("[tilttest] fallback layout=%d tilt=%s toast='%s'" % [TouchControls.layout_from_settings(s), r.touch.tilt, r.l_toast.text if r.l_toast.modulate.a > 0.1 else ""])
		print("[tilttest] DONE");return
	for ph in ["flat", "right90", "left90", "right270", "left270", "small90", "right0"]:
		JavaScriptBridge.eval("window.__tiltPhase='%s'" % ph, true)
		await tree.create_timer(0.7).timeout
		print("[tilttest] phase=%s raw=%.2f steer=%.2f angle=%s src=%s" % [ph, TouchControls.tilt_raw(), r.touch.drive_input().x, JavaScriptBridge.eval("window.__ttrTilt.angle", true), JavaScriptBridge.eval("window.__ttrTilt.src", true)])
	s["tilt_sens"] = 2.0
	JavaScriptBridge.eval("window.__tiltPhase='small90'", true); await tree.create_timer(0.7).timeout
	print("[tilttest] phase=small90 sens=2 steer=%.2f" % r.touch.drive_input().x)
	s["tilt_sens"] = 1.0
	print("[tilttest] layout_end=%d" % TouchControls.layout_from_settings(s))
	print("[tilttest] DONE")






func _env_f(k: String, d: float) -> float: return float(OS.get_environment(k)) if OS.get_environment(k) != "" else d
func _hero_shot(track: int) -> void :
	var tree: SceneTree = main.get_tree()
	Game.data["car"] = OS.get_environment("TTR_HERO_CAR") if OS.get_environment("TTR_HERO_CAR") != "" else "green"
	if not Game.car_owned(Game.data["car"]): Game.data["owned"].append(Game.data["car"])
	Game.data["paint"][Game.data["car"]] = int(_env_f("TTR_HERO_PAINT", 3.0))
	Game.data["settings"]["quality"] = 3;Game.data["settings"]["auto_quality"] = false
	Game.data["tips_seen"] = true;Game.data["settings"]["flyby"] = false
	seed(int(_env_f("TTR_HERO_SEED", 7.0)))
	main.start_race(track, "race")
	var r = main.race
	await tree.create_timer(3.6 + _env_f("TTR_HERO_T", 6.0)).timeout
	var pv = r.player["v"]
	var p0: Vector3 = pv.get_vehicle_position()
	var f0: Vector3 = p0 - r.view.global_position;f0.y = 0;f0 = f0.normalized()
	var pack: = OS.get_environment("TTR_HERO_PACK")
	if pack != "":
		var slots: = pack.split(";"); var k: = 0
		for rr in r.racers:
			if rr["player"]: continue
			if k < slots.size():
				var bs: = slots[k].split(",");rr["v"].place(p0 - f0 * float(bs[0]) + f0.cross(Vector3.UP) * float(bs[1]), f0)
			else: rr["v"].visible = false
			k += 1
		await tree.create_timer(0.5).timeout
	tree.paused = true
	for n in tree.root.find_children("*", "CanvasLayer", true, false): n.visible = false
	if OS.get_environment("TTR_HERO_NOLAMPS") == "1":
		for n in r.get_children():
			if n is MeshInstance3D and ((n.mesh is CylinderMesh and is_equal_approx(n.mesh.top_radius, 0.08)) or (n.mesh is SphereMesh and is_equal_approx(n.mesh.radius, 0.25))): n.visible = false
	var v = r.player["v"]
	for sl in v.find_children("*", "SpotLight3D", true, false):
		sl.light_energy = _env_f("TTR_HERO_SPOT", 0.0);sl.visible = sl.light_energy > 0.0
		sl.spot_attenuation = 2.0;sl.spot_angle = 45.0
	var c: = (OS.get_environment("TTR_HERO_CAM") if OS.get_environment("TTR_HERO_CAM") != "" else "7,2.5,1.6,3,50").split(",")
	var pos: Vector3 = v.get_vehicle_position()
	var fwd: Vector3 = pos - r.view.global_position;fwd.y = 0;fwd = fwd.normalized()
	var right: = fwd.cross(Vector3.UP)
	var cam: = Camera3D.new();cam.process_mode = Node.PROCESS_MODE_ALWAYS;r.add_child(cam)
	cam.fov = float(c[4]) if c.size() > 4 else 50.0
	cam.global_position = pos + fwd * float(c[0]) + right * float(c[1]) + Vector3(0, float(c[2]), 0)
	cam.look_at(pos - fwd * float(c[3]) + Vector3(0, float(c[5]) if c.size() > 5 else 0.3, 0));cam.current = true

	var rain: = WeatherFX.rain(r, 3);rain.process_mode = Node.PROCESS_MODE_ALWAYS;rain.amount = 1000
	(rain.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(12, 1, 8)
	rain.global_transform = Transform3D(Basis.looking_at(fwd), pos - fwd * 7.0 + Vector3(0, 14, 0))
	await tree.create_timer(1.5, true, false, true).timeout
	rain.speed_scale = 0.0
	await RenderingServer.frame_post_draw
	var name: = OS.get_environment("TTR_TAG") if OS.get_environment("TTR_TAG") != "" else "hero"
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("[hero] saved ", dir.path_join(name + ".png"))
	tree.quit()



func _nitro_phase(label: String, actions: Array, secs: float, gas: = true, bar: = 1.0, pre: Array = []) -> Dictionary:
	var tree: SceneTree = main.get_tree()
	main.start_race(0, "race")
	var r = main.race
	while r.state != "racing": await tree.physics_frame
	r.nitro = bar
	if gas: Input.action_press("forward")
	for a in pre: Input.action_press(a)
	for i in int(1.5 * 60): await tree.physics_frame
	var v = r.player["v"]
	var y0: float = v.vehicle_model.global_rotation.y; var p0: Vector3 = v.get_vehicle_position()
	for a in actions: Input.action_press(a)
	var yaw: = 0.0; var last: float = y0; var minv: = 999.0; var air: = 0
	var pp: Vector3 = p0; var h0: = INF; var hl: = 0.0; var travel: = 0.0
	for i in int(secs * 60):
		await tree.physics_frame
		if i % 6 == 5:
			var pn: Vector3 = v.get_vehicle_position(); var dv: = pn - pp;pp = pn
			if Vector2(dv.x, dv.z).length() > 0.05:
				var h: = atan2(dv.x, dv.z)
				if h0 == INF: h0 = h;hl = h
				else: travel += wrapf(h - hl, - PI, PI);hl = h
		var y: float = v.vehicle_model.global_rotation.y
		yaw += wrapf(y - last, - PI, PI);last = y
		minv = min(minv, v.speed_mps())
		if not v.raycast.is_colliding():
			air += 1
			if OS.get_environment("TTR_AIRDBG") == "1": print("   air f%d pos=%s vel=%s" % [i, v.sphere.global_position, v.sphere.linear_velocity])
	var out: = {"label": label, "yaw_deg": rad_to_deg(yaw), "travel_deg": rad_to_deg(travel), "dist": v.get_vehicle_position().distance_to(p0), "kmh": v.speed_mps() * 3.6 * 1.6, "min_kmh": minv * 3.6 * 1.6, 
		"in": v.input, "steer_out": v.steer_out, "nitro_on": v.nitro_active, "air_frames": air, "drift": v.drift_intensity}
	for a in actions + pre: Input.action_release(a)
	Input.action_release("forward")
	print("[nitrotest] %-22s travel=%6.1f deg yaw=%6.1f deg dist=%5.1f m kmh=%5.1f min_kmh=%5.1f input=%s steer_out=%.2f nitro_on=%s air=%d drift=%.2f" % [label, out["travel_deg"], out["yaw_deg"], out["dist"], out["kmh"], out["min_kmh"], v.input, v.steer_out, v.nitro_active, air, v.drift_intensity])
	return out

func _nitro_test() -> void :
	Game.autotest_human = true
	Game.data["settings"]["flyby"] = false;Game.data["tips_seen"] = true
	await main.get_tree().create_timer(0.5).timeout
	var a = await _nitro_phase("gas", [], 1.5)
	var b = await _nitro_phase("gas+nitro", ["nitro"], 1.5)
	var c = await _nitro_phase("gas+left", ["left"], 1.5)
	var d = await _nitro_phase("gas+left+nitro", ["left", "nitro"], 1.5)
	var e = await _nitro_phase("gas+right+nitro", ["right", "nitro"], 1.5)
	var f = await _nitro_phase("nitro+left, no gas key", ["nitro", "left"], 1.5, false)
	var g = await _nitro_phase("nitro, empty bar", ["nitro", "left"], 1.5, false, 0.0)
	var h = await _nitro_phase("at nitro speed +left", ["left"], 0.6, true, 1.0, ["nitro"])
	var c2 = await _nitro_phase("at top speed +left", ["left"], 0.6, true, 1.0)
	var ok: bool = b["dist"] > a["dist"] * 1.05 and absf(d["yaw_deg"]) > absf(c["yaw_deg"]) * 0.6 and d["dist"] > c["dist"] * 0.9 and absf(e["yaw_deg"]) > 30 and f["dist"] > 5.0 and absf(f["yaw_deg"]) > 30 and g["dist"] > 5.0 and absf(h["travel_deg"]) > 30 and absf(h["travel_deg"]) > absf(c2["travel_deg"]) * 0.7
	print("[nitrotest] %s" % ("PASS" if ok else "FAIL"))
	main.get_tree().quit(0 if ok else 1)



func _start_test() -> void :
	var tree: SceneTree = main.get_tree()
	Game.autotest_human = true
	Game.data["settings"]["flyby"] = OS.get_environment("TTR_FLYBY") == "1";Game.data["tips_seen"] = true
	await tree.create_timer(1.0).timeout
	var tracks: = [0, 0, 5, 9]
	for ti in tracks.size():
		var track: int = tracks[ti]
		main.show_title(); await tree.create_timer(0.6).timeout
		var t0: = Time.get_ticks_usec()
		main.start_race(track, "race")
		var t_build: = (Time.get_ticks_usec() - t0) / 1000.0
		var r = main.race
		var last: = Time.get_ticks_usec(); var frames: = []; var go_t: = -1.0
		while true:
			await tree.process_frame
			var now: = Time.get_ticks_usec(); var ms: = (now - last) / 1000.0;last = now
			var st: String = r.state
			if st == "racing" and go_t < 0: go_t = (now - t0) / 1000000.0
			frames.append([ms, st, (now - t0) / 1000000.0])
			if go_t > 0 and (now - t0) / 1000000.0 - go_t > 3.0: break
		var worst: = frames.duplicate();worst.sort_custom( func(a, b): return a[0] > b[0])
		var top: = []
		for i in min(6, worst.size()): top.append("%.0fms@%s+%.2fs" % [worst[i][0], worst[i][1], worst[i][2]])
		var mx_go: = 0.0; var mx_cd: = 0.0
		for f in frames:
			if f[1] == "racing": mx_go = max(mx_go, f[0])
			elif f[2] > 0.3: mx_cd = max(mx_cd, f[0])
		print("[starttest] race %d track=%d build_call=%.0fms first_frame=%.0fms max_countdown=%.0fms max_after_go=%.0fms worst=%s" % [ti, track, t_build, frames[0][0], mx_cd, mx_go, top])
	print("[starttest] DONE");tree.quit(0)


func _pt_measure(tree: SceneTree, n: int) -> float:
	var acc: = 0.0
	for i in n:
		await tree.process_frame
		acc += Performance.get_monitor(Performance.TIME_PROCESS)
	return acc / n * 1000.0

func _prof_test() -> void :
	var tree: SceneTree = main.get_tree()
	Game.autotest_human = true
	Game.data["settings"]["flyby"] = false;Game.data["tips_seen"] = true
	await tree.create_timer(0.5).timeout
	main.start_race(0, "race")
	var r = main.race
	while r.state != "racing": await tree.process_frame
	await tree.create_timer(1.0).timeout
	print("[prof] all on: process_ms=%.1f" % await _pt_measure(tree, 30))
	var groups: = {"race": [r], "cam": [r.view], "main": [main], "hud_layer": [], "vehicles": []}
	for rr in r.racers: groups["vehicles"].append(rr["v"])
	for name in groups.keys():
		for n in groups[name]: if n: n.set_process(false)
		print("[prof] without %s: process_ms=%.1f" % [name, await _pt_measure(tree, 30)])
		for n in groups[name]: if n: n.set_process(true)

	var cnt: = {}
	var stack: Array = [tree.root]
	while stack.size():
		var nd: Node = stack.pop_back()
		if nd.is_processing(): cnt[nd.get_class() + ":" + str(nd.get_script().resource_path.get_file() if nd.get_script() else "")] = cnt.get(nd.get_class() + ":" + str(nd.get_script().resource_path.get_file() if nd.get_script() else ""), 0) + 1
		for c in nd.get_children(): stack.append(c)
	print("[prof] processing nodes: ", cnt)
	var total: = 0
	stack = [tree.root]
	while stack.size():
		var nd: Node = stack.pop_back();total += 1
		for c in nd.get_children(): stack.append(c)
	print("[prof] nodes total=%d" % total)
	tree.quit(0)





func _cam_run(label: String, track: int, hitch_ms: int, fps_cap: int) -> Dictionary:
	var tree: SceneTree = main.get_tree()
	Engine.max_fps = fps_cap
	main.start_race(track, "race")
	var r = main.race
	while r.state != "racing": await tree.process_frame
	r.nitro = 1.0
	var v = r.player["v"]; var cam: Camera3D = r.view
	var lags: = []; var t: = 0.0; var worst: = 0.0; var maxlag: = 0.0; var minlag: = 999.0; var still: = 0; var still_max: = 0
	var last_cam: Vector3 = cam.global_position; var last_lag: = -1.0; var n: = 0; var next_hitch: = 1.5; var stalls: = 0
	var last_spd: float = v.speed_mps(); var crash_frames: = 0; var steady_frames_only: = hitch_ms == 0
	while t < 8.0:
		if hitch_ms > 0 and t > next_hitch: OS.delay_msec(hitch_ms);next_hitch += 2.0
		await tree.process_frame
		var dt: = tree.root.get_process_delta_time();t += dt;n += 1
		r.nitro = 1.0
		var car: Vector3 = v.vehicle_model.get_global_transform_interpolated().origin
		var lag: = Vector2(car.x - cam.global_position.x, car.z - cam.global_position.z).length()


		var stall: bool = hitch_ms == 0 and dt > 2.5 / float(fps_cap)
		if stall: stalls += 1


		var spd_now: float = v.speed_mps(); var steady: bool = absf(spd_now - last_spd) < 20.0 * dt;last_spd = spd_now
		if steady_frames_only and not steady: crash_frames += 1
		if t > 1.0 and not stall and (steady or not steady_frames_only):
			if last_lag >= 0.0: worst = max(worst, absf(lag - last_lag) / max(dt * 60.0, 1.0))
			maxlag = max(maxlag, lag);minlag = min(minlag, lag)

			if cam.global_position.distance_to(last_cam) < 0.2 * v.speed_mps() * minf(dt, 1.0 / 60.0) and v.speed_mps() > 5.0: still += 1;still_max = max(still_max, still)
			else: still = 0
		last_lag = lag;last_cam = cam.global_position
	var out: = {"label": label, "worst_jump": worst, "lag_min": minlag, "lag_max": maxlag, "frozen_frames": still_max, "kmh": v.speed_mps() * 3.6 * 1.6, "frames": n}
	print("[camtest] %-28s kmh=%5.1f lag %.2f..%.2f m  worst jump/frame=%.3f m  frozen frames=%d  frames=%d  stalls=%d  wall-hit frames=%d" % [label, out["kmh"], minlag, maxlag, worst, still_max, n, stalls, crash_frames])
	return out

func _cam_test() -> void :
	Game.autotest_human = false
	Game.data["settings"]["flyby"] = false;Game.data["tips_seen"] = true;Game.data["settings"]["shake"] = false
	await main.get_tree().create_timer(0.5).timeout
	var ok: = true
	var runs: = []
	for cam in [1, 0, 3]:
		for cfg in [["60fps", 0, 60], ["144fps", 0, 144], ["30fps", 0, 30]]: runs.append([2, cam, cfg])
	runs.append([2, 1, ["hitch 250ms", 250, 60]])
	for cfg in [["60fps", 0, 60], ["30fps", 0, 30], ["hitch 250ms", 250, 60]]: runs.append([0, 1, cfg])
	for run in runs:
		var q: int = run[0]; var cfg: Array = run[2]
		Game.data["settings"]["quality"] = q;Game.data["settings"]["quality_choice"] = q + 1;Game.apply_settings()
		Game.data["settings"]["camera"] = run[1]
		if true:
			var o: = await _cam_run("q%d %s %s" % [q, ChaseCam.NAMES[run[1]], cfg[0]], 9, cfg[1], cfg[2])


			if (cfg[1] == 0 and o["worst_jump"] > 0.15) or o["frozen_frames"] > 0 or o["lag_max"] > {0: 14.0, 1: 19.0, 3: 2.5}[run[1]]: ok = false
	print("[camtest] %s" % ("PASS" if ok else "FAIL"))
	main.get_tree().quit(0 if ok else 1)




func _pad_phase(label: String, nitro: bool, steer: String, runup: = 2.0, secs: = 1.0) -> Dictionary:
	var tree: SceneTree = main.get_tree()
	var r = main.race; var v = r.player["v"]
	v.place(Vector3(1000, 0.0, -150), Vector3(0, 0, 1))
	for i in 10: await tree.physics_frame
	r.nitro = 1.0
	Input.action_press("forward")
	if nitro: Input.action_press("nitro")
	for i in int(runup * 60): r.nitro = 1.0; await tree.physics_frame
	var kmh0: float = v.speed_mps() * 3.6 * 1.6
	if steer != "": Input.action_press(steer)
	var p0: Vector3 = v.get_vehicle_position(); var pp: = p0; var hl: = INF; var travel: = 0.0; var air: = 0
	var y0: float = v.vehicle_model.global_rotation.y; var yl: = y0; var yaw: = 0.0
	for i in int(secs * 60):
		r.nitro = 1.0
		await tree.physics_frame
		if not v.raycast.is_colliding(): air += 1
		var y: float = v.vehicle_model.global_rotation.y;yaw += wrapf(y - yl, - PI, PI);yl = y
		if i % 6 == 5:
			var pn: Vector3 = v.get_vehicle_position(); var dv: = pn - pp;pp = pn
			if Vector2(dv.x, dv.z).length() > 0.05:
				var h: = atan2(dv.x, dv.z)
				if hl == INF: hl = h
				else: travel += wrapf(h - hl, - PI, PI);hl = h
	for a in ["forward", "nitro", "left", "right"]: Input.action_release(a)
	var out: = {"label": label, "travel": rad_to_deg(travel), "yaw": rad_to_deg(yaw), "kmh0": kmh0, "air": air}
	print("[steertest] %-26s speed at steer=%5.1f km/h  path turned=%6.1f deg  nose turned=%6.1f deg  air=%d" % [label, kmh0, out["travel"], out["yaw"], air])
	return out

func _steer_test() -> void :
	Game.autotest_human = true
	Game.data["settings"]["flyby"] = false;Game.data["tips_seen"] = true
	await main.get_tree().create_timer(0.5).timeout
	main.start_race(0, "time_trial")
	var r = main.race
	while r.state != "racing": await main.get_tree().physics_frame
	var pad: = StaticBody3D.new(); var cs: = CollisionShape3D.new(); var bx: = BoxShape3D.new();bx.size = Vector3(600, 1, 600);cs.shape = bx
	pad.add_child(cs); var pm: = PhysicsMaterial.new();pm.friction = 0.0;pm.bounce = 0.1;pad.physics_material_override = pm
	r.add_child(pad);pad.global_position = Vector3(1000, -0.5, 0)
	var a = await _pad_phase("cruise, left", false, "left")
	var b = await _pad_phase("nitro, left", true, "left")
	var c = await _pad_phase("nitro, right", true, "right")
	var d = await _pad_phase("nitro, straight", true, "")
	var ok: bool = absf(b["travel"]) > 45.0 and absf(c["travel"]) > 45.0 and absf(b["travel"]) > absf(a["travel"]) * 0.75 and absf(d["travel"]) < 5.0 and b["kmh0"] > a["kmh0"] * 1.1
	print("[steertest] %s" % ("PASS" if ok else "FAIL"))
	main.get_tree().quit(0 if ok else 1)




func _tilt_phase(label: String, nitro: bool, deg: float, noise_deg: = 0.0, runup: = 2.0, secs: = 1.5) -> Dictionary:
	var tree: SceneTree = main.get_tree()
	var r = main.race; var v = r.player["v"]
	TouchControls.tilt_override = 0.0
	v.place(Vector3(1000, 0.0, -200), Vector3(0, 0, 1))
	for i in 10: await tree.physics_frame
	r.nitro = 1.0
	if runup > 0.0: Input.action_press("forward")
	if nitro: Input.action_press("nitro")
	for i in int(runup * 60): r.nitro = 1.0; await tree.physics_frame
	var kmh0: float = v.speed_mps() * 3.6 * 1.6
	var p0: Vector3 = v.get_vehicle_position(); var pp: = p0; var hl: = INF; var travel: = 0.0
	var yl: float = v.vehicle_model.global_rotation.y; var yaw: = 0.0
	var so: = []; var rates: = []
	for i in int(secs * 60):
		r.nitro = 1.0
		TouchControls.tilt_override = sin(deg_to_rad(deg + randf_range( - noise_deg, noise_deg)))
		await tree.physics_frame
		var y: float = v.vehicle_model.global_rotation.y; var dy: = wrapf(y - yl, - PI, PI);yaw += dy;yl = y
		if i > 20: so.append(v.steer_out);rates.append(rad_to_deg(dy) * 60.0)
		if i % 6 == 5:
			var pn: Vector3 = v.get_vehicle_position(); var dv: = pn - pp;pp = pn
			if Vector2(dv.x, dv.z).length() > 0.05:
				var h: = atan2(dv.x, dv.z)
				if hl == INF: hl = h
				else: travel += wrapf(h - hl, - PI, PI);hl = h
	for a in ["forward", "nitro"]: Input.action_release(a)
	var mean: = 0.0;for x in so: mean += x
	mean /= max(1, so.size())
	var rm: = 0.0;for x in rates: rm += x
	rm /= max(1, rates.size())
	var jit: = 0.0;for x in rates: jit += (x - rm) * (x - rm)
	jit = sqrt(jit / max(1, rates.size()))
	var out: = {"label": label, "path_dps": rad_to_deg(travel) / secs, "yaw_dps": rad_to_deg(yaw) / secs, "steer": mean, "jitter": jit, "kmh0": kmh0}
	print("[tiltdrive] %-24s %5.1f km/h  steer_out=%5.2f  path %6.1f deg/s  nose %6.1f deg/s  yaw-rate jitter %5.1f deg/s" % [label, kmh0, mean, out["path_dps"], out["yaw_dps"], jit])
	return out

func _tilt_drive_test() -> void :
	Game.autotest_human = true
	var st: Dictionary = Game.data["settings"]
	st["flyby"] = false;Game.data["tips_seen"] = true
	st["touch"] = 1;st["touch_layout"] = 2;st["steer_mode"] = 1;st["auto_accel"] = false;st["tilt_zero"] = 0.0;st["tilt_sens"] = 1.0;st["steer"] = 1.0
	await main.get_tree().create_timer(0.5).timeout
	main.start_race(0, "time_trial")
	var r = main.race
	while r.state != "racing": await main.get_tree().physics_frame
	if r.touch: r.touch.reload_settings()
	var pad: = StaticBody3D.new(); var cs: = CollisionShape3D.new(); var bx: = BoxShape3D.new();bx.size = Vector3(800, 1, 800);cs.shape = bx
	pad.add_child(cs); var pm: = PhysicsMaterial.new();pm.friction = 0.0;pm.bounce = 0.1;pad.physics_material_override = pm
	r.add_child(pad);pad.global_position = Vector3(1000, -0.5, 0)
	var res: = {}
	res["rest"] = await _tilt_phase("at rest, 0+-2 deg noise", false, 0.0, 2.0, 0.0)
	for sp in [["cruise", false], ["nitro", true]]:
		res[sp[0] + "0"] = await _tilt_phase("%s, 0+-2 deg noise" % sp[0], sp[1], 0.0, 2.0)
		for deg in [3.0, 8.0, 14.0, 20.0, 28.0]:
			res["%s%d" % [sp[0], int(deg)]] = await _tilt_phase("%s, %d deg" % [sp[0], int(deg)], sp[1], deg, 0.5)
	TouchControls.tilt_override = -9.0
	var ok: = true
	for k in ["rest", "cruise0", "nitro0", "cruise3", "nitro3"]:
		if absf(res[k]["steer"]) > 0.02 or absf(res[k]["path_dps"]) > 3.0: ok = false;print("[tiltdrive] centre not still: ", k)
	for sp in ["cruise", "nitro"]:
		var last: = 0.0
		for deg in [8, 14, 20, 28]:
			var pdps: float = absf(res["%s%d" % [sp, deg]]["path_dps"])
			if pdps + 2.0 < last: ok = false;print("[tiltdrive] not monotonic: ", sp, deg)
			last = pdps
		if absf(res[sp + "14"]["path_dps"]) > absf(res[sp + "28"]["path_dps"]) * 0.7: ok = false;print("[tiltdrive] half tilt too strong: ", sp)
		if absf(res[sp + "8"]["path_dps"]) > 30.0: ok = false;print("[tiltdrive] slight tilt over-turns: ", sp)
		if res[sp + "20"]["jitter"] > 25.0: ok = false;print("[tiltdrive] twitchy: ", sp)
	if absf(res["nitro28"]["path_dps"]) < 40.0: ok = false;print("[tiltdrive] full tilt at nitro speed doesn't turn enough")
	print("[tiltdrive] %s" % ("PASS" if ok else "FAIL"))
	main.get_tree().quit(0 if ok else 1)



func _android_test() -> void :
	var tree: SceneTree = main.get_tree(); var fails: = 0
	var ok: = func(cond: bool, what: String) -> int:
		print("[android] %s %s" % ["OK  " if cond else "FAIL", what]);return 0 if cond else 1
	await tree.create_timer(1.0).timeout
	fails += ok.call( not ProjectSettings.get_setting("application/config/quit_on_go_back"), "quit_on_go_back is off")
	main.show_settings(); await tree.process_frame
	main.go_back(); await tree.process_frame
	fails += ok.call(main.screen.name == "Title", "back: settings -> title")
	main.show_garage(); await tree.process_frame
	main.go_back(); await tree.process_frame
	fails += ok.call(main.screen.name == "Title", "back: garage -> title")
	main.show_tracks("race"); await tree.process_frame
	main.go_back(); await tree.process_frame
	fails += ok.call(main.screen.name == "Title", "back: tracks -> title")
	main._confirm("test?", func(): pass); await tree.process_frame
	main.go_back(); await tree.process_frame; await tree.process_frame
	fails += ok.call(main.get_node_or_null("Confirm") == null, "back: closes a yes/no dialog (No)")
	Game.data["tips_seen"] = true;Game.data["settings"]["flyby"] = false
	main.start_race(0, "race")
	var t0: = Time.get_ticks_msec()
	while (main.race == null or main.race.state != "racing") and Time.get_ticks_msec() - t0 < 30000: await tree.process_frame
	fails += ok.call(main.race != null and main.race.state == "racing", "race reaches racing")
	main.go_back(); await tree.process_frame
	fails += ok.call(tree.paused and main.race.pause_layer.visible, "back in a race: pause menu")
	main.go_back(); await tree.process_frame
	fails += ok.call( not tree.paused, "back again: resume")
	Game.autotest = false;main.race._notification(Node.NOTIFICATION_APPLICATION_PAUSED);Game.autotest = true
	await tree.process_frame
	fails += ok.call(tree.paused, "app to background: race paused")
	main.race._toggle_pause()
	main.race.quit_requested.emit(); await tree.process_frame


	var s: Dictionary = Game.data["settings"];s["tilt_zero"] = 0.0;s["tilt_sens"] = 1.0;s["tilt_invert"] = false
	Input.set_accelerometer(Vector3(4.905, -7.0, -4.8))
	fails += ok.call(absf(TouchControls.tilt_raw() - 0.5) < 0.01, "tilt right -> +0.5 (%.2f)" % TouchControls.tilt_raw())
	fails += ok.call(TouchControls.tilt_target() > 0.9, "tilt right 30 deg -> full right (%.2f)" % TouchControls.tilt_target())
	Input.set_accelerometer(Vector3(-4.905, -7.0, -4.8))
	fails += ok.call(TouchControls.tilt_target() < -0.9, "tilt left 30 deg -> full left (%.2f)" % TouchControls.tilt_target())
	Input.set_accelerometer(Vector3(0.5, -7.0, -6.9))
	fails += ok.call(TouchControls.tilt_target() == 0.0, "held level (3 deg) -> straight")
	s["tilt_invert"] = true
	Input.set_accelerometer(Vector3(4.905, -7.0, -4.8))
	fails += ok.call(TouchControls.tilt_target() < -0.9, "INVERT TILT on: tilt right -> left (%.2f)" % TouchControls.tilt_target())
	s["tilt_invert"] = false

	TouchControls.test_android = true
	Input.set_accelerometer(Vector3(-4.905, 7.0, -4.8))
	fails += ok.call(TouchControls.tilt_raw() < 0.0, "mirrored axes: not trusted before 0.5 s")
	await tree.create_timer(0.7).timeout
	fails += ok.call(absf(TouchControls.tilt_raw() - 0.5) < 0.01, "mirrored axes for 0.5 s -> corrected, right (%.2f)" % TouchControls.tilt_raw())
	Input.set_accelerometer(Vector3(4.905, -7.0, -4.8));TouchControls.tilt_raw()
	await tree.create_timer(0.7).timeout
	fails += ok.call(absf(TouchControls.tilt_raw() - 0.5) < 0.01, "axes right again -> back to normal (%.2f)" % TouchControls.tilt_raw())
	Input.set_accelerometer(Vector3(-4.905, 7.0, 4.8));TouchControls.tilt_raw()
	await tree.create_timer(0.7).timeout
	fails += ok.call(TouchControls.tilt_raw() < 0.0, "screen facing down: no un-mirroring")
	TouchControls.test_android = false
	Input.set_accelerometer(Vector3.ZERO)
	fails += ok.call(TouchControls.tilt_raw() == 0.0 and TouchControls.tilt_events() == 0, "no accelerometer -> 0, no events")
	for c in [["Adreno (TM) 610", 1], ["Adreno (TM) 506", 1], ["Adreno (TM) 505", 0], ["Adreno (TM) 650", 2], ["Adreno (TM) 740", 2], 
			["Mali-G52 MC2", 1], ["Mali-G57 MC2", 1], ["Mali-G76 MC4", 2], ["Mali-G610 MC6", 1], ["Mali-G615 MC2", 1], ["Mali-G615", 1], 
			["Mali-G68 MC4", 1], ["Mali-G78 MP14", 2], ["Mali-G710 MC10", 2], ["Mali-G720 MC7", 2], ["Mali-G31 MP2", 0], ["Mali-T830", 0], 
			["Mali-400 MP", 0], ["PowerVR Rogue GE8320", 0], ["PowerVR B-Series BXM-8-256", 1], ["Xclipse 920", 2], ["llvmpipe", 1]]:
		var got: int = Game.native_start_level(c[0])
		fails += ok.call(got == c[1], "gpu %s -> %d" % [c[0], got])


	var tc: = TouchControls.new();main.add_child(tc); await tree.process_frame
	var bad: = 0; var combos: = 0
	for vs in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1559, 720), Vector2(1280, 800), Vector2(1280, 960)]:
		for lay in 3:
			for np in 3:
				for sk in [0.7, 1.0, 1.4]:
					for lefty in [false, true]:
						tc.layout = lay;tc.auto_accel = lay == 1;tc.tilt = lay == 2;tc.nitro_pos = np;tc.size_k = sk;tc.lefty = lefty
						var sh: Dictionary = tc.shapes(vs); var names: Array = sh.keys();combos += 1
						for i in names.size():
							var a: Dictionary = sh[names[i]]; var ah: Vector2 = a["hs"]
							if a["c"].x - ah.x < 0.0 or a["c"].x + ah.x > vs.x or a["c"].y - ah.y < 0.0 or a["c"].y + ah.y > vs.y:
								bad += 1;print("[android]   off screen: %s %s lay %d np %d size %.1f lefty %s" % [names[i], vs, lay, np, sk, lefty])
							for j in range(i + 1, names.size()):
								var b: Dictionary = sh[names[j]]; var bh: Vector2 = b["hs"]
								if names[i] in ["left", "right"] and names[j] in ["left", "right"]: continue
								var d: Vector2 = (a["c"] - b["c"]).abs()
								var overl: bool
								if a["round"] and b["round"]: overl = d.length() < (ah.x + bh.x) * 1.18
								elif not a["round"] and not b["round"]: overl = d.x < (ah.x + bh.x) * 1.18 and d.y < (ah.y + bh.y) * 1.18
								else:
									var boxh: Vector2 = (bh if a["round"] else ah) * 1.18; var r: float = (ah.x if a["round"] else bh.x) * 1.18
									overl = (d - boxh).max(Vector2.ZERO).length() < r
								if overl:
									bad += 1;print("[android]   overlap: %s / %s %s lay %d np %d size %.1f lefty %s" % [names[i], names[j], vs, lay, np, sk, lefty])
	tc.queue_free()
	fails += ok.call(bad == 0, "touch layouts: %d combinations on screen, no overlapping touch areas (%d problems)" % [combos, bad])

	fails += ok.call(Game.native_screen_cap(Vector2i(1920, 1200)) == 1 and Game.native_screen_cap(Vector2i(1200, 1920)) == 1, "tablet 1920x1200 -> start Medium at most")
	fails += ok.call(Game.native_screen_cap(Vector2i(2400, 1080)) == 2 and Game.native_screen_cap(Vector2i(2772, 1280)) == 2 and Game.native_screen_cap(Vector2i(2732, 2048)) == 1, "phones 2400x1080 / 2772x1280 -> no cap, 4:3 tablet -> Medium")
	for lv in 3:
		for sc in [0.5, 0.75, 0.83, 0.999, 1.0]:
			var m: int = Game.native_msaa(lv, sc)
			fails += ok.call((m == Viewport.MSAA_DISABLED) if (sc < 0.999 or lv == 0) else (m == [0, Viewport.MSAA_2X, Viewport.MSAA_4X][lv]), "native MSAA level %d scale %.3f -> %d" % [lv, sc, m])
	print("[android] DONE fails=%d" % fails)
	tree.quit()





func _play_shots() -> void :
	var tree: SceneTree = main.get_tree()
	Ads.provider = "none"
	Game.data["coins"] = 2600;Game.data["xp"] = 2600
	for c in Game.CARS: if not Game.car_owned(c["id"]): Game.data["owned"].append(c["id"])
	for i in Game.TRACKS.size(): Game.data["stars"][Game.TRACKS[i]["id"]] = max(2, int(Game.data["stars"].get(Game.TRACKS[i]["id"], 0)))
	var s: Dictionary = Game.data["settings"]
	s["touch"] = 1;s["quality_choice"] = 3;s["auto_quality"] = false;s["touch_layout"] = 0;s["nitro_pos"] = 0
	s["touch_size"] = 1.0;s["touch_opacity"] = 0.7;s["flyby"] = false;Game.data["tips_seen"] = true
	Game.apply_settings()
	var only: = OS.get_environment("TTR_ONLY")
	var shots: = [
		["1_pine_far", 0, "clear", "yellow", 0, 1, 7.0, ["gas"]], 
		["2_lakeside_sunset_near", 3, "sunset", "red", 1, 0, 9.0, ["gas", "nitro"]], 
		["3_canyon_rain_far", 4, "rain", "purple", 4, 1, 8.0, ["gas", "left"]], 
		["4_grand_night_far", 9, "night", "green", 3, 1, 8.0, ["gas"]], 
		["5_hairpin_fog_bike", 6, "fog", "bike", 2, 1, 10.0, ["gas", "right"]], 
		["6_twin_hood", 8, "clear", "yellow", 5, 3, 9.0, ["gas"]], 
		["n1_pine_near", 0, "clear", "yellow", 0, 0, 5.0, ["gas"]], 
		["n3_canyon_rain_near", 4, "rain", "purple", 4, 0, 12.0, ["gas", "left"]], 
		["n4_grand_night_near", 9, "night", "green", 3, 0, 6.0, ["gas", "nitro"]], 
		["n5_hairpin_fog_bike_near", 6, "fog", "bike", 2, 0, 7.0, ["gas", "right"]], 
		["n6_esses_hood", 5, "clear", "red", 1, 3, 6.0, ["gas"]], 
		["n7_chicane_sunset_far", 7, "sunset", "green", 5, 1, 6.0, ["gas", "nitro"]], 
	]
	for e in shots:
		if only != "" and not String(e[0]).begins_with(only): continue
		Game.data["car"] = e[3];Game.data["paint"][e[3]] = int(e[4]);s["camera"] = int(e[5])
		OS.set_environment("TTR_WEATHER", e[2])
		seed(11)
		main.start_race(int(e[1]), "race")
		var r = main.race
		var t0: = Time.get_ticks_msec()
		while (r.state != "racing") and Time.get_ticks_msec() - t0 < 120000: await tree.process_frame
		await tree.create_timer(float(e[6])).timeout
		var sh: Dictionary = r.touch.shapes()
		var idx: = 0
		for f in e[7]:
			var key: String = String(f)
			if not sh.has(key): print("[playshots] no touch shape ", key, " in ", sh.keys());continue
			await _touch(idx, sh[key]["c"], true);idx += 1
		await tree.create_timer(0.35).timeout
		await _shot(e[0])
		for i in idx: await _touch(i, Vector2.ZERO, false)
		r.quit_requested.emit(); await tree.create_timer(0.5).timeout
	OS.set_environment("TTR_WEATHER", "")
	if only == "" or only == "7":
		Game.data["car"] = "red";Game.data["paint"]["red"] = 1
		main.show_garage(); await tree.create_timer(1.5).timeout; await _shot("7_garage")
	print("[playshots] DONE")
	tree.quit()





func _gfx_frac(img: Image, bg: Color) -> float:

	var w: = img.get_width(); var h: = img.get_height(); var n: = 0; var hit: = 0
	for y in range(int(h * 0.3), int(h * 0.8), 6):
		for x in range(0, w, 6):
			var c: = img.get_pixel(x, y);n += 1
			if absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b) > 0.12: hit += 1
	return float(hit) / maxf(1.0, n)

func _gfx_luma(img: Image) -> float:
	var w: = img.get_width(); var h: = img.get_height(); var n: = 0; var sum: = 0.0
	for y in range(int(h * 0.3), int(h * 0.8), 8):
		for x in range(0, w, 8):
			sum += img.get_pixel(x, y).get_luminance();n += 1
	return sum / maxf(1.0, n)

func _gfx_check(tag: String, ok: Callable) -> int:
	var vp: Viewport = main.get_viewport()
	var f: = 0
	if Game.native_mobile() and vp.scaling_3d_scale < 0.999:
		f += ok.call(vp.msaa_3d == Viewport.MSAA_DISABLED, "%s: no MSAA with scale %.2f (msaa %d)" % [tag, vp.scaling_3d_scale, vp.msaa_3d])
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var env: Environment = main.race.my_env if main.race.my_env else Game.make_env(main.race.weather)
	var fr: = _gfx_frac(img, env.background_color)
	f += ok.call(fr > 0.3, "%s: 3D drawn (%.0f%% of the middle not sky/fog), luma %.2f, level %d scale %.2f msaa %d" % [tag, fr * 100.0, _gfx_luma(img), Game.quality_level(), vp.scaling_3d_scale, vp.msaa_3d])
	img.save_png(dir.path_join("gfx_%s.png" % tag))
	return f

func _gfx_wait_racing(tree: SceneTree) -> bool:
	var t0: = Time.get_ticks_msec()
	while (main.race == null or main.race.state != "racing") and Time.get_ticks_msec() - t0 < 60000: await tree.process_frame
	return main.race != null and main.race.state == "racing"

func _gfx_test() -> void :
	var tree: SceneTree = main.get_tree(); var fails: = 0
	var ok: = func(cond: bool, what: String) -> int:
		print("[gfx] %s %s" % ["OK  " if cond else "FAIL", what]);return 0 if cond else 1
	Game.data["tips_seen"] = true; var s: Dictionary = Game.data["settings"];s["flyby"] = false;s["touch"] = 1
	var size: Vector2 = main.get_viewport().get_visible_rect().size
	print("[gfx] window %s viewport %s native %s" % [DisplayServer.window_get_size(), size, Game.native_mobile()])
	var track: = int(OS.get_environment("TTR_TRACK")) if OS.get_environment("TTR_TRACK") != "" else 0
	var weathers: = OS.get_environment("TTR_WEATHERS").split(",") if OS.get_environment("TTR_WEATHERS") != "" else PackedStringArray(["clear", "fog", "night", "rain", "sunset"])
	for w in weathers:
		for qc in [1, 2, 3]:
			OS.set_environment("TTR_WEATHER", w)
			Game.set_quality_choice(qc)
			main.start_race(track, "daily")
			fails += ok.call( await _gfx_wait_racing(tree), "%s q%d: race reaches racing" % [w, qc])
			await tree.create_timer(1.5).timeout
			fails += await _gfx_check("%s_q%d" % [w, qc], ok)
			main.race.quit_requested.emit(); await tree.process_frame

	OS.set_environment("TTR_WEATHER", "clear")
	Game.set_quality_choice(3)
	main.start_race(track, "race")
	fails += ok.call( await _gfx_wait_racing(tree), "switch: race reaches racing")
	for qc in [2, 1, 3, 0, 2, 3, 1]:
		Game.set_quality_choice(qc);main.race.quality = Game.quality_level()
		await tree.create_timer(0.4).timeout
		fails += await _gfx_check("switch_to_q%d" % qc, ok)

	Game.set_quality_choice(0);s["auto_level"] = 2;s["auto_scale"] = 1.0;Game.apply_settings();main.race.quality = Game.quality_level()
	OS.set_environment("TTR_AUTOPERF", "1")
	var lv0: = Game.quality_level()
	for i in 5: main.race._auto_perf(2.0)
	fails += ok.call(Game.quality_level() == lv0, "auto: long frames (2 s each) don't lower the graphics")
	for step in 4:
		for i in 51: main.race._auto_perf(0.1)
		await tree.create_timer(0.3).timeout
		fails += await _gfx_check("auto_step%d" % step, ok)
	OS.set_environment("TTR_AUTOPERF", "")
	main.race.quit_requested.emit(); await tree.process_frame
	Game.set_quality_choice(0)
	print("[gfx] DONE fails=%d" % fails)
	tree.quit()


func _soak_test() -> void :
	var tree: SceneTree = main.get_tree(); var fails: = 0
	Game.data["tips_seen"] = true;Game.data["settings"]["flyby"] = false
	var n: = int(OS.get_environment("TTR_SOAK")) if OS.get_environment("TTR_SOAK") != "" else 12
	var counts: Array = []
	for i in n:
		var t: = i % Game.TRACKS.size()
		OS.set_environment("TTR_WEATHER", ["clear", "night", "rain", "fog", "sunset"][i % 5])
		main.start_race(t, ["race", "daily", "time_trial", "elimination", "checkpoint"][i % 5])
		var t0: = Time.get_ticks_msec()
		while (main.race == null or main.race.state != "racing") and Time.get_ticks_msec() - t0 < 60000: await tree.process_frame
		await tree.create_timer(2.0).timeout
		main.race.quit_requested.emit()
		for k in 10: await tree.process_frame
		var c: = [Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), 
			Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)]
		counts.append(c)
		print("[soak] race %d track %d: objects %d nodes %d resources %d static %.1f MB video %.1f MB orphans %d" % ([i + 1, t] + c))
	OS.set_environment("TTR_WEATHER", "")

	var a: Array = counts[min(4, n - 1)]; var b: Array = counts[n - 1]
	var grow_nodes: float = b[1] - a[1]; var grow_mem: float = b[3] - a[3]
	var good: = grow_nodes <= 50 and grow_mem < 40.0
	if not good: fails += 1
	print("[soak] %s nodes %+d, static memory %+.1f MB from race 5 to race %d" % ["OK  " if good else "FAIL", grow_nodes, grow_mem, n])
	print("[soak] DONE fails=%d" % fails)
	tree.quit()





func _prop_check() -> void :
	var tree: SceneTree = main.get_tree(); var fails: = 0
	Game.data["tips_seen"] = true;Game.data["settings"]["flyby"] = false
	OS.set_environment("TTR_WEATHER", "night")
	var total: = 0; var old_bad_total: = 0
	for t in Game.TRACKS.size():
		for md in ["checkpoint", "daily"]:
			main.start_race(t, md)
			for k in 3: await tree.process_frame
			var r = main.race
			var cells: Array = r.info["cells"]; var n: = cells.size()
			var line: = TrackBuilder.centreline(cells)
			var gm: GridMap = null
			for c in r.get_children(): if c is GridMap: gm = c

			for i in n:
				var dd: = TrackBuilder.road_dist(line, r.points[i])
				if dd > 0.05: fails += 1;print("[props] FAIL %s waypoint %d is %.2f m off the centre line" % [Game.TRACKS[t]["id"], i, dd])
			var road: = {}
			for c in cells: road[c] = true
			var bad: = 0; var lamps: = 0
			var check: = func(pos: Vector3, what: String, radius: float) -> bool:
				var ok: = TrackBuilder.off_road(line, pos, radius)
				for o in [Vector3.ZERO, Vector3(radius, 0, 0), Vector3( - radius, 0, 0), Vector3(0, 0, radius), Vector3(0, 0, - radius)]:
					var mc: = gm.local_to_map(gm.to_local(pos + o)); var cc: = Vector2i(mc.x, mc.z)
					if not road.has(cc): continue
					var item: = gm.get_cell_item(Vector3i(cc.x, 0, cc.y))
					if item != TrackBuilder.ITEM_CORNER: ok = false;continue
					var ci: = cells.find(cc); var a: Vector2i = cells[(ci - 1 + n) % n] - cc; var b: Vector2i = cells[(ci + 1) % n] - cc
					var inner: = TrackBuilder.cell_center(cc) + Vector3(a.x + b.x, 0, a.y + b.y) * 0.5 * Game.CELL
					if Vector2(pos.x + o.x - inner.x, pos.z + o.z - inner.z).length() < Game.CELL + 0.2: ok = false
				if not ok: print("[props] FAIL %s %s %s at %s is on the road (%.2f m from the lane centre)" % [Game.TRACKS[t]["id"], md, what, pos, TrackBuilder.road_dist(line, pos)])
				return ok
			if md == "checkpoint":
				for nd in r.get_children():
					if nd is MeshInstance3D and nd.get_meta("prop", "") == "lamp":
						lamps += 1; if not check.call(Vector3(nd.position.x, 0, nd.position.z), "lamp", 0.3): bad += 1
				for g in TrackBuilder.finish_posts(cells):
					if not check.call(g, "finish gantry leg", 0.3): bad += 1
				for nd in r.get_children():
					if nd.get_meta("prop", "") != "gate": continue
					for post in nd.get_children():
						if not (post.mesh is BoxMesh and (post.mesh as BoxMesh).size.y > 3.0): continue
						var dd: = TrackBuilder.road_dist(line, post.position)
						if dd < 5.0 or dd > 6.3: bad += 1;print("[props] FAIL %s gate post %.2f m from the lane centre (must be at the edge, 5.0-6.3)" % [Game.TRACKS[t]["id"], dd])

				var old_bad: = 0
				for i in range(1, n, 3):
					var d: Vector3 = r.info["dirs"][i]; var s: = 1.0 if (i / 3) % 2 == 0 else -1.0
					if not TrackBuilder.off_road(line, r.points[i] + d.cross(Vector3.UP) * s * 6.6, 0.3): old_bad += 1
				old_bad_total += old_bad;total += lamps
				print("[props] %s %s %s: %d lamps, %d on the road (1.0.2 placement: %d of %d on the road)" % ["OK  " if bad == 0 else "FAIL", Game.TRACKS[t]["id"], md, lamps, bad, old_bad, range(1, n, 3).size()])
			else:
				for nd in r.get_children():
					if nd is MeshInstance3D and nd.get_meta("prop", "") == "lamp":
						lamps += 1; if not check.call(Vector3(nd.position.x, 0, nd.position.z), "lamp", 0.3): bad += 1
				print("[props] %s %s daily: %d lamps, %d on the road" % ["OK  " if bad == 0 else "FAIL", Game.TRACKS[t]["id"], lamps, bad])
			fails += bad
			if OS.get_environment("TTR_PROPSHOT") != "" and md == "checkpoint":
				var cam: = Camera3D.new();cam.projection = Camera3D.PROJECTION_ORTHOGONAL; var lo: Vector3 = r.info["lo"]; var hi: Vector3 = r.info["hi"]
				cam.size = maxf(hi.x - lo.x, hi.z - lo.z) + 10.0;cam.position = (lo + hi) / 2.0 + Vector3(0, 60, 0);cam.rotation_degrees.x = -90;cam.far = 200
				r.add_child(cam);cam.current = true
				for k in 4: await tree.process_frame
				await RenderingServer.frame_post_draw
				main.get_viewport().get_texture().get_image().save_png("%s/props_%d.png" % [OS.get_environment("TTR_PROPSHOT"), t])

				for gi in r.cps:
					if TrackBuilder._is_straight(cells, gi): continue
					cam.size = 30.0;cam.position = r.points[gi] + Vector3(0, 60, 0)
					for k in 3: await tree.process_frame
					await RenderingServer.frame_post_draw
					main.get_viewport().get_texture().get_image().save_png("%s/gate_%d_%d.png" % [OS.get_environment("TTR_PROPSHOT"), t, gi])
			r.quit_requested.emit()
			for k in 3: await tree.process_frame
	OS.set_environment("TTR_WEATHER", "")
	print("[props] %d lamps checked on all tracks; 1.0.2 had %d on the road" % [total, old_bad_total])
	print("[props] DONE fails=%d" % fails)
	tree.quit()




func _pause_test() -> void :
	var tree: SceneTree = main.get_tree(); var fails: = 0
	var ok: = func(cond: bool, what: String) -> int:
		print("[pause] %s %s" % ["OK  " if cond else "FAIL", what]);return 0 if cond else 1
	var s: Dictionary = Game.data["settings"]
	Game.data["tips_seen"] = true;s["flyby"] = false;s["touch"] = 1;s["touch_layout"] = 0;s["auto_accel"] = false;s["steer_mode"] = 0
	if OS.get_environment("TTR_LANG") != "": s["lang"] = OS.get_environment("TTR_LANG");Loc.apply()
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	print("[pause] screen %s lang %s" % [vs, Loc.lang])
	main.start_race(0, "race")
	var t0: = Time.get_ticks_msec()
	while (main.race == null or main.race.state != "racing") and Time.get_ticks_msec() - t0 < 30000: await tree.process_frame
	var r = main.race
	fails += ok.call(r.state == "racing", "race reaches racing")
	main.go_back(); await tree.process_frame; await tree.process_frame
	fails += ok.call(tree.paused and r.pause_layer.visible, "back: pause menu opens")
	var resume_btn: Button = null
	for b in r.pause_layer.find_children("*", "Button", true, false):
		if b.text == "RESUME": resume_btn = b
	var col: Control = resume_btn.get_parent() if resume_btn else null
	for tab in r.PAUSE_TABS.size():
		r._show_pause_tab(tab); await tree.process_frame; await tree.process_frame
		var pr: Rect2 = r.pause_controls.get_global_rect()
		fails += ok.call(Rect2(Vector2.ZERO, vs).encloses(pr), "tab %d (%s): panel on screen %s" % [tab, r.PAUSE_TABS[tab], pr])
		if col: fails += ok.call( not col.get_global_rect().intersects(pr), "tab %d: no overlap with RESUME / RESTART / QUIT" % tab)
		var n_vis: = 0
		for c in r.pause_controls.find_children("*", "Control", true, false):
			if (c is BaseButton or c is Slider) and c.is_visible_in_tree():
				n_vis += 1
				if not Rect2(Vector2.ZERO, vs).encloses(c.get_global_rect()): fails += ok.call(false, "tab %d: '%s' off screen" % [tab, c.name])
				if c is BaseButton and c.get_global_rect().size.y < 40: fails += ok.call(false, "tab %d: '%s' too small to tap (%.0f px)" % [tab, c.name, c.get_global_rect().size.y])
		fails += ok.call(n_vis >= 4, "tab %d: %d controls shown" % [tab, n_vis])
		if OS.get_environment("TTR_SHOTS") != "":
			await RenderingServer.frame_post_draw
			main.get_viewport().get_texture().get_image().save_png("%s/pause_%dx%d_tab%d.png" % [OS.get_environment("TTR_SHOTS"), vs.x, vs.y, tab])

	var pc: Control = r.pause_controls
	r._show_pause_tab(1); await tree.process_frame
	(pc.find_child("Nitro2", true, false) as Button).pressed.emit(); await tree.process_frame
	fails += ok.call(int(s["nitro_pos"]) == 2 and r.touch.nitro_pos == 2, "NITRO BUTTON: LEFT SIDE applied live + saved")
	var sh: Dictionary = r.touch.shapes()
	fails += ok.call(sh.has("nitro") and sh["nitro"]["c"].x < vs.x * 0.5, "LEFT SIDE nitro now on the left half")
	(pc.find_child("Nitro0", true, false) as Button).pressed.emit(); await tree.process_frame
	fails += ok.call(r.touch.nitro_pos == 0, "NITRO BUTTON back to BESIDE PEDAL")
	(pc.find_child("Lefty", true, false) as CheckButton).button_pressed = true
	fails += ok.call(bool(s["touch_lefty"]) and r.touch.lefty, "LEFT-HANDED applied live")
	(pc.find_child("Lefty", true, false) as CheckButton).button_pressed = false
	(pc.find_child("Vibration", true, false) as CheckButton).button_pressed = false
	fails += ok.call( not bool(s["haptics"]) and not r.touch.haptics, "VIBRATION off applied live")
	(pc.find_child("Vibration", true, false) as CheckButton).button_pressed = true
	(pc.find_child("touch_opacity", true, false) as HSlider).value = 0.5
	fails += ok.call(absf(r.touch.opacity - 0.5) < 0.01, "BUTTON OPACITY live")
	(pc.find_child("touch_opacity", true, false) as HSlider).value = 0.7
	r._show_pause_tab(0); await tree.process_frame
	(pc.find_child("steer", true, false) as HSlider).value = 1.2
	fails += ok.call(absf(float(s["steer"]) - 1.2) < 0.01, "STEERING SENSITIVITY saved")
	(pc.find_child("steer", true, false) as HSlider).value = 1.0
	(pc.find_child("InvertTilt", true, false) as CheckButton).button_pressed = true
	fails += ok.call(bool(s["tilt_invert"]), "INVERT TILT saved")
	(pc.find_child("InvertTilt", true, false) as CheckButton).button_pressed = false
	r._set_preset(1); await tree.process_frame
	fails += ok.call(r.touch.auto_accel and not r.touch.shapes().has("gas"), "control mode AUTO GAS live")
	r._set_preset(0); await tree.process_frame
	r._show_pause_tab(2); await tree.process_frame
	(pc.find_child("music", true, false) as HSlider).value = 0.3
	var mdb: = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	fails += ok.call(absf(mdb - linear_to_db(0.3)) < 0.1, "MUSIC volume live (%.1f dB)" % mdb)
	(pc.find_child("music", true, false) as HSlider).value = 0.7
	(pc.find_child("sfx", true, false) as HSlider).value = 0.4
	fails += ok.call(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) - linear_to_db(0.4)) < 0.1, "SFX volume live")
	(pc.find_child("sfx", true, false) as HSlider).value = 0.8
	(pc.find_child("Mute", true, false) as CheckButton).button_pressed = true
	fails += ok.call(AudioServer.is_bus_mute(0), "MUTE ALL live")
	(pc.find_child("Mute", true, false) as CheckButton).button_pressed = false
	fails += ok.call( not AudioServer.is_bus_mute(0), "unmute live")
	var cam0: = int(s.get("camera", 1))
	(pc.find_child("Camera", true, false) as Button).pressed.emit(); await tree.process_frame
	fails += ok.call(int(s["camera"]) != cam0 and r.view.mode == int(s["camera"]), "CAMERA changes the race camera")
	fails += ok.call((pc.find_child("Camera", true, false) as Button).text.contains(ChaseCam.display_name(int(s["camera"]))), "CAMERA button shows the new camera")
	(pc.find_child("Shake", true, false) as CheckButton).button_pressed = false
	fails += ok.call( not bool(s["shake"]), "SCREEN SHAKE off saved")
	(pc.find_child("Shake", true, false) as CheckButton).button_pressed = true

	if Game.perf_mode:
		var g1: Button = r.pause_layer.find_child("Gfx1", true, false)
		if g1: g1.pressed.emit(); await tree.process_frame
		fails += ok.call(Game.quality_choice() == 1, "GRAPHICS LOW from the pause menu")
		var g0: Button = r.pause_layer.find_child("Gfx0", true, false)
		if g0: g0.pressed.emit()

	main.go_back(); await tree.process_frame
	fails += ok.call( not tree.paused and not r.pause_layer.visible, "back again: race resumes")
	r._cycle_camera()
	await tree.create_timer(1.0).timeout
	fails += ok.call(r.state == "racing", "race still running after resume")
	main.go_back(); await tree.process_frame
	fails += ok.call((pc.find_child("Camera", true, false) as Button).text.contains(ChaseCam.display_name(int(s["camera"]))), "pause menu re-reads a camera changed with CAM")
	fails += ok.call(r._pause_tab == 2, "pause menu reopens on the last tab")
	(r.pause_layer.find_children("*", "Button", true, false).filter( func(b): return b.text == "RESUME")[0] as Button).pressed.emit()
	await tree.process_frame
	fails += ok.call( not tree.paused, "RESUME button resumes")

	r.touch.active = false
	r._toggle_pause(); await tree.process_frame
	fails += ok.call(r._pause_tab == 2 and not r._pause_tab_btns[0].is_visible_in_tree() and (pc.find_child("music", true, false) as Control).is_visible_in_tree(), "no touch: only SOUND & CAMERA, no tabs")
	r._toggle_pause();r.touch.active = true

	s["nitro_pos"] = 2;s["camera"] = cam0
	r.quit_requested.emit(); await tree.process_frame
	main.show_settings(); await tree.process_frame
	var nb_ok: = false
	for ob in main.screen.find_children("*", "OptionButton", true, false):
		if (ob as OptionButton).get_item_text((ob as OptionButton).selected) == tr("LEFT SIDE"): nb_ok = true
	fails += ok.call(nb_ok, "Settings screen shows NITRO BUTTON LEFT SIDE set in the race")
	s["nitro_pos"] = 0
	if OS.get_environment("TTR_LANG") != "": s["lang"] = "auto";Loc.apply()
	Game.save_game()
	print("[pause] DONE fails=%d" % fails)
	tree.quit()
