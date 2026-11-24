extends Node


const SAVE_PATH: = "user://save.json"
const TILE_SCALE: = 1.25
const CELL: = 9.99 * TILE_SCALE


const TRACKS: = [
	{"id": "pine_loop", "name": "Pine Loop", "start": Vector2i(0, 0), "moves": "RRRRRRRRDDRRRRRRDDDDDDLLLLLLLLLLLLLLUUUUUUUU", "stars_needed": 0}, 
	{"id": "tent_town", "name": "Tent Town", "start": Vector2i(0, 0), "moves": "RRRRRRRRRRRRDDDDLLLLDDDDLLLLLLLLUUUUUUUU", "stars_needed": 2}, 
	{"id": "zigzag", "name": "Zig Zag Ridge", "start": Vector2i(0, 0), "moves": "RRRRDDRRRRDDRRRDDDDDLLLLLLLLLLLUUUUUUUUU", "stars_needed": 4}, 
	{"id": "lakeside", "name": "Lakeside Sprint", "start": Vector2i(0, 0), "moves": "RRRRRRRRRRRRRRDDLLLLLDDLLLLLDDLLLLUUUUUU", "stars_needed": 7}, 
	{"id": "canyon", "name": "Canyon Hook", "start": Vector2i(0, 0), "moves": "RRRRRDDDDDRRRRUURRRDDDDDDLLLLLLLLLLLLUUUUUUUUU", "stars_needed": 10}, 
	{"id": "esses", "name": "Ridge Esses", "start": Vector2i(0, 0), "moves": "RRRRDDRRUURRDDRRUURRRRDDDDDDLLDDLLLLLLLLLLLLUUUUUUUU", "stars_needed": 12, "cup": 2, "obstacles": true, "bumps": true}, 
	{"id": "hairpin", "name": "Hairpin Hollow", "start": Vector2i(0, 0), "moves": "RRRRRRRRRRDDLLLLLLDDRRRRRRDDRRRRDDDDLLLLLLLLLLLLLLUUUUUUUUUU", "stars_needed": 14, "cup": 2, "obstacles": true, "bumps": true}, 
	{"id": "chicane", "name": "Chicane Valley", "start": Vector2i(0, 0), "moves": "RRRRRRDRRRRRURRRRRDDDDLLLDDDRRRDDDDLLLLLLDLLLLLLULLLLUUUUUUUUUUU", "stars_needed": 16, "cup": 2, "obstacles": true, "bumps": true}, 
	{"id": "twin", "name": "Twin Lakes", "start": Vector2i(0, 0), "moves": "RRRRRRRDDDRRRRRRUUURRRRRRRDDDDDDDDDLLLLLLLUUULLLLLLDDDLLLLLLLUUUUUUUUU", "stars_needed": 19, "cup": 2, "obstacles": true, "bumps": true}, 
	{"id": "grand", "name": "Grand Canyon GP", "start": Vector2i(0, 0), "moves": "RRRRRRRRDDLLLDDRRRRRUUUURRRRRDDDDDDDLLLDDRRRDDDLLLLLLUULLLUULLLDDDLLLUUUUUUUUUUU", "stars_needed": 22, "cup": 2, "obstacles": true, "bumps": true}, 
]


const WEATHER: = {"pine_loop": "clear", "tent_town": "sunset", "zigzag": "clear", "lakeside": "rain", "canyon": "fog", 
	"esses": "sunset", "hairpin": "night", "chicane": "rain", "twin": "fog", "grand": "night"}
const WEATHERS: = ["clear", "sunset", "rain", "fog", "night"]



const PAR: = {"pine_loop": 148, "tent_town": 134, "zigzag": 130, "lakeside": 128, "canyon": 154, 
	"esses": 115, "hairpin": 136, "chicane": 140, "twin": 160, "grand": 184}
const DIFFICULTY: = [
	{"name": "EASY", "skill": [0.86, 0.92], "band": [0.82, 1.06], "reward": 0.8}, 
	{"name": "NORMAL", "skill": [0.93, 0.99], "band": [0.88, 1.16], "reward": 1.0}, 
	{"name": "HARD", "skill": [0.99, 1.04], "band": [0.95, 1.24], "reward": 1.3}, 
]


