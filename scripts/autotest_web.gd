class_name AutoTestWeb extends Node





var main
var _cb_probe = null
var _cb_cmd = null
var _ft: Array = []
var _last_us: = 0
var _fs: Array = []
var _player_ai: = false

func setup(m) -> void :
	main = m
	process_mode = Node.PROCESS_MODE_ALWAYS
	var s: Dictionary = Game.data["settings"]
	s["flyby"] = false;Game.data["tips_seen"] = true
	Game.autotest_human = true
	if str(JavaScriptBridge.eval("location.search", true)).contains("adforce"): Ads.test_force = true

	var w: = JavaScriptBridge.get_interface("window")
	_cb_probe = JavaScriptBridge.create_callback( func(_a): w.set("__ttrOut", JSON.stringify(probe())))
	_cb_cmd = JavaScriptBridge.create_callback( func(a): w.set("__ttrOut", JSON.stringify(cmd(JSON.parse_string(str(a[0])) if a.size() > 0 else {}))))
	w.set("__ttrProbe", _cb_probe);w.set("__ttrCmd", _cb_cmd)
	print("[webqa] ready")

func _process(_d: float) -> void :
	var now: = Time.get_ticks_usec()
	if _last_us > 0 and _ft.size() < 20000:
		_ft.append((now - _last_us) / 1000.0)
		var r = main.race
		_fs.append(r.state if r and is_instance_valid(r) else "menu")
	_last_us = now

func _yaw(v) -> float:
	var b: Basis = v.vehicle_model.global_transform.basis
	return rad_to_deg(atan2(b.z.x, b.z.z))

func probe() -> Dictionary:
	var d: = {"screen": str(main.screen.name) if main.screen and is_instance_valid(main.screen) else "", "paused": main.get_tree().paused, 
		"muted": AudioServer.is_bus_mute(0), "held": Ads.is_held(), "lang": Loc.lang, "provider": Ads.provider, "cg": OS.has_feature("crazygames"), "coins": int(Game.data["coins"]), 
		"cars": Game.data.get("owned", []).size() if Game.data.get("owned", []) is Array else 0, "stars": Game.total_stars(), "fps": Engine.get_frames_per_second(), 
		"ad_busy": Ads._busy, "loading_ad": Ads._loading != null and is_instance_valid(Ads._loading), "toast": ""}
	var r = main.race
	if r and is_instance_valid(r):
		var v = r.player["v"]
		d["race"] = {"state": r.state, "mode": r.mode, "t": r.race_time, "lap": r.player["lap"], "pos": r.position_of(r.player), "kmh": v.speed_mps() * 3.6 * 1.6, 
			"ls": v.linear_speed, "yaw": _yaw(v), "drift": v.drift_intensity, "nitro": r.nitro, "nitro_on": v.nitro_active, "boost": v.boost, 
			"in": [v.input.x, v.input.z], "grounded": v.raycast.is_colliding(), "p": [v.get_vehicle_position().x, v.get_vehicle_position().z], 
			"pause_menu": r.pause_layer.visible, "touch": r.touch != null and r.touch.active, "steer_out": v.steer_out if "steer_out" in v else v.input.x, 
			"gate": v.drift_gate if "drift_gate" in v else 1.0, "lean": absf(v.calculated_lean) * 2.0 * (v.drift_gate if "drift_gate" in v else 1.0)}
	return d

