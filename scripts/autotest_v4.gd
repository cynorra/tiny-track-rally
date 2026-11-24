class_name AutoTest4 extends RefCounted





var main
var dir: = ""
var fails: = 0
var tree: SceneTree

func ok(c: bool, what: String) -> void :
	print("[v4] %s %s" % ["OK  " if c else "FAIL", what])
	if not c: fails += 1

func run(m, mode: String, shot_dir: String) -> void :
	main = m;dir = shot_dir;tree = main.get_tree()
	Game.data["tips_seen"] = true
	if OS.get_environment("TTR_QUALITY") != "": Game.data["settings"]["quality"] = int(OS.get_environment("TTR_QUALITY"));Game.apply_settings()
	await tree.create_timer(0.5).timeout
	match mode:
		"matrix": await matrix(OS.get_environment("TTR_MATRIX"))
		"unit": await unit()
		"shots": await shots()
		"missionshots": await missionshots()
		"padtest": await padtest()
		"v7shots": await v7shots()
		"uishots":
			var tag: = OS.get_environment("TTR_TAG")
			for sc in [["title", main.show_title], ["garage", main.show_garage], ["tracks", func(): main.show_tracks("race")], ["modes", main.show_modes], ["settings", main.show_settings], ["awards", main.show_achievements]]:
				sc[1].call(); await wait(0.7); await shot("ui_%s%s" % [sc[0], tag])
		"toastshot":
			Game.data["coins"] = 0;main.show_garage(); await tree.create_timer(0.6).timeout
			main._buy_paint(3); await tree.create_timer(0.3).timeout; await shot("garage_toast")
	print("[v4] DONE fails=%d" % fails)
	tree.quit(0 if fails == 0 else 1)

func shot(name: String) -> void :
	await RenderingServer.frame_post_draw
	var img: Image = main.get_viewport().get_texture().get_image()
	if img: img.save_png(dir.path_join(name + ".png"));print("[v4] shot ", name)

func wait(s: float) -> void : await tree.create_timer(s).timeout


var _res: = {}
func race(track: int, mode: String, weather: = "", diff: = 1, timeout: = 900.0) -> Dictionary:
	OS.set_environment("TTR_WEATHER", weather)
	Game.data["settings"]["difficulty"] = diff
	_res = {}
	main.start_race(track, mode)
	main.race.race_finished.connect( func(r): _res = r)
	var r = main.race
	var fmin: = 9999.0
	var trace: Array = []; var next_t: = 10.0
	while _res.is_empty():
		await tree.process_frame
		if not is_instance_valid(r): break
		if r.race_time >= next_t and r.player and not r.player["done"]: trace.append(r.position_of(r.player));next_t += 10.0
		if r.race_time > 2.0: fmin = min(fmin, Engine.get_frames_per_second())
		if r.race_time > timeout: print("[matrix] TIMEOUT");break
	_res["fps_min"] = fmin
	if OS.get_environment("TTR_TRACE") == "1": print("[trace] pos every 10s: ", trace)
	return _res

func back_to_title() -> void :
	await wait(0.2)
	if main.race and is_instance_valid(main.race): main.race.queue_free();main.race = null
	main.show_title(); await wait(0.2)

func matrix(spec: String) -> void :
	for item in spec.split(",", false):
		var p: = item.split(":")
		var t: = int(p[0]); var md: = p[1] if p.size() > 1 else "race"; var w: = p[2] if p.size() > 2 else ""
		var d: = int(p[3]) if p.size() > 3 else 1
		if p.size() > 4: Game.data["settings"]["camera"] = int(p[4])
		var t0: = Time.get_ticks_msec()
		var res: = await race(t, md, w, d)
		var ok_run: bool = not res.is_empty() and res.has("position")
		if ok_run:
			var ms: = ""
			for mm in res.get("missions", []): ms += ("+" if mm["done"] else "-") + String(mm["id"]) + " "
			print("[matrix] cam=%d track=%d %s mode=%s weather=%s diff=%d pos=%d/%d time=%.1f finished=%s stars=%d coins=%d pick=%d xp=%d drift=%d missions=%s wall=%d resp=%d wall_s=%.0f" % [int(Game.data["settings"]["camera"]), t, Game.TRACKS[t]["id"], md, res["weather"], d, res["position"], res["racers"], res["time"], res["finished"], res["stars"], res["coins"], res["pickup_coins"], res["xp"], res["drift"], ms, res["stats"]["wall_hits"], res["stats"]["respawns"], (Time.get_ticks_msec() - t0) / 1000.0])
		ok(ok_run, "race %d %s %s finished with a result" % [t, md, w])
		await back_to_title()


