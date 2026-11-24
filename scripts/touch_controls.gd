class_name TouchControls extends CanvasLayer





const SVG_ARROW: = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"128\" height=\"128\" viewBox=\"0 0 128 128\"><path d=\"M80 24 L40 64 L80 104\" fill=\"none\" stroke=\"#fff\" stroke-width=\"16\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></svg>"
const SVG_PEDAL: = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"128\" height=\"160\" viewBox=\"0 0 128 160\"><rect x=\"14\" y=\"8\" width=\"100\" height=\"144\" rx=\"22\" fill=\"none\" stroke=\"#fff\" stroke-width=\"9\"/><g fill=\"#fff\"><circle cx=\"44\" cy=\"36\" r=\"9\"/><circle cx=\"84\" cy=\"36\" r=\"9\"/><circle cx=\"44\" cy=\"64\" r=\"9\"/><circle cx=\"84\" cy=\"64\" r=\"9\"/><circle cx=\"44\" cy=\"92\" r=\"9\"/><circle cx=\"84\" cy=\"92\" r=\"9\"/><circle cx=\"44\" cy=\"120\" r=\"9\"/><circle cx=\"84\" cy=\"120\" r=\"9\"/></g></svg>"
const SVG_BRAKE: = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"128\" height=\"128\" viewBox=\"0 0 128 128\"><circle cx=\"64\" cy=\"64\" r=\"34\" fill=\"none\" stroke=\"#fff\" stroke-width=\"9\"/><path d=\"M26 30 A50 50 0 0 0 26 98 M102 30 A50 50 0 0 1 102 98\" fill=\"none\" stroke=\"#fff\" stroke-width=\"9\" stroke-linecap=\"round\"/><rect x=\"59\" y=\"44\" width=\"10\" height=\"26\" rx=\"5\" fill=\"#fff\"/><circle cx=\"64\" cy=\"82\" r=\"6\" fill=\"#fff\"/></svg>"
const SVG_NITRO: = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"128\" height=\"128\" viewBox=\"0 0 128 128\"><path d=\"M72 10 L30 72 L58 72 L50 118 L98 50 L68 50 Z\" fill=\"#fff\" stroke=\"#fff\" stroke-width=\"6\" stroke-linejoin=\"round\"/></svg>"

const SVG_TILT: = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"128\" height=\"128\" viewBox=\"0 0 128 128\"><g transform=\"rotate(-18 64 64)\"><rect x=\"22\" y=\"40\" width=\"84\" height=\"48\" rx=\"10\" fill=\"none\" stroke=\"#fff\" stroke-width=\"8\"/><circle cx=\"96\" cy=\"64\" r=\"4\" fill=\"#fff\"/></g><path d=\"M18 28 A54 54 0 0 1 58 10\" fill=\"none\" stroke=\"#fff\" stroke-width=\"7\" stroke-linecap=\"round\"/><path d=\"M110 100 A54 54 0 0 1 70 118\" fill=\"none\" stroke=\"#fff\" stroke-width=\"7\" stroke-linecap=\"round\"/><path d=\"M50 4 L60 10 L52 19\" fill=\"none\" stroke=\"#fff\" stroke-width=\"6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/><path d=\"M78 109 L68 118 L77 125\" fill=\"none\" stroke=\"#fff\" stroke-width=\"6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></svg>"

const LAYOUT_NAMES: = ["ARROWS + GAS/BRAKE", "AUTO GAS: ARROWS + BRAKE", "TILT + GAS/BRAKE"]

var active: = false
var layout: = 1
var auto_accel: = true
var tilt: = false
var lefty: = false
var size_k: = 1.0
var opacity: = 0.7
var haptics: = true
var touches: = {}
var steer: = 0.0
var gas: = false
var brake: = false
var nitro: = false
var nitro_charge: = 1.0
var pad: Control
var icons: = {}
var _last_state: = ""
var _t: = 0.0

static func layout_from_settings(s: Dictionary) -> int:
	if s.has("touch_layout"): return clamp(int(s["touch_layout"]), 0, 2)
	if int(s.get("steer_mode", 0)) == 1: return 2
	return 1 if bool(s.get("auto_accel", true)) else 0