func cmd(c) -> Dictionary:
	if not (c is Dictionary): return {"ok": false, "err": "bad json"}
	var tree: SceneTree = main.get_tree()
	match str(c.get("do", "")):
		"race":
			if c.has("touch"): Game.data["settings"]["touch"] = int(c["touch"])
			main.start_race(int(c.get("track", 0)), str(c.get("mode", "race")))
			_player_ai = bool(c.get("ai", false))
			return {"ok": true}
		"play":
			main._play_break(int(c.get("track", 0)), str(c.get("mode", "race")));return {"ok": true}
		"ai":
			var r = main.race
			if r and is_instance_valid(r):
				var v = r.player["v"]
				if bool(c.get("on", true)):
					v.ai = Race.AIDriver.new();v.ai.race = r;v.ai.racer = r.player
				else: v.ai = null
			return {"ok": true}
		"end_race":
			var r = main.race
			if r and is_instance_valid(r) and r.state == "racing": r._player_finished()
			return {"ok": true}
		"progress": Ads.report_progress(Game.level(), Game.total_stars(), bool(c.get("happy", true)));return {"ok": true}
		"title":
			if main.race and is_instance_valid(main.race): main._free_race();main.get_tree().paused = false
			main.show_title();return {"ok": true}
		"screen":
			var n: = str(c.get("name", ""))
			match n:
				"settings": main.show_settings()
				"garage": main.show_garage()
				"modes": main.show_modes()
				"awards": main.show_achievements()
				"tracks": main.track_cup = int(c.get("cup", 1));main.show_tracks(str(c.get("mode", "race")))
				_: main.show_title()
			return {"ok": true}
		"focus":
			var f = main.get_viewport().gui_get_focus_owner()
			return {"ok": true, "focus": (str(f.name) + ":" + (f.text if "text" in f else "")) if f else ""}
		"set":
			Game.data["settings"][str(c["key"])] = c["value"];Game.apply_settings() if Game.has_method("apply_settings") else null
			if str(c["key"]) == "lang": Loc.apply()
			return {"ok": true}
		"touch_shapes":
			var rr = main.race
			if not (rr and is_instance_valid(rr) and rr.touch): return {"ok": false}
			rr.touch.reload_settings()
			var out: = {}
			var sh: Dictionary = rr.touch.shapes()
			for n in sh.keys(): out[n] = {"x": sh[n]["c"].x, "y": sh[n]["c"].y, "hx": sh[n]["hs"].x, "hy": sh[n]["hs"].y, "round": sh[n]["round"]}
			var vr: Vector2 = main.get_viewport().get_visible_rect().size
			return {"ok": true, "shapes": out, "vw": vr.x, "vh": vr.y, "active": rr.touch.active}
		"settings":
			return {"ok": true, "s": Game.data["settings"], "d": Game.default_data()["settings"], "music_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), 
				"sfx_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), "locale": TranslationServer.get_locale(), "cam": main.race.view.mode if main.race and is_instance_valid(main.race) else -1, 
				"touch_nitro_pos": main.race.touch.nitro_pos if main.race and is_instance_valid(main.race) and main.race.touch else -1}
		"data":
			Game.data[str(c["key"])] = c["value"];return {"ok": true}
		"save": Game.save_game();Game.flush_save() if Game.has_method("flush_save") else null;return {"ok": true}
		"shaders": return _shaders()
		"login":
			main._maybe_daily_login();return {"ok": true}
		"tracks": main.show_tracks(str(c.get("mode", "race")));return {"ok": true}
		"tilt":
			var r = main.race
			var sm = r.touch._tilt_x if r and is_instance_valid(r) and r.touch else null
			return {"ok": true, "target": TouchControls.tilt_target(), "smoothed": sm, "zero": float(Game.data["settings"].get("tilt_zero", 0.0))}
		"recalibrate": TouchControls.tilt_recalibrate();return {"ok": true, "zero": float(Game.data["settings"].get("tilt_zero", 0.0))}
		"frames_reset": _ft.clear();_fs.clear();_last_us = 0;return {"ok": true}
		"frames":
			var a: = _ft.duplicate(); var mx: = 0.0; var over: = 0
			for x in a:
				mx = max(mx, x)
				if x > 50.0: over += 1
			var by: = {}
			for i in a.size():
				var k: String = _fs[i] if i < _fs.size() else "?"
				by[k] = max(float(by.get(k, 0.0)), a[i])
			return {"ok": true, "n": a.size(), "max_ms": mx, "over50": over, "by_state": by, "list": a if bool(c.get("list", false)) else [], "states": _fs if bool(c.get("list", false)) else []}
		"buttons":
			var out: = []
			_collect_buttons(tree.root, out)
			var vr: Vector2 = main.get_viewport().get_visible_rect().size
			return {"ok": true, "buttons": out, "vw": vr.x, "vh": vr.y}
		"press":
			var want: = str(c.get("text", ""))
			var found = _find_button(tree.root, want)
			if found == null: found = _find_button(tree.root, want, true)
			if found == null: return {"ok": false, "err": "no button " + want}
			found.emit_signal("pressed");return {"ok": true}
		"labels":
			var out: = []
			_collect_labels(tree.root, out)
			var vr2: Vector2 = main.get_viewport().get_visible_rect().size
			return {"ok": true, "labels": out, "vw": vr2.x, "vh": vr2.y}
		"scroll":
			var scs: Array = tree.root.find_children("Scroll", "ScrollContainer", true, false)
			scs = scs.filter( func(n): return n.is_visible_in_tree())
			if scs.is_empty(): return {"ok": false, "err": "no scroll"}
			var sc: ScrollContainer = scs[0]
			var bar: = sc.get_v_scroll_bar(); var br: = bar.get_global_rect(); var rr: = sc.get_global_rect()
			var sl: = []
			for n in sc.find_children("*", "Slider", true, false):
				var r: Rect2 = n.get_global_rect()
				sl.append({"name": str(n.get_path()).get_file(), "x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y, "value": n.value, "min": n.min_value, "max": n.max_value})
			return {"ok": true, "sv": sc.scroll_vertical, "max": bar.max_value - bar.page, "rect": [rr.position.x, rr.position.y, rr.size.x, rr.size.y], 
				"bar": [br.position.x, br.position.y, br.size.x, br.size.y], "bar_visible": bar.visible, "sliders": sl, "popup": tree.root.find_children("*", "PopupMenu", true, false).any( func(pm): return pm.visible), "focus": str(main.get_viewport().gui_get_focus_owner())}
		"loading": return {"ok": true, "last_ms": Race.ld_last_ms}
		"test_blur": Ads.test_blur = bool(c.get("on", true));return {"ok": true}
		"hold": Ads.set_hold(str(c.get("src", "portal")), bool(c.get("on", true)));return {"ok": true}
		"ad":
			var res: = {"done": false, "ok": null}
			if str(c.get("kind", "interstitial")) == "rewarded": Ads.show_rewarded( func(ok): print("[webqa] rewarded ok=%s" % ok))
			else: Ads.show_interstitial( func(): print("[webqa] interstitial done"))
			return {"ok": true}
		"steer_settings":
			for k in c.keys(): if k != "do": Game.data["settings"][k] = c[k]
			return {"ok": true}
	return {"ok": false, "err": "unknown"}

func _visible(n: Node) -> bool:
	if n is CanvasItem and not n.is_visible_in_tree(): return false
	var p: = n.get_parent()
	while p:
		if p is CanvasLayer and not p.visible: return false
		p = p.get_parent()
	return true

func _collect_buttons(n: Node, out: Array) -> void :
	if n is BaseButton and _visible(n):
		var r: Rect2 = n.get_global_rect()
		out.append({"text": n.text if "text" in n else "", "name": str(n.name), "x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y, "disabled": n.disabled})
	for ch in n.get_children(): _collect_buttons(ch, out)

func _find_button(n: Node, want: String, prefix: = false):
	if n is BaseButton and _visible(n) and (("text" in n and (n.text == want or n.text.strip_edges() == want or (prefix and n.text.begins_with(want)))) or str(n.name) == want): return n
	for ch in n.get_children():
		var f = _find_button(ch, want, prefix)
		if f: return f
	return null

func _collect_labels(n: Node, out: Array) -> void :
	if (n is Label or n is Button) and _visible(n) and n.text != "":
		var r: Rect2 = n.get_global_rect()
		var shown: String = n.text if n.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED else n.atr(n.text)
		var fnt: Font = n.get_theme_font("font"); var fs: int = n.get_theme_font_size("font_size")
		var tw: = fnt.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if fnt else 0.0
		if n is Button and n.icon: tw += 0.0
		var wraps: bool = n is Label and n.autowrap_mode != TextServer.AUTOWRAP_OFF
		var pad: = 0.0
		if n is Button:
			var sb: StyleBox = n.get_theme_stylebox("normal")
			if sb: pad = sb.get_content_margin(SIDE_LEFT) + sb.get_content_margin(SIDE_RIGHT)
		var clipped: bool = n is Label and not wraps and n.clip_text and tw > r.size.x + 1
		out.append({"t": n.text, "shown": shown, "x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y, "tw": tw + pad, 
			"over": ( not wraps) and tw + pad > r.size.x + 2, "clip": clipped})
	for ch in n.get_children(): _collect_labels(ch, out)


func _shaders() -> Dictionary:
	var out: = {}
	var root: Node = main.race if main.race else main
	var stack: Array = [root]
	while stack.size():
		var n: Node = stack.pop_back()
		var mats: Array = []
		if n is GeometryInstance3D:
			if n.material_override: mats.append(n.material_override)
		if n is MeshInstance3D and n.mesh:
			for i in n.mesh.get_surface_count(): mats.append(n.mesh.surface_get_material(i))
			for i in n.get_surface_override_material_count(): mats.append(n.get_surface_override_material(i))
		if n is GridMap and n.mesh_library:
			for id in n.mesh_library.get_item_list():
				var m: Mesh = n.mesh_library.get_item_mesh(id)
				if m: for i in m.get_surface_count(): mats.append(m.surface_get_material(i))
		if n is GPUParticles3D and n.draw_pass_1:
			for i in n.draw_pass_1.get_surface_count(): mats.append(n.draw_pass_1.surface_get_material(i))
		for m in mats:
			if m == null: continue
			var sid: = "%s#%d" % [m.get_class(), m.get_instance_id()]
			if not out.has(sid): out[sid] = {"n": 0, "eg": "%s %s %s" % [n.get_class(), n.name, m.resource_path.get_file()]}
			out[sid]["n"] += 1
		for c in n.get_children(): stack.append(c)
	return out