func unit() -> void :
	var save_backup: = FileAccess.get_file_as_string(Game.SAVE_PATH) if FileAccess.file_exists(Game.SAVE_PATH) else ""

	Game.data = Game.default_data()
	Game.date_override = "2026-10-01"
	var p: = Progress.login_pending();ok(p.get("day", 0) == 1 and p["reward"] == 60, "login day1 pending $60")
	var c0: = int(Game.data["coins"]);ok(Progress.claim_login() == 60 and int(Game.data["coins"]) == c0 + 60, "login claim adds coins")
	ok(Progress.login_pending().is_empty() and Progress.claim_login() == 0, "no double claim same day")
	for d in range(2, 8):
		Game.date_override = "2026-10-%02d" % d
		var r: = Progress.claim_login();ok(r == Progress.LOGIN_REWARDS[d - 1], "day %d reward %d" % [d, r])
	ok(Progress.has("streak_7"), "streak_7 achievement on day 7")
	Game.date_override = "2026-10-08";ok(Progress.claim_login() == 300, "day 8 stays at 300")
	Game.date_override = "2026-10-10";ok(Progress.login_pending()["day"] == 1, "missed day resets streak")
	Game.date_override = "2026-11-01";Game.data["login"] = {"last": "2026-10-31", "streak": 3, "claimed": "2026-10-31"}
	ok(Progress.login_pending()["day"] == 4, "streak across month boundary")
	Game.date_override = "2027-01-01";Game.data["login"] = {"last": "2026-12-31", "streak": 2, "claimed": "2026-12-31"}
	ok(Progress.login_pending()["day"] == 3, "streak across year boundary")

	Game.data = Game.default_data()
	var toasts: Array = []
	var cb: = func(id): toasts.append(id)
	Game.achievement_unlocked.connect(cb)
	ok(Progress.check_all().is_empty(), "fresh save: no achievements")
	Game.stat_add("races_done");Game.stat_add("wins")
	var got: = Progress.check_all();ok(got.has("first_race") and got.has("first_win") and not got.has("wins_10"), "first race/win unlock")
	ok(Progress.check_all().is_empty(), "no repeat unlock")
	var before: = int(Game.data["coins"]);Game.stat_add("nitro_uses", 100);Progress.check_all()
	ok(Progress.has("nitro_100") and int(Game.data["coins"]) == before + Progress.ACH_REWARD, "nitro_100 + reward")
	for k in ["drift:5000", "coins_picked:500", "elim_wins:1", "cp_clears:1", "night_wins:1", "rain_wins:1", "paints:1", "missions:20", "tt3:1", "wins:9"]:
		var kv: PackedStringArray = String(k).split(":");Game.stat_add(kv[0], float(kv[1]))
	Game.data["owned"] = ["yellow", "red", "purple"]
	for i in 5: Game.data["stars"][Game.TRACKS[i]["id"]] = 3
	for i in range(5, 10): Game.data["stars"][Game.TRACKS[i]["id"]] = 3
	Progress.check_all()
	for a in Progress.ACHIEVEMENTS: if not Progress.has(a["id"]): print("[v4]   not unlocked: ", a["id"])
	ok(Game.data["ach"].size() == Progress.ACHIEVEMENTS.size() - 1, "all stat achievements (%d/%d, streak_7 separate)" % [Game.data["ach"].size(), Progress.ACHIEVEMENTS.size()])
	ok(toasts.size() == Game.data["ach"].size(), "achievement signal fired per unlock (%d) -> toast" % toasts.size())
	Game.achievement_unlocked.disconnect(cb)

	var rng: = RandomNumberGenerator.new()
	var bad: = 0
	for mode in ["race", "daily", "elimination", "time_trial", "checkpoint"]:
		for sd in 40:
			rng.seed = sd
			var ms: = Progress.pick_missions(mode, sd % 10, rng)
			var ids: = ms.map( func(x): return x["id"])
			if ms.size() != 3: bad += 1
			if ids.has("top3") and ids.has("win"): bad += 1
			if mode in ["time_trial", "checkpoint"] and (ids.has("top3") or ids.has("win")): bad += 1
			for mm in ms:
				if Progress.mission_text(mm).contains("%"): bad += 1
	ok(bad == 0, "missions: 3 per race, valid for mode, texts formatted (bad=%d)" % bad)
	var ms2: = [{"id": "coins", "n": 8}, {"id": "win", "n": 1}, {"id": "clean", "n": 2}, {"id": "speed", "n": 70}, {"id": "time", "n": 100}, {"id": "norespawn", "n": 0}]
	var st: = {"coins": 9, "drift": 0, "nitro_uses": 0, "pads": 0, "wall_hits": 3, "respawns": 0, "max_kmh": 71.0}
	Progress.evaluate(ms2, st, {"position": 1, "time": 99.0, "finished": true})
	ok(ms2.map( func(x): return x["done"]) == [true, true, false, true, true, true], "mission evaluation")
	Progress.evaluate(ms2, st, {"position": 1, "time": 99.0, "finished": false})
	ok( not ms2[1]["done"] and not ms2[4]["done"], "unfinished race fails finish-missions")

	var fixtures: = {
		"v1": {"coins": 1234, "xp": 560, "car": "red", "owned": ["yellow", "red"], "upgrades": {"red": {"speed": 2}}, "stars": {"pine_loop": 3, "tent_town": 2}, "best": {"pine_loop": 55.0}, "settings": {"music": 0.3, "camera": 1}}, 
		"v2": {"version": 2, "coins": 2500, "xp": 900, "car": "bike", "owned": ["yellow", "bike"], "upgrades": {}, "paint": {"bike": 4}, "stars": {"pine_loop": 3, "tent_town": 3, "zigzag": 2}, "best": {"pine_loop": 48.2}, "daily_done": "2026-01-01", "remove_ads": true, "races": 17, "settings": {"music": 0.5, "sfx": 0.6, "mute": false, "quality": 2, "touch": 1, "steer": 1.2, "camera": 2}}, 
		"v3": {"version": 3, "coins": 4100, "xp": 2400, "car": "purple", "owned": ["yellow", "purple", "red"], "upgrades": {"purple": {"handling": 3}}, "paint": {"purple": 7, "yellow": 2}, "stars": {"pine_loop": 3, "tent_town": 3, "zigzag": 3, "lakeside": 2, "canyon": 1, "esses": 1}, "best": {"esses": 101.5}, "daily_done": "2026-10-15", "remove_ads": false, "races": 44, "settings": {"music": 0.7, "sfx": 0.8, "mute": true, "quality": 0, "touch": 0, "steer": 1.0, "camera": 1, "auto_accel": false, "steer_mode": 1}}, 

		"v8": {"version": 4, "coins": 5321, "xp": 7300, "car": "green", "owned": ["yellow", "green", "red", "bike"], "upgrades": {"green": {"speed": 4, "accel": 2}}, "paint": {"green": 3}, "stars": {"pine_loop": 3, "tent_town": 3, "zigzag": 3, "lakeside": 3, "canyon": 2, "esses": 2, "dunes": 1}, "best": {"pine_loop": 41.3, "dunes": 88.0}, "daily_done": "2026-10-10", "remove_ads": false, "races": 120, "tips_seen": true, 
			"login": {"last": "2026-10-10", "streak": 3}, "ach": {"first_win": true}, "stats": {"wins": 30, "nitro_uses": 200}, "settings": {"music": 0.4, "sfx": 0.9, "mute": false, "quality": 1, "quality_choice": 3, "touch": 1, "steer": 1.1, "camera": 0, "difficulty": 1, "lang": "de", "auto_accel": true, "steer_mode": 0}}, 
	}
	for name in fixtures:
		var fx: Dictionary = fixtures[name]
		var f: = FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE);f.store_string(JSON.stringify(fx));f.close()
		Game.load_game()
		var keep: = true
		for k in ["coins", "xp", "car", "owned", "stars", "upgrades", "paint"]:
			if fx.has(k) and not _eq(Game.data[k], fx[k]): keep = false;print("[v4]   %s lost %s: %s -> %s" % [name, k, fx[k], Game.data[k]])
		for k in fx.get("settings", {}):
			if not _eq(Game.data["settings"][k], fx["settings"][k]): keep = false
		var v1best: bool = name != "v1" or Game.data["best"].is_empty()
		if name != "v1" and not _eq(Game.data["best"], fx["best"]): keep = false
		var newk: bool = Game.data.has("login") and Game.data.has("ach") and Game.data.has("stats") and Game.data["settings"].has("difficulty") and Game.data["settings"].has("lang") and int(Game.data["version"]) == 4
		ok(keep and newk and v1best, "migrate %s keeps progress (coins %d, stars %d) and gains v4 keys" % [name, Game.data["coins"], Game.total_stars()])
		Game.save_game();Game.load_game()
		ok(int(Game.data["coins"]) == int(fx["coins"]), "migrated %s survives save/load" % name)

	Game.data["coins"] = 4321;Game.save_game();Game.data["coins"] = 4322;Game.save_game()
	var f2: = FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE);f2.store_string("{broken");f2.close()
	Game.load_game();ok(int(Game.data["coins"]) == 4321, "corrupt save falls back to the backup (%d)" % int(Game.data["coins"]))
	f2 = FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE);f2.store_string("{broken");f2.close()
	DirAccess.remove_absolute(Game.SAVE_PATH + ".bak")
	Game.load_game();ok(int(Game.data["coins"]) == 100, "corrupt save without a backup falls back to defaults")

	Game.data["coins"] = 777;Game.save_game();Game.data["coins"] = 778;Game.data["saved_at"] = 1.0
	var f5: = FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE);f5.store_string(JSON.stringify(Game.data));f5.close()
	Game.load_game();ok(int(Game.data["coins"]) == 778, "readable save wins over an older-looking backup")

	var f4: = FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	f4.store_string("{\"version\": 4, \"coins\": null, \"xp\": \"x\", \"car\": 5, \"login\": [], \"settings\": {\"music\": null, \"quality_choice\": \"2\", \"tilt_invert\": 1, \"touch_size\": 1.2}}");f4.close()
	Game.load_game()
	var gs: Dictionary = Game.data["settings"]
	ok(int(Game.data["coins"]) == 100 and int(Game.data["xp"]) == 0 and Game.data["car"] == "yellow" and Game.data["login"] is Dictionary and float(gs["music"]) == 0.7 and int(gs["quality_choice"]) == 0 and gs["tilt_invert"] == false and is_equal_approx(float(gs["touch_size"]), 1.2), "damaged save values -> defaults, good ones kept")

	f4 = FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE);f4.store_string("{\"version\": 4, \"settings\": {\"quality_choice\": 0, \"auto_level\": 1, \"auto_scale\": 0.7}}");f4.close()
	Game.load_game();gs = Game.data["settings"]
	ok(int(gs["auto_level"]) == -1 and float(gs["auto_scale"]) == 1.0 and int(gs["gfx_rev"]) == 3, "1.0.2 save: Auto graphics re-detects once")
	f4 = FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE);f4.store_string("{\"version\": 4, \"settings\": {\"quality_choice\": 3, \"auto_level\": 1, \"auto_scale\": 0.7, \"gfx_rev\": 3}}");f4.close()
	Game.load_game();gs = Game.data["settings"]
	ok(int(gs["quality_choice"]) == 3 and int(gs["auto_level"]) == 1, "1.0.3 save: graphics settings kept")

	Game.data = Game.default_data();Game.data["tips_seen"] = true
	Game.data["coins"] = 0
	main.garage_sel = "yellow";main.show_garage(); await tree.process_frame
	ok( not main._buy_paint(3) and main.last_toast.begins_with(tr("Not enough coins: need $").substr(0, 10)), "paint denied toast: " + main.last_toast)
	ok( not main._buy_upgrade("speed") and main.last_toast != "", "upgrade denied toast")
	Game.data["coins"] = 100000;Game.data["xp"] = 100000
	ok(main._buy_paint(3) and Game.paint_of("yellow") == 3, "paint bought")
	ok(main._buy_upgrade("speed"), "upgrade bought: " + main.last_toast)
	ok(main._buy_car(Game.car_def("red")) and Game.car_owned("red"), "car bought: " + main.last_toast)
	await tree.process_frame; await tree.process_frame
	ok(main._toast_node != null and is_instance_valid(main._toast_node), "toast shown")
	if main._toast_node and is_instance_valid(main._toast_node):
		var pnl: Control = main._toast_node.get_child(0).get_child(0)
		var tr_rect: Rect2 = pnl.get_global_rect()
		var overlap: = ""
		for b in main.screen.find_children("*", "Control", true, false):
			if (b is SubViewportContainer or (b is Button and b.text.length() > 0 and b.name.begins_with("Car"))) and b.is_visible_in_tree() and b.get_global_rect().intersects(tr_rect): overlap += String(b.name) + " "
		ok(overlap == "", "toast (%s) does not cover car picker/preview %s" % [tr_rect, overlap])
	Progress.check_all();ok(Progress.has("painter") or Game.stat("paints") >= 1, "paint purchase counted for achievement")

	await glyphs()

	var f3: = FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE);f3.store_string(save_backup);f3.close()
	Game.date_override = "";Game.load_game()