const CARS: = [
	{"id": "yellow", "name": "Sunny", "model": "res://models/vehicle-truck-yellow.glb", "bike": false, "price": 0, "level": 1, "base": {"speed": 1.0, "accel": 1.0, "handling": 1.0, "drift": 1.0}}, 
	{"id": "red", "name": "Red Runner", "model": "res://models/vehicle-truck-red.glb", "bike": false, "price": 400, "level": 1, "base": {"speed": 1.05, "accel": 0.95, "handling": 1.0, "drift": 1.05}}, 
	{"id": "purple", "name": "Grape Ape", "model": "res://models/vehicle-truck-purple.glb", "bike": false, "price": 800, "level": 1, "base": {"speed": 1.0, "accel": 1.1, "handling": 1.05, "drift": 0.95}}, 
	{"id": "green", "name": "Forest Hauler", "model": "res://models/vehicle-truck-green.glb", "bike": false, "price": 0, "level": 3, "base": {"speed": 1.08, "accel": 1.0, "handling": 0.95, "drift": 1.1}}, 
	{"id": "bike", "name": "Zip Bike", "model": "res://models/vehicle-motorcycle.glb", "bike": true, "price": 0, "level": 5, "base": {"speed": 1.1, "accel": 1.15, "handling": 1.1, "drift": 0.9}}, 
]

const UPGRADES: = ["speed", "accel", "handling", "drift"]
const MAX_UPGRADE: = 5
const PAINT_COST: = 50

signal achievement_unlocked(id: String)

var data: = {}
var date_override: = ""
var autotest: = false
var autotest_human: = false


var race_mode: = "race"
var race_track: = 0



var perf_mode: = false

func _ready() -> void :
	autotest = "--autotest" in OS.get_cmdline_user_args() or OS.get_environment("TTR_AUTOTEST") == "1"
	if OS.has_feature("web") and str(JavaScriptBridge.eval("location.search", true)).contains("autotest"): autotest = true
	test_native = autotest and OS.get_environment("TTR_NATIVE") == "1"
	perf_mode = OS.has_feature("perf") or OS.has_feature("gd") or OS.get_environment("TTR_PERF") == "1" or (OS.has_feature("web") and str(JavaScriptBridge.eval("location.search", true)).contains("perf"))
	_setup_input()
	load_game()
	apply_settings()

	if OS.has_feature("web") and TouchControls.layout_from_settings(data["settings"]) == 2: TouchControls.tilt_request()
	if OS.has_feature("crazygames"): get_tree().node_added.connect(_cg_min_font)




const CG_MIN_FONT: = 18
func _cg_min_font(n: Node) -> void :
	if not (n is Label or n is Button): return
	( func():
		if is_instance_valid(n) and (n as Control).get_theme_font_size("font_size") < CG_MIN_FONT:
			(n as Control).add_theme_font_size_override("font_size", CG_MIN_FONT)).call_deferred()

func default_data() -> Dictionary:
	return {
		"coins": 100, "xp": 0, "car": "yellow", 
		"owned": ["yellow"], "upgrades": {}, "paint": {}, 
		"stars": {}, "best": {}, "daily_done": "", 
		"remove_ads": false, "races": 0, "version": 4, 
		"login": {"last": "", "streak": 0, "claimed": ""}, "ach": {}, "stats": {}, "tips_seen": false, 
		"settings": {"music": 0.7, "sfx": 0.8, "mute": false, "quality": 1, "touch": 0, "steer": 1.0, "camera": 1, "auto_accel": false, "steer_mode": 0, "touch_layout": 0, "nitro_pos": 0, "touch_size": 1.0, "touch_opacity": 0.7, "touch_lefty": false, "haptics": true, 
			"difficulty": 1, "lang": "auto", "auto_quality": true, "shake": true, "flyby": true, 
			"quality_choice": 0, "auto_level": -1, "auto_scale": 1.0, "tilt_sens": 1.0, "tilt_invert": false, "gfx_rev": 3}, 
	}