class Pad extends Control:
	var tc
	func _draw() -> void :
		var sh: Dictionary = tc.shapes()
		for name in sh.keys():
			var b: Dictionary = sh[name]
			var on: bool = name in tc.touches.values()
			var c: Vector2 = b["c"]; var hs: Vector2 = b["hs"] * (0.92 if on else 1.0)
			var r: = Rect2(c - hs, hs * 2.0)
			var a: float = tc.opacity
			var accent: Color = b["accent"]
			if name == "nitro" and tc.nitro_charge >= 0.98 and not on:
				var g: = 0.5 + 0.5 * sin(tc._t * 6.0)
				for i in 3:
					var gr: = r.grow(6.0 + i * 6.0 + g * 4.0)
					_box(gr, Color(accent.r, accent.g, accent.b, (0.22 - i * 0.06) * a), Color(0, 0, 0, 0), 0, b["round"])
			var fill: = Color(1, 1, 1, (0.5 if on else 0.16) * a)
			if on: fill = fill.lerp(Color(accent.r, accent.g, accent.b, 0.7 * a), 0.55)
			_box(r, fill, Color(1, 1, 1, (0.85 if on else 0.45) * a), 3 if not on else 5, b["round"])
			if name == "nitro":
				var rad: float = hs.x + 2.0
				draw_arc(c, rad, - PI / 2, - PI / 2 + TAU * clamp(tc.nitro_charge, 0.0, 1.0), 48, Color(accent.r, accent.g, accent.b, 0.95 * a), 5.0, true)
			var tex: Texture2D = tc.icons[b["icon"]]
			var isz: Vector2 = b["isz"] * (0.92 if on else 1.0)
			var ir: = Rect2(c - isz / 2.0, isz)
			draw_texture_rect(tex, ir, false, Color(1, 1, 1, (1.0 if on else 0.8) * clamp(a + 0.15, 0.0, 1.0)))
	func _box(r: Rect2, fill: Color, edge: Color, bw: int, round: bool) -> void :
		var sb: = StyleBoxFlat.new();sb.bg_color = fill;sb.border_color = edge
		sb.set_border_width_all(bw);sb.anti_aliasing = true
		sb.set_corner_radius_all(int(min(r.size.x, r.size.y) / 2.0) if round else int(min(r.size.x, r.size.y) * 0.24))
		sb.corner_detail = 16
		draw_style_box(sb, r)

func _ready() -> void :
	layer = 5
	for n in ["arrow", "pedal", "brake", "nitro"]: icons[n] = _svg(get("SVG_" + n.to_upper()))
	icons["arrow_r"] = _svg(SVG_ARROW, true)
	pad = Pad.new();pad.tc = self
	pad.set_anchors_preset(Control.PRESET_FULL_RECT);pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pad)
	reload_settings()


func reload_settings() -> void :
	var s: Dictionary = Game.data["settings"]
	var mode: = int(s["touch"])
	active = mode == 1 or (mode == 0 and DisplayServer.is_touchscreen_available())
	layout = layout_from_settings(s)
	auto_accel = layout == 1
	tilt = layout == 2
	lefty = bool(s.get("touch_lefty", false))
	size_k = clamp(float(s.get("touch_size", 1.0)), 0.7, 1.4)
	opacity = clamp(float(s.get("touch_opacity", 0.7)), 0.3, 1.0)
	haptics = bool(s.get("haptics", true))
	nitro_pos = clampi(int(s.get("nitro_pos", 0)), 0, 2)
	touches.clear();steer = 0.0;gas = false;brake = false;nitro = false
	visible = active
	if pad: pad.queue_redraw()




const TILT_DEADZONE_DEG: = 4.0
const TILT_FULL_DEG: = 28.0
const TILT_CURVE: = 1.6
const TILT_SMOOTH: = 0.09
var _tilt_x: = 0.0
static var _js_tilt = null
static func _tilt_js():
	if _js_tilt == null and OS.has_feature("web"): _js_tilt = JavaScriptBridge.get_interface("__ttrTilt")
	return _js_tilt

var nitro_pos: = 0
const NITRO_POS_NAMES: = ["BESIDE PEDAL", "ABOVE PEDAL", "LEFT SIDE"]
static var tilt_override: = -9.0
static func tilt_raw() -> float:
	if tilt_override >= -1.0: return tilt_override
	if OS.has_feature("web"):
		var t = _tilt_js()
		return float(t.x) if t else 0.0





	var acc: = Input.get_accelerometer()
	if _native_upside_down(acc): acc.x = - acc.x
	return clampf(acc.x / 9.81, -1.0, 1.0)







static var _upside_down: = false
static var _upside_since: = -1
static var test_android: = false
static func _native_upside_down(acc: Vector3) -> bool:
	if not (OS.has_feature("android") or test_android): return false
	var want: = _upside_down
	if acc.y > 6.0 and acc.z < 2.0: want = true
	elif acc.y < -3.0: want = false
	if want == _upside_down: _upside_since = -1;return _upside_down
	var now: = Time.get_ticks_msec()
	if _upside_since < 0: _upside_since = now
	elif now - _upside_since > 500: _upside_down = want;_upside_since = -1
	return _upside_down


static func tilt_events() -> int:
	if OS.has_feature("web"):
		var t = _tilt_js()
		return int(t.events) if t else 0
	return 1 if Input.get_accelerometer() != Vector3.ZERO else 0