func _eq(a, b) -> bool:
	if (a is int or a is float) and (b is int or b is float): return is_equal_approx(float(a), float(b))
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for k in b:
			if not a.has(k) or not _eq(a[k], b[k]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not _eq(a[i], b[i]): return false
		return true
	return a == b

func _font_has(fonts: Array, ch: int) -> bool:
	for fo in fonts:
		if fo.has_char(ch): return true
	return false

func glyphs() -> void :
	var langs: = ["en"] + Array(Strings.LANGS)
	for li in langs.size():
		var lang: String = langs[li]
		Game.data["settings"]["lang"] = lang;Loc.apply()
		var fv: FontVariation = Loc.font()
		var chain: Array = [fv.base_font] + Array(fv.base_font.fallbacks)
		var missing: = {}
		var texts: Array = Strings.T.keys() if lang == "en" else Strings.T.values().map( func(v): return v[li - 1])
		texts += Game.TRACKS.map( func(t): return t["name"]) + Game.CARS.map( func(c): return c["name"]) + ["$1234 ★☆✔✖ — 00:00.00 · km/h"]
		texts += Loc.LANG_NAMES.values()
		for s in texts:
			for i in String(s).length():
				var ch: = String(s).unicode_at(i)
				if ch < 32: continue
				if not _font_has(chain, ch): missing[String.chr(ch)] = true
		ok(missing.is_empty(), "glyphs %s: %d strings, missing=%s" % [lang, texts.size(), "".join(missing.keys())])
	Game.data["settings"]["lang"] = "auto";Loc.apply()


func _side_cam(r, v, side: = 1.0, dist: = 2.6, h: = 0.35) -> Camera3D:
	var cam: = Camera3D.new();r.add_child(cam);cam.fov = 40
	var pos: Vector3 = v.vehicle_model.global_position
	var right: Vector3 = v.vehicle_model.global_transform.basis.x.normalized()
	cam.global_position = pos + right * dist * side + Vector3(0, h, 0)
	cam.look_at(pos + Vector3(0, 0.25, 0));cam.current = true
	return cam

func shots() -> void :
	Game.data["coins"] = 5000;Game.data["xp"] = 3000
	for c in Game.CARS: if not Game.car_owned(c["id"]): Game.data["owned"].append(c["id"])
	for i in Game.TRACKS.size(): Game.data["stars"][Game.TRACKS[i]["id"]] = max(1, int(Game.data["stars"].get(Game.TRACKS[i]["id"], 0)))
	Game.data["settings"]["camera"] = 0
	if OS.get_environment("TTR_SHOTSET") == "lang": await _langs();return

	for car in ["yellow", "bike", "purple"]:
		Game.data["car"] = car
		OS.set_environment("TTR_WEATHER", "clear")
		main.start_race(0, "time_trial"); await wait(1.2)
		var r = main.race
		var cam: = _side_cam(r, r.player["v"]); await wait(0.3); await shot("wheel_%s" % car)
		cam.queue_free();r.view.current = true
		await back_to_title()
	Game.data["car"] = "yellow"
	OS.set_environment("TTR_WEATHER", "clear")
	main.start_race(0, "race"); await wait(1.0)
	var r2 = main.race
	await shot("missions_countdown")
	var ai = r2.racers[1]["v"]
	var c2: = _side_cam(r2, ai, -1.0); await wait(0.3); await shot("wheel_ai_car");c2.queue_free();r2.view.current = true
	await wait(6.0)
	for m in ChaseCam.MODES.size():
		r2.view.mode = m;r2.view.snap();r2._flash(tr(ChaseCam.NAMES[m])); await wait(1.6)
		await shot("cam_%d_%s" % [m, String(ChaseCam.NAMES[m]).to_lower()])
	r2.view.mode = 0;r2.view.snap()

	for kind in ["coin", "nitro", "pad"]:
		for it in r2.pickups.items:
			if it["kind"] == kind and it["active"]:
				var pc: = Camera3D.new();r2.add_child(pc);pc.fov = 50
				var pp: Vector3 = it["pos"]
				pc.global_position = pp + Vector3(5, 4.5, 5);pc.look_at(pp);pc.current = true
				await wait(0.4); await shot("pickup_%s" % kind);pc.queue_free();break
	r2.view.current = true
	await back_to_title()

	for w in [["rain", 3], ["night", 6], ["fog", 4], ["sunset", 5]]:
		OS.set_environment("TTR_WEATHER", w[0])
		main.start_race(w[1], "race"); await wait(9.0); await shot("weather_%s" % w[0])
		await back_to_title()
	OS.set_environment("TTR_WEATHER", "")

	main.start_race(0, "elimination")
	var re = main.race
	while is_instance_valid(re) and re.elim_done < 1: await wait(0.25)
	await wait(0.3); await shot("elimination_out")
	await back_to_title()

	main.start_race(1, "checkpoint"); await wait(8.0); await shot("checkpoint_hud"); await back_to_title()

	main.start_race(0, "time_trial")
	var rt = main.race
	while is_instance_valid(rt) and rt.state != "done": await tree.process_frame
	await wait(0.6); await shot("confetti_finish")
	while main.screen == null or not is_instance_valid(main.screen) or main.race != null and main.race.state != "done": await wait(0.2)
	await wait(2.6); await shot("results_missions")
	await back_to_title()

	Game.data["settings"]["flyby"] = true;OS.set_environment("TTR_FLYBY", "1")
	main.start_race(7, "race"); await wait(1.5); await shot("flyby"); await back_to_title()
	OS.set_environment("TTR_FLYBY", "")

	Game.data["tips_seen"] = false
	main.start_race(0, "race");main.race._show_tips(); await wait(0.6); await shot("tips");Game.data["tips_seen"] = true; await back_to_title()

	for id in ["first_race", "first_win", "painter", "garage3", "nitro_100"]: Progress.unlock(id)
	main.show_achievements(); await wait(0.6); await shot("achievements")
	Game.date_override = "2026-10-03";Game.data["login"] = {"last": "2026-10-02", "streak": 2, "claimed": "2026-10-02"}
	main.show_title();main._maybe_daily_login(); await wait(0.6); await shot("daily_reward")
	var claim: Button = main.login_layer.find_child("ClaimLogin", true, false)
	claim.pressed.emit(); await wait(0.5); await shot("daily_reward_toast")
	Game.date_override = ""
	main.show_modes(); await wait(0.5); await shot("modes")
	main.show_settings(); await wait(0.5); await shot("settings")
	main.show_tracks("time_trial"); await wait(0.5); await shot("time_trial_picker")
	main.show_title(); await wait(0.5); await shot("title_logo")
	var q0 = Game.data["settings"]["quality"];Game.data["settings"]["quality"] = 0;Game.apply_settings()
	for w in [["rain", 2], ["night", 3]]:
		OS.set_environment("TTR_WEATHER", w[0]);main.start_race(w[1], "race"); await wait(9.0); await shot("lowgfx_%s" % w[0]); await back_to_title()
	OS.set_environment("TTR_WEATHER", "");Game.data["settings"]["quality"] = q0;Game.apply_settings()
	await _langs()

func _langs() -> void :
	for lang in ["en"] + Array(Strings.LANGS):
		Game.data["settings"]["lang"] = lang;Loc.apply();
		main.show_title(); await wait(0.5); await shot("lang_%s_title" % lang)
		main.show_achievements(); await wait(0.4); await shot("lang_%s_awards" % lang)
	Game.data["settings"]["lang"] = "auto";Loc.apply()



func missionshots() -> void :
	var tag: = OS.get_environment("TTR_TAG")
	if OS.get_environment("TTR_LANG") != "": Game.data["settings"]["lang"] = OS.get_environment("TTR_LANG");Loc.apply()
	Game.data["settings"]["touch"] = 1;Game.data["settings"]["flyby"] = false
	for sz in [1.0, 1.4]:
		Game.data["settings"]["touch_size"] = sz
		main.start_race(0, "race")
		var r = main.race
		while r.state != "racing": await tree.process_frame
		await wait(1.0)
		var vs: Vector2 = main.get_viewport().get_visible_rect().size
		var pr: = Rect2(r.mission_panel.global_position, r.mission_panel.size)
		ok(r.mission_panel.visible and r.mission_panel.modulate.a > 0.9, "%s size %.1f: mission panel visible during race" % [tag, sz])
		ok(Rect2(Vector2.ZERO, vs).encloses(pr), "%s panel on screen %s in %s" % [tag, pr, vs])
		var sh: Dictionary = r.touch.shapes()
		for n in sh.keys():
			var tr_: Rect2 = Rect2(sh[n]["c"] - sh[n]["hs"] * 1.18, sh[n]["hs"] * 2.36)
			ok( not pr.intersects(tr_), "%s size %.1f: panel clear of touch %s" % [tag, sz, n])
		if r.minimap: ok( not pr.intersects(Rect2(r.minimap.global_position, r.minimap.size)), "%s panel clear of minimap" % tag)
		if sz == 1.0:
			await shot("mission_panel%s" % tag)

			var idx: = -1
			for i in r.missions.size():
				if r.missions[i]["id"] in Progress.LIVE_MISSIONS: idx = i;break
			ok(idx >= 0, "has a live mission")
			if idx >= 0:
				var m: Dictionary = r.missions[idx]
				var key: String = {"coins": "coins", "drift": "drift", "nitro": "nitro_uses", "pads": "pads", "speed": "max_kmh"}[m["id"]]
				var fired: = [false]
				r.mission_completed.connect( func(_i): fired[0] = true)
				r.rs[key] = m["n"] + 1 if key != "max_kmh" else float(m["n"]) + 1.0
				await wait(0.32); await shot("mission_complete_fx%s" % tag)
				ok(fired[0], "%s mission_completed fired for %s" % [tag, m["id"]])
				await wait(2.8); await shot("mission_after_fade%s" % tag)
				var row: Control = r.mission_rows[idx]["row"]
				ok( not row.visible, "%s completed mission row hidden after fade" % tag)
				var others: = 0
				for i in r.mission_rows.keys():
					if i != idx and r.mission_rows[i]["row"].visible: others += 1
				ok(others == r.missions.size() - 1, "%s other missions still listed (%d)" % [tag, others])
		await back_to_title()



func padtest() -> void :
	Game.data["settings"]["flyby"] = false;Game.data["settings"]["camera"] = 0
	for t in Game.TRACKS.size():
		main.start_race(t, "race"); await wait(0.5)
		var r = main.race
		var n: int = r.points.size(); var pads: = 0; var good: = 0
		for it in r.pickups.items:
			if it["kind"] != "pad": continue
			pads += 1

			var bi: = 0; var bd: = INF
			for i in n:
				var dd: float = (r.points[i] as Vector3).distance_to(it["pos"])
				if dd < bd: bd = dd;bi = i
			var travel: Vector3 = ((r.points[(bi + 1) % n] as Vector3) - (r.points[bi] as Vector3)).normalized()
			var fwd: Vector3 = - (it["node"] as Node3D).global_transform.basis.z.normalized()
			if fwd.dot(travel) > 0.95: good += 1
		ok(pads > 0 and good == pads, "track %d %s: %d/%d pads point along travel" % [t, Game.TRACKS[t]["id"], good, pads])
		await back_to_title()

	main.start_race(0, "race"); await wait(0.5)
	var rs_ = main.race
	for it in rs_.pickups.items:
		if it["kind"] == "pad":
			var f: Vector3 = - (it["node"] as Node3D).global_transform.basis.z
			var pc: = Camera3D.new();rs_.add_child(pc);pc.fov = 62
			pc.global_position = (it["pos"] as Vector3) - f * 8.5 + Vector3(0, 2.6, 0);pc.look_at((it["pos"] as Vector3) + f * 3.0);pc.current = true
			await wait(0.3); await shot("boost_pad_driver_view")
			pc.global_position = (it["pos"] as Vector3) + Vector3(0, 7, 0) - f * 0.01;pc.look_at(it["pos"], f); await wait(0.2); await shot("boost_pad_topdown")
			pc.queue_free();break
	await back_to_title()

	main.start_race(0, "race")
	var r = main.race
	while r.state != "racing": await tree.process_frame
	var v = r.player["v"]
	var shot_done: = false; var t0: = Time.get_ticks_msec()
	var before: = 0.0; var hit_speed: = -1.0; var after: = 0.0; var boost_seen: = 0.0; var flame: = false
	while Time.get_ticks_msec() - t0 < 90000:
		await tree.process_frame
		var pos: Vector3 = v.get_vehicle_position()
		if not shot_done:
			for it in r.pickups.items:
				if it["kind"] == "pad" and it["active"]:
					var to: Vector3 = (it["pos"] as Vector3) - pos;to.y = 0
					var dist: = to.length()
					if dist > 6.0 and dist < 9.0 and to.normalized().dot( - (it["node"] as Node3D).global_transform.basis.z) > 0.9:
						await shot("boost_pad_chase_approach");shot_done = true;before = v.speed_mps();break
		if shot_done and hit_speed < 0.0 and r.pad_boost_t > 0.0:
			hit_speed = v.speed_mps(); await tree.physics_frame; await tree.physics_frame
			boost_seen = v.boost;flame = v.nitro_active
			await wait(0.25); await shot("boost_pad_chase_hit"); await wait(0.75);after = v.speed_mps();break
	ok(shot_done, "approach shot taken")
	ok(hit_speed >= 0.0 and boost_seen >= 1.29 and flame, "pad boosts: engine power x%.2f with boost flame=%s (speed %.1f m/s at pad -> %.1f m/s 1 s later, info only)" % [boost_seen, flame, hit_speed, after])
	await back_to_title()



func _vis_in_view(c: Control) -> bool:
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	return c.is_visible_in_tree() and Rect2(Vector2.ZERO, vs).encloses(c.get_global_rect())

func v7shots() -> void :
	var tag: = OS.get_environment("TTR_TAG")
	Game.data["settings"]["flyby"] = false;Game.data["settings"]["touch"] = 1

	Game.data["stars"]["_test"] = 3
	main.start_race(0, "race")
	var r = main.race
	while r.state != "racing": await tree.process_frame
	r.player["time"] = 150.0;r.player["done"] = true;r.state = "done";r.hud.visible = false;r.touch.visible = false
	main._on_race_finished(r._result()); await wait(0.8)
	await shot("results_flow%s" % tag)
	var cont: Button = main.screen.find_child("Continue", true, false)
	ok(cont != null and cont.text == tr("NEXT RACE"), "%s results offers NEXT RACE (got %s)" % [tag, cont.text if cont else "none"])
	ok(main.screen.find_child("Garage", true, false) != null, "%s results offers GARAGE" % tag)
	for b in main.screen.find_children("*", "Button", true, false): if b.is_visible_in_tree(): ok(_vis_in_view(b), "%s results button '%s' on screen" % [tag, b.text])
	cont.pressed.emit(); await wait(0.6)
	ok(main.race != null and is_instance_valid(main.race) and main.race.track_index == 1, "%s NEXT RACE starts track 1 (not the title)" % tag)
	await back_to_title()
	Game.data["stars"].erase("_test")

	main.start_race(0, "race");r = main.race
	while r.state != "racing": await tree.process_frame
	r.player["time"] = 150.0;r.player["done"] = true;r.state = "done";r.hud.visible = false;r.touch.visible = false
	main._on_race_finished(r._result()); await wait(0.5)
	cont = main.screen.find_child("Continue", true, false)
	ok(cont != null and cont.text == tr("TRACKS"), "%s locked next track -> TRACKS (got %s)" % [tag, cont.text if cont else "none"])
	cont.pressed.emit(); await wait(0.6)
	ok(main.race == null and main.screen.find_child("Scroll", true, false) != null, "%s TRACKS opens track select" % tag)
	main.show_title(); await wait(0.3)

	for sc in [["settings", main.show_settings], ["awards", main.show_achievements], ["tracks", func(): main.show_tracks("race")]]:
		sc[1].call(); await wait(0.5)
		var back: Control = main.screen.find_child("Back", true, false)
		var scroll: ScrollContainer = main.screen.find_child("Scroll", true, false)
		ok(back != null and _vis_in_view(back), "%s %s: BACK pinned and visible" % [tag, sc[0]])
		if scroll:

			for k in 2:
				var e: = InputEventMouseButton.new();e.button_index = MOUSE_BUTTON_WHEEL_DOWN;e.pressed = true;e.factor = 1.0;e.position = scroll.get_global_rect().get_center();e.global_position = e.position
				main.get_viewport().push_input(e, true)
				await tree.process_frame
			await wait(0.4)
			var vmax: float = scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page
			ok(vmax <= 0.0 or scroll.scroll_vertical > 0, "%s %s: wheel scrolls (%d / %.0f)" % [tag, sc[0], scroll.scroll_vertical, vmax])
			ok(back != null and _vis_in_view(back), "%s %s: BACK still visible after scrolling" % [tag, sc[0]])
		if sc[0] == "settings": await shot("settings_pinned_back%s" % tag)
	main.show_title(); await wait(0.3)

	Game.data["settings"]["touch_layout"] = 1
	main.start_race(0, "race");r = main.race
	while r.state != "racing": await tree.process_frame
	await wait(0.5)
	r._toggle_pause(); await wait(0.4)
	ok(r.pause_controls.is_visible_in_tree(), "%s pause shows CONTROLS when touch is on" % tag)
	for tab in r.PAUSE_TABS.size():
		r._show_pause_tab(tab); await tree.process_frame
		for b in r.pause_controls.find_children("*", "Button", true, false):
			if b.is_visible_in_tree(): ok(_vis_in_view(b), "%s pause tab %d control '%s' on screen" % [tag, tab, b.name])
	r._show_pause_tab(1); await tree.process_frame
	r._set_preset(0); await wait(0.2)
	ok(r.touch.layout == 0 and r.touch.shapes().has("gas"), "%s preset A applied live (gas button present)" % tag)
	(r.pause_controls.find_child("touch_size", true, false) as HSlider).value = 1.3
	ok(absf(r.touch.size_k - 1.3) < 0.01 and absf(float(Game.data["settings"]["touch_size"]) - 1.3) < 0.01, "%s size slider live + saved" % tag)
	await wait(0.2); await shot("pause_controls%s" % tag)
	r._set_preset(2); await wait(0.1)
	ok(r.touch.tilt and not r.touch.shapes().has("left"), "%s preset C (tilt) live" % tag)
	r._set_preset(1)
	(r.pause_controls.find_child("touch_size", true, false) as HSlider).value = 1.0
	r._toggle_pause(); await wait(0.3)
	ok( not tree.paused and r.touch.auto_accel, "%s resumed with preset B" % tag)
	await back_to_title()

	Ads._loading_show( func(): pass); await wait(0.4); await shot("ad_loading%s" % tag)
	var cb: Control = Ads._loading.find_child("AdCancel", true, false) if Ads._loading else null
	ok(cb != null and _vis_in_view(cb), "%s ad loading Cancel visible" % tag)
	Ads._loading_hide()