func load_game() -> void :
	data = default_data()



	var text: = ""; var best_t: = -1.0
	var cands: Array = []
	for path in [SAVE_PATH, SAVE_PATH + ".bak"]:
		if not FileAccess.file_exists(path): continue
		var sf: = FileAccess.open(path, FileAccess.READ)
		if sf == null: continue
		var txt: = sf.get_as_text();sf.close()

		if path == SAVE_PATH or cands.is_empty() or not (JSON.parse_string(cands[0]) is Dictionary): cands.append(txt)
	if _web_store(): cands.append(str(JavaScriptBridge.eval("window.__ttrStore.get()", true)))
	elif OS.has_feature("web"): cands.append(str(JavaScriptBridge.eval("(function(){try{return localStorage.getItem('ttr_save')||''}catch(e){return ''}})()", true)))
	for c in cands:
		if c == "" or c == "null": continue
		var pc = JSON.parse_string(c)
		if not (pc is Dictionary): continue
		var sa = pc.get("saved_at", 0.0)
		var t: float = float(sa) if (sa is float or sa is int) else 0.0
		if t > best_t: best_t = t;text = c
	if text != "":
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			for k in parsed.keys():
				data[k] = parsed[k]
			var ver = parsed.get("version", 1)
			if not (ver is float or ver is int): ver = 1
			if int(ver) < 2:
				data["best"] = {};data["version"] = 2
				for gf in DirAccess.get_files_at("user://"):
					if gf.begins_with("ghost_"): DirAccess.remove_absolute("user://" + gf)

			var dd: = default_data()
			for k in dd.keys():
				if not data.has(k): data[k] = dd[k]
			var defs: Dictionary = dd["settings"]
			if not (data["settings"] is Dictionary): data["settings"] = defs.duplicate()

			if not data["settings"].has("touch_layout"):
				var os_: Dictionary = data["settings"]
				data["settings"]["touch_layout"] = 2 if int(os_.get("steer_mode", 0)) == 1 else (1 if bool(os_.get("auto_accel", true)) else 0)


			var st: Dictionary = data["settings"]
			if int(st.get("gfx_rev", 0)) < 3:
				st["auto_level"] = -1;st["auto_scale"] = 1.0;st["gfx_rev"] = 3
			for k in defs.keys():
				if not data["settings"].has(k): data["settings"][k] = defs[k]
			_sanitize_settings(data["settings"], defs)
			for k in ["coins", "xp", "races"]:
				if not (data[k] is int or data[k] is float): data[k] = dd[k]
			for k in ["car", "daily_done"]:
				if not (data[k] is String): data[k] = dd[k]
			if not (data["login"] is Dictionary): data["login"] = dd["login"]
			for k in ["stars", "best", "paint", "upgrades", "ach", "stats"]:
				if not (data[k] is Dictionary): data[k] = {}
			if not (data["owned"] is Array): data["owned"] = ["yellow"]
			data["version"] = 4



func _sanitize_settings(st: Dictionary, defs: Dictionary) -> void :
	for k in defs.keys():
		var d = defs[k]; var v = st.get(k)
		var num_ok: = (d is int or d is float) and (v is int or v is float)
		if typeof(v) != typeof(d) and not num_ok: st[k] = d

var _save_dirty: = false


func save_soon() -> void :
	if _save_dirty: return
	_save_dirty = true
	get_tree().create_timer(0.3, true).timeout.connect(flush_save)

func flush_save() -> void :
	if _save_dirty: _save_dirty = false;save_game()

func _notification(what: int) -> void :
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PREDELETE]:
		flush_save()


	if native_mobile() and data.has("settings"):
		if what == NOTIFICATION_APPLICATION_PAUSED: AudioServer.set_bus_mute(0, true)
		elif what == NOTIFICATION_APPLICATION_RESUMED: AudioServer.set_bus_mute(0, bool(data["settings"]["mute"]))