static func tilt_request() -> void :
	if OS.has_feature("web"): JavaScriptBridge.eval("window.__ttrTilt && window.__ttrTilt.request()", true)



static func tilt_probe(node: Node, fail: Callable, wait: = 1.5) -> void :
	if Game.autotest and not OS.has_feature("web"): return
	tilt_request()
	var tree: = node.get_tree()
	var t0: = Time.get_ticks_msec()
	while OS.has_feature("web") and bool(JavaScriptBridge.eval("!!(window.__ttrTilt && window.__ttrTilt.needsTap)", true)) and Time.get_ticks_msec() - t0 < 20000:
		await tree.create_timer(0.25, true, false, true).timeout
		if not is_instance_valid(node): return
	await tree.create_timer(wait, true, false, true).timeout
	if is_instance_valid(node) and tilt_events() == 0: fail.call()

func _update_tilt(d: float) -> void :
	_tilt_x = lerpf(_tilt_x, tilt_target(), 1.0 - exp( - d / TILT_SMOOTH))


static func tilt_target() -> float:
	var st: Dictionary = Game.data["settings"]
	var sens: = clampf(float(st.get("tilt_sens", 1.0)), 0.5, 2.0)
	var r: = clampf(tilt_raw() - float(st.get("tilt_zero", 0.0)), -1.0, 1.0)
	var deg: = rad_to_deg(asin(r))
	if bool(st.get("tilt_invert", false)): deg = - deg
	var full: = minf(TILT_FULL_DEG / sens, 60.0)
	var v: = clampf((absf(deg) - TILT_DEADZONE_DEG) / (full - TILT_DEADZONE_DEG), 0.0, 1.0)
	return signf(deg) * pow(v, TILT_CURVE)


static func tilt_recalibrate() -> void :
	Game.data["settings"]["tilt_zero"] = clampf(tilt_raw(), -0.6, 0.6)
	Game.save_game()


static var _icon_cache: = {}
static func icon(name: String) -> Texture2D:
	if not _icon_cache.has(name):
		var src: String = {"pedal": SVG_PEDAL, "brake": SVG_BRAKE, "nitro": SVG_NITRO, "arrow": SVG_ARROW, "tilt": SVG_TILT}[name]
		_icon_cache[name] = _svg(src)
	return _icon_cache[name]

static func _svg(src: String, mirror: = false) -> Texture2D:
	var img: = Image.new()
	if img.load_svg_from_string(src, 2.0) != OK: img = Image.create(8, 8, false, Image.FORMAT_RGBA8);img.fill(Color.WHITE)
	if mirror: img.flip_x()
	return ImageTexture.create_from_image(img)

func _process(d: float) -> void :
	if not active: return
	_t += d
	if tilt: _update_tilt(d)
	if nitro_charge >= 0.98: pad.queue_redraw()

func set_nitro_charge(v: float) -> void :
	if abs(v - nitro_charge) > 0.01: nitro_charge = v;pad.queue_redraw()