func save_game() -> void :

	var tmp: = SAVE_PATH + ".tmp"
	var f: = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("save failed: %s" % FileAccess.get_open_error());return
	data["saved_at"] = Time.get_unix_time_from_system()
	var text: = JSON.stringify(data)
	f.store_string(text)
	f.close()

	if not OS.has_feature("web") and FileAccess.file_exists(SAVE_PATH): DirAccess.rename_absolute(SAVE_PATH, SAVE_PATH + ".bak")
	DirAccess.rename_absolute(tmp, SAVE_PATH)
	if _web_store(): JavaScriptBridge.get_interface("__ttrStore").put(text)
	elif OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").__ttrSaveText = text
		JavaScriptBridge.eval("try{localStorage.setItem('ttr_save', window.__ttrSaveText)}catch(e){}", true)




func reset_settings() -> void :
	data["settings"] = default_data()["settings"].duplicate(true)
	apply_settings()
	save_game()

func reset_progress() -> void :
	var keep: Dictionary = data.get("settings", {}).duplicate(true)
	var keep_ads: = bool(data.get("remove_ads", false))
	var keep_login: Dictionary = data.get("login", {}).duplicate(true)
	_save_dirty = false
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("ghost_") or f.begins_with("save.json"): DirAccess.remove_absolute("user://" + f)
	if _web_store(): JavaScriptBridge.eval("window.__ttrStore.clear()", true)
	elif OS.has_feature("web"): JavaScriptBridge.eval("try{localStorage.removeItem('ttr_save')}catch(e){}", true)
	data = default_data()
	data["settings"] = keep;data["remove_ads"] = keep_ads;data["tips_seen"] = true
	if not keep_login.is_empty(): data["login"] = keep_login
	save_game()


func _web_store() -> bool:
	return OS.has_feature("web") and bool(JavaScriptBridge.eval("!!window.__ttrStore", true))


func level() -> int: return 1 + int(data["xp"]) / 100
func total_stars() -> int:
	var s: = 0
	for k in data["stars"].keys(): s += int(data["stars"][k])
	return s
func track_unlocked(i: int) -> bool: return total_stars() >= int(TRACKS[i]["stars_needed"])
func car_def(id: String) -> Dictionary:
	for c in CARS:
		if c["id"] == id: return c
	return CARS[0]
func car_owned(id: String) -> bool:
	var c: = car_def(id)
	if int(c["level"]) > 1: return level() >= int(c["level"])
	return id in data["owned"]
func upgrade_level(car_id: String, stat: String) -> int:
	return int(data["upgrades"].get(car_id, {}).get(stat, 0))
func upgrade_cost(car_id: String, stat: String) -> int:
	return 100 * (upgrade_level(car_id, stat) + 1)
func apply_upgrade(car_id: String, stat: String) -> void :
	if not data["upgrades"].has(car_id): data["upgrades"][car_id] = {}
	data["upgrades"][car_id][stat] = upgrade_level(car_id, stat) + 1
func buy_upgrade(car_id: String, stat: String) -> bool:
	var cost: = upgrade_cost(car_id, stat)
	if upgrade_level(car_id, stat) >= MAX_UPGRADE or int(data["coins"]) < cost: return false
	data["coins"] = int(data["coins"]) - cost
	apply_upgrade(car_id, stat)
	save_game()
	return true
func car_stats(car_id: String) -> Dictionary:
	var c: = car_def(car_id)
	var out: = {}
	for s in UPGRADES:
		out[s] = float(c["base"][s]) * (1.0 + 0.04 * upgrade_level(car_id, s))
	return out
func paint_of(car_id: String) -> int: return int(data["paint"].get(car_id, 0))


func today() -> String: return date_override if date_override != "" else Time.get_date_string_from_system()
func daily_seed() -> int: return hash(today())
func daily_info() -> Dictionary:
	var rng: = RandomNumberGenerator.new()
	rng.seed = daily_seed()
	var t: = rng.randi_range(0, TRACKS.size() - 1)
	return {"track": t, "ai_boost": 1.0 + rng.randf_range(0.03, 0.08), "reward": 200 + rng.randi_range(0, 4) * 25, 
		"weather": WEATHERS[rng.randi_range(0, WEATHERS.size() - 1)]}


func apply_settings() -> void :
	apply_audio()
	var s: Dictionary = data["settings"]
	if perf_mode: _apply_perf(s);return
	var q: = int(s["quality"])
	get_viewport().msaa_3d = Viewport.MSAA_2X if q >= 2 else Viewport.MSAA_DISABLED
	get_viewport().scaling_3d_scale = 0.6 if q == 0 else 1.0


func apply_audio() -> void :
	var s: Dictionary = data["settings"]
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:


			AudioServer.add_bus(AudioServer.bus_count)
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(max(float(s["music"]), 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(max(float(s["sfx"]), 0.0001)))
	AudioServer.set_bus_mute(0, bool(s["mute"]))


const QUALITY_NAMES: = ["AUTO", "LOW", "MEDIUM", "HIGH"]
var _mobile_cache: = -1

func is_mobile() -> bool:
	if _mobile_cache == -1:
		var m: = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
		if OS.has_feature("web") and not m:
			m = bool(JavaScriptBridge.eval("/Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent) || (navigator.maxTouchPoints > 1 && matchMedia('(pointer: coarse)').matches)", true))
		_mobile_cache = 1 if m else 0
	return _mobile_cache == 1


func native_mobile() -> bool: return test_native or (OS.has_feature("mobile") and not OS.has_feature("web"))

var test_native: = false



func native_start_level(gpu: = "") -> int:
	if gpu == "": gpu = RenderingServer.get_video_adapter_name()
	gpu = gpu.to_lower()
	var num: = func(prefix: String) -> int:
		var m: = RegEx.create_from_string(prefix + "\\D{0,6}(\\d+)").search(gpu)
		return int(m.get_string(1)) if m else -1
	if gpu.contains("adreno"):
		var n: int = num.call("adreno")
		if n >= 640: return 2
		if n > 0 and n < 506: return 0
		return 1
	if gpu.contains("mali"):
		if RegEx.create_from_string("mali-?[t4]").search(gpu): return 0
		var g: int = num.call("mali-?g")



		if g in [76, 77, 78] or g >= 700: return 2
		if g in [31, 51, 71, 72]: return 0
		return 1
	if gpu.contains("immortalis") or gpu.contains("xclipse") or gpu.contains("apple"): return 2
	if gpu.contains("ge8") or gpu.contains("rogue"): return 0
	return 1


func set_quality_choice(c: int) -> void :
	var s: Dictionary = data["settings"]
	s["quality_choice"] = clampi(c, 0, 3)
	if c == 0: s["auto_level"] = -1;s["auto_scale"] = 1.0
	apply_settings()

func quality_choice() -> int: return int(data["settings"].get("quality_choice", 0))


func _effective_level(s: Dictionary) -> int:
	var c: = int(s.get("quality_choice", 0))
	if c > 0: return c - 1
	var al: = int(s.get("auto_level", -1))
	if al >= 0: return al
	if native_mobile(): return mini(native_start_level(), native_screen_cap())
	return 0 if is_mobile() else 1




func native_screen_cap(screen: = Vector2i.ZERO) -> int:
	if screen == Vector2i.ZERO: screen = DisplayServer.screen_get_size()
	var lo: = mini(screen.x, screen.y); var hi: = maxi(screen.x, screen.y)
	return 1 if lo >= 1200 and float(hi) / float(lo) < 1.9 else 2



const TARGET_3D_H: = [540.0, 720.0, 100000.0]
const TARGET_3D_H_NATIVE: = [600.0, 900.0, 100000.0]
func render_scale_for(level: int) -> float:
	var h: = float(get_viewport().get_visible_rect().size.y)
	var win_h: = float(DisplayServer.window_get_size().y) if not OS.has_feature("headless") else h
	if win_h <= 0.0: win_h = h
	var sc: = 1.0
	if native_mobile():
		sc = clampf(TARGET_3D_H_NATIVE[level] / win_h, 0.5, [0.8, 0.9, 1.0][level])
	elif is_mobile():
		sc = clampf(TARGET_3D_H[level] / win_h, 0.4, [0.75, 0.85, 1.0][level])
	else:
		sc = [0.7, 1.0, 1.0][level]
	return sc

func _apply_perf(s: Dictionary) -> void :
	var lvl: = _effective_level(s)
	s["quality"] = lvl
	var vp: = get_viewport()
	var sc: = render_scale_for(lvl)
	if int(s.get("quality_choice", 0)) == 0: sc = clampf(sc * float(s.get("auto_scale", 1.0)), 0.35, 1.0)
	var msaa: = Viewport.MSAA_2X if lvl >= 2 else Viewport.MSAA_DISABLED

	if native_mobile(): msaa = native_msaa(lvl, sc)


	if msaa == Viewport.MSAA_DISABLED or vp.msaa_3d > msaa: vp.msaa_3d = msaa
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = sc
	vp.msaa_3d = msaa
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_debanding = false

	var cap30: = (int(s.get("quality_choice", 0)) == 1) or (int(s.get("quality_choice", 0)) == 0 and float(s.get("auto_scale", 1.0)) < 0.8 and lvl == 0)
	Engine.max_fps = 30 if cap30 else 60

	Engine.max_physics_steps_per_frame = 3 if is_mobile() else 8


	var high_q: = RenderingServer.SHADOW_QUALITY_SOFT_LOW if native_mobile() else RenderingServer.SHADOW_QUALITY_SOFT_HIGH
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD if lvl == 0 else (RenderingServer.SHADOW_QUALITY_SOFT_LOW if lvl == 1 else high_q))
	RenderingServer.directional_shadow_atlas_set_size(1024 if lvl == 0 else (2048 if lvl == 1 or native_mobile() else 4096), true)
	for sun in get_tree().root.find_children("*", "DirectionalLight3D", true, false):

		(sun as DirectionalLight3D).shadow_enabled = lvl >= 1 and not sun.has_meta("no_shadow")
		(sun as DirectionalLight3D).directional_shadow_max_distance = 22.0 if lvl == 1 else 30.0
	for cam in get_tree().root.find_children("*", "Camera3D", true, false):
		if cam is ChaseCam: (cam as Camera3D).far = draw_distance(lvl)