const EDGE_PAD: = 20.0
const PEDAL_HS: = Vector2(80.0, 104.0)
func shapes(vs: = Vector2.ZERO) -> Dictionary:
	var s: = vs if vs != Vector2.ZERO else get_viewport().get_visible_rect().size
	var k: float = clamp(min(s.x / 1280.0, s.y / 720.0), 0.6, 2.0) * size_k
	var m: = 36.0 * k
	var ml: = m; var mr: = m; var mb: = m
	if Game.native_mobile():
		var ins: = safe_insets(s)
		ml = m + EDGE_PAD * k + ins.x;mr = m + EDGE_PAD * k + ins.y;mb = m + ins.z
	var out: = {}
	var steer_r: = 74.0 * k
	var by: = s.y - mb - steer_r
	var nitro_col: = Color(0.35, 0.75, 1.0)
	var ped: = (PEDAL_HS if Game.native_mobile() else Vector2(70.0, 92.0)) * k
	var pedal_c: = Vector2(s.x - mr - ped.x, s.y - mb - ped.y)
	if not tilt:
		out["left"] = {"c": Vector2(ml + steer_r, by), "hs": Vector2.ONE * steer_r, "round": true, "icon": "arrow", "isz": Vector2.ONE * steer_r * 1.0, "accent": Color(1, 1, 1)}
		out["right"] = {"c": Vector2(ml + steer_r * 3.0 + 40.0 * k, by), "hs": Vector2.ONE * steer_r, "round": true, "icon": "arrow_r", "isz": Vector2.ONE * steer_r * 1.0, "accent": Color(1, 1, 1)}
		var pc: = pedal_c
		var nc: Vector2
		match nitro_pos:
			1: nc = Vector2(pc.x, pc.y - ped.y - 30.0 * k - 56.0 * k)
			2:
				if Game.native_mobile(): nc = Vector2(ml + steer_r * 2.0 + 20.0 * k, by - steer_r - 80.0 * k)
				else: nc = Vector2(ml + steer_r * 1.15, by - steer_r * 2.0 - 40.0 * k)
			_: nc = Vector2(pc.x - ped.x - 34.0 * k - 58.0 * k, pc.y - 104.0 * k)
		out["nitro"] = {"c": nc, "hs": Vector2.ONE * 56.0 * k, "round": true, "icon": "nitro", "isz": Vector2.ONE * 62.0 * k, "accent": nitro_col}
	else:
		out["nitro"] = {"c": Vector2(ml + 70.0 * k, s.y - mb - 70.0 * k), "hs": Vector2.ONE * 70.0 * k, "round": true, "icon": "nitro", "isz": Vector2.ONE * 76.0 * k, "accent": nitro_col}
	if auto_accel:

		out["brake"] = {"c": pedal_c, "hs": ped, "round": false, "icon": "brake", "isz": Vector2(ped.x * 1.25, ped.x * 1.25), "accent": Color(1, 0.35, 0.3)}
	else:
		out["gas"] = {"c": pedal_c, "hs": ped, "round": false, "icon": "pedal", "isz": Vector2(ped.x * 1.3, ped.y * 1.45), "accent": Color(0.4, 1, 0.5)}
		var bh: = Vector2(58.0, 58.0) * k
		out["brake"] = {"c": Vector2(pedal_c.x - ped.x - 34.0 * k - bh.x, s.y - mb - bh.y), "hs": bh, "round": false, "icon": "brake", "isz": bh * 1.4, "accent": Color(1, 0.35, 0.3)}
	if lefty:
		for n in out.keys():
			var b: Dictionary = out[n];b["c"] = Vector2(s.x - b["c"].x, b["c"].y)
		if out.has("left"):
			var lc: Vector2 = out["left"]["c"];out["left"]["c"] = out["right"]["c"];out["right"]["c"] = lc
	return out


static func safe_insets(vs: Vector2) -> Vector3:
	var win: = Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0 or OS.has_feature("headless"): return Vector3.ZERO
	var sa: = DisplayServer.get_display_safe_area()
	if sa.size.x <= 0 or sa.size.y <= 0: return Vector3.ZERO
	var f: = vs / win
	var l: = clampf(float(sa.position.x) * f.x, 0.0, vs.x * 0.1)
	var r: = clampf((win.x - float(sa.end.x)) * f.x, 0.0, vs.x * 0.1)
	var b: = clampf((win.y - float(sa.end.y)) * f.y, 0.0, vs.y * 0.1)
	return Vector3(l, r, b)

func hit(p: Vector2) -> String:
	var sh: = shapes()
	var best: = ""; var bd: = INF
	for name in sh.keys():
		var b: Dictionary = sh[name]
		var hs: Vector2 = b["hs"] * 1.18
		var d: Vector2 = (p - b["c"]).abs()
		var inside: bool = (d.length() <= hs.x) if b["round"] else (d.x <= hs.x and d.y <= hs.y)
		if inside and d.length() < bd: best = name;bd = d.length()
	return best

func _buzz(ms: int) -> void :
	if haptics and (OS.has_feature("mobile") or OS.has_feature("web")): Input.vibrate_handheld(ms)

func _input(e: InputEvent) -> void :
	if not active: return
	if e is InputEventScreenTouch:
		if e.pressed:
			var c: = hit(e.position)
			if c != "": touches[e.index] = c;_buzz(14 if c in ["left", "right"] else 22)
		else:
			touches.erase(e.index)
		_update()
	elif e is InputEventScreenDrag and touches.has(e.index):
		var cur: String = touches[e.index]
		if cur in ["left", "right"]:
			var c: = hit(e.position)
			if c in ["left", "right"] and c != cur: touches[e.index] = c;_buzz(10)
		elif cur in ["gas", "nitro"]:
			var c2: = hit(e.position)
			if c2 in ["gas", "nitro"] and c2 != cur: touches[e.index] = c2;_buzz(10)
		_update()

func _update() -> void :
	var v: = touches.values()
	steer = (1.0 if "right" in v else 0.0) - (1.0 if "left" in v else 0.0)
	gas = "gas" in v;brake = "brake" in v;nitro = "nitro" in v
	pad.queue_redraw()
	var st: = "steer=%d gas=%s brake=%s nitro=%s fingers=%d" % [steer, gas, brake, nitro, touches.size()]
	if Game.autotest and st != _last_state: print("[touch] ", st)
	_last_state = st


func drive_input() -> Vector2:
	if not active: return Vector2.ZERO
	var x: = steer
	if tilt: x = _tilt_x

	var y: = 0.0
	if brake: y = -1.0
	elif gas or auto_accel: y = 1.0
	return Vector2(x, y)