static func native_msaa(lvl: int, scale: float) -> Viewport.MSAA:
	if scale < 0.999: return Viewport.MSAA_DISABLED
	return [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(lvl, 0, 2)]

func draw_distance(lvl: int) -> float: return [130.0, 180.0, 220.0][clampi(lvl, 0, 2)] if perf_mode else 220.0







var _scenes: = {}
var _kept: Array = []
var _envs: = {}
func scene(path: String) -> Resource:
	if not _scenes.has(path): _scenes[path] = load(path)
	return _scenes[path]

func keep_resources(root: Node) -> void :
	var keep: = {}
	var stack: Array = [root]
	while stack.size():
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D:
			if n.material_override: keep[n.material_override] = true
			if n.material_overlay: keep[n.material_overlay] = true
		if n is MeshInstance3D and n.mesh:
			keep[n.mesh] = true
			for i in n.get_surface_override_material_count():
				var m = n.get_surface_override_material(i)
				if m: keep[m] = true
		elif n is GPUParticles3D:
			if n.process_material: keep[n.process_material] = true
			for i in n.draw_passes: if n.get_draw_pass_mesh(i): keep[n.get_draw_pass_mesh(i)] = true
		elif n is CPUParticles3D and n.mesh: keep[n.mesh] = true
		elif n is MultiMeshInstance3D and n.multimesh and n.multimesh.mesh: keep[n.multimesh.mesh] = true
		elif n is GridMap and n.mesh_library: keep[n.mesh_library] = true
		for c in n.get_children(): stack.append(c)
	_kept = keep.keys()



func release_caches() -> void :
	_kept.clear();_envs.clear();_scenes.clear()
	Race._mats.clear();WeatherFX._mats.clear();Pickups._mats.clear();Paint._mats.clear();TouchControls._icon_cache.clear()
	FX._spark_mesh = null;SkidMarks._mm = null;Paint._shader = null
	Sound.music.stop();Sound.music.stream = null;Sound._music.clear()

func make_env(weather: = "clear") -> Environment:
	var key: = "%s_%d_%d" % [weather, int(perf_mode), quality_level() if perf_mode else 2]
	if _envs.has(key): return _envs[key]
	var e: = Environment.new()
	_envs[key] = e
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.78, 0.98)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.68, 0.8)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.tonemap_exposure = 1.0
	e.fog_enabled = true;e.fog_light_color = Color(0.62, 0.78, 0.98);e.fog_density = 0.004
	match weather:
		"sunset":
			e.background_color = Color(0.98, 0.62, 0.42);e.ambient_light_color = Color(0.85, 0.6, 0.55);e.ambient_light_energy = 0.5
			e.fog_light_color = Color(0.98, 0.6, 0.45);e.fog_density = 0.006
		"rain":
			e.background_color = Color(0.42, 0.47, 0.55);e.ambient_light_color = Color(0.5, 0.55, 0.62);e.ambient_light_energy = 0.5
			e.fog_light_color = Color(0.45, 0.5, 0.58);e.fog_density = 0.012


		"fog":
			e.background_color = Color(0.72, 0.75, 0.78);e.ambient_light_color = Color(0.72, 0.74, 0.78);e.ambient_light_energy = 0.72
			e.fog_light_color = Color(0.74, 0.77, 0.8);e.fog_density = 0.022
		"night":
			e.background_color = Color(0.05, 0.08, 0.18);e.ambient_light_color = Color(0.32, 0.38, 0.6);e.ambient_light_energy = 0.5
			e.fog_light_color = Color(0.06, 0.09, 0.2);e.fog_density = 0.008
	if perf_mode and quality_level() < 2:

		e.fog_density = max(e.fog_density, 0.016 if quality_level() == 0 else 0.009)
	e.glow_enabled = false;e.ssao_enabled = false;e.ssr_enabled = false;e.sdfgi_enabled = false
	return e

func track_par(i: int) -> float:
	var id: String = TRACKS[i]["id"]
	if PAR.has(id): return float(PAR[id])
	return String(TRACKS[i]["moves"]).length() * (3.9 if int(TRACKS[i].get("cup", 1)) == 2 else 3.5) * laps_for(i) / 3.0


func laps_for(i: int) -> int: return 2 if int(TRACKS[i].get("cup", 1)) == 2 else 3
func weather_for(i: int) -> String: return String(WEATHER.get(TRACKS[i]["id"], "clear"))
func difficulty() -> Dictionary: return DIFFICULTY[clamp(int(data["settings"].get("difficulty", 1)), 0, 2)]
func stat_add(key: String, n: float = 1.0) -> void : data["stats"][key] = float(data["stats"].get(key, 0.0)) + n
func stat(key: String) -> float: return float(data["stats"].get(key, 0.0))

func shadows_enabled() -> bool: return int(data["settings"]["quality"]) >= 1
func quality_level() -> int: return int(data["settings"]["quality"])

func _setup_input() -> void :
	_add_action("nitro", [KEY_SHIFT, KEY_SPACE], [JOY_BUTTON_A])
	_add_action("reset", [KEY_R], [JOY_BUTTON_Y])
	_add_action("pause", [KEY_P] if OS.has_feature("crazygames") else [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_add_action("camera", [KEY_C], [JOY_BUTTON_BACK])

func _add_action(name: String, keys: Array, buttons: Array) -> void :
	if InputMap.has_action(name): return
	InputMap.add_action(name, 0.5)
	for k in keys:
		var e: = InputEventKey.new();e.physical_keycode = k
		InputMap.action_add_event(name, e)
	for b in buttons:
		var j: = InputEventJoypadButton.new();j.button_index = b
		InputMap.action_add_event(name, j)
