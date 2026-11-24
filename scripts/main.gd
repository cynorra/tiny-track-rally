extends Node


var ui_layer: CanvasLayer
var screen: Control
var race: Race
var backdrop: Node3D
var autotest: AutoTest
var last_race: = {"track": 0, "mode": "race"}

func _ready() -> void :
	ui_layer = CanvasLayer.new();add_child(ui_layer)
	Game.achievement_unlocked.connect( func(id):
		var a: = Progress.ach_def(id)
		_toast("★ " + tr("Achievement: %s") % tr(a["name"]) + "  +$%d" % Progress.ACH_REWARD, true)
		Sound.play("lap", 1.3))
	_make_backdrop()
	show_title()
	_warmup_paint()
	if OS.get_environment("TTR_TOPDOWN") != "": start_race(int(OS.get_environment("TTR_TRACK")), "race");return
	if Game.autotest:
		autotest = AutoTest.new();autotest.run(self)


func _make_backdrop() -> void :
	backdrop = Node3D.new();add_child(backdrop)
	var env: = WorldEnvironment.new();env.environment = Game.make_env();backdrop.add_child(env)
	var sun: = DirectionalLight3D.new();sun.rotation_degrees = Vector3(-50, -150, 0);sun.shadow_enabled = Game.shadows_enabled();backdrop.add_child(sun)
	var gm: = GridMap.new();gm.mesh_library = load("res://models/Library/mesh-library.tres");gm.cell_size = Vector3(9.99, 1, 9.99)
	gm.transform = Transform3D(Basis().scaled(Vector3.ONE * Game.TILE_SCALE), Vector3(0, -0.5 * Game.TILE_SCALE, 0));gm.collision_layer = 0;gm.collision_mask = 0;backdrop.add_child(gm)
	var info: = TrackBuilder.build(Game.TRACKS[0], gm)
	var pts: Array = info["points"]
	var cars: = ["vehicle-truck-yellow", "vehicle-truck-red", "vehicle-truck-purple"]
	for i in 3:
		var m: Node3D = load("res://models/%s.glb" % cars[i]).instantiate();backdrop.add_child(m)
		Paint.apply(m, cars[i].trim_prefix("vehicle-truck-"), i, false)
		var a: Vector3 = pts[0]; var b: Vector3 = pts[1]
		m.position = a + (b - a).normalized() * (3.0 * i - 3.0) + (b - a).normalized().cross(Vector3.UP) * (1.3 if i % 2 else -1.3)
		m.rotation.y = atan2(b.x - a.x, b.z - a.z)
	var cam: = Camera3D.new();cam.name = "Cam";cam.fov = 50;backdrop.add_child(cam)
	cam.set_meta("center", (info["lo"] + info["hi"]) / 2.0)
	cam.set_meta("ext", (info["hi"] - info["lo"]) / 2.0);cam.far = 400

func _process(delta: float) -> void :
	if backdrop and backdrop.visible:
		var cam: Camera3D = backdrop.get_node("Cam")
		var c: Vector3 = cam.get_meta("center")
		var t: = Time.get_ticks_msec() / 1000.0 * 0.06
		var ext: Vector3 = cam.get_meta("ext")
		cam.position = c + Vector3(cos(t) * ext.x * 0.75, 28, sin(t) * ext.z * 0.75)
		cam.look_at(c + Vector3(0, -2, 0))

var paint_warm: = false

func _detach_previews() -> void :
	for p in _previews.values():
		if is_instance_valid(p) and p.get_parent() and screen and screen.is_ancestor_of(p): p.get_parent().remove_child(p)







func _exit_tree() -> void :
	for p in _previews.values():
		if is_instance_valid(p) and p.get_parent() == null: p.free()
	_previews.clear()
	Game.release_caches()

func _set_screen(c: Control) -> void :
	_detach_previews()
	Game.flush_save()
	if screen: screen.queue_free()
	screen = c
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.theme = UI.make_theme()
	ui_layer.add_child(c)

func _coins_badge() -> Control:
	var p: = UI.panel()
	p.add_child(UI.label("$ %d   LV %d" % [Game.data["coins"], Game.level()], 24, Color(1, 0.82, 0.3)))
	var row: = HBoxContainer.new();row.alignment = BoxContainer.ALIGNMENT_END;row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_right = 1.0;row.offset_right = -20;row.offset_top = 20
	row.add_child(p)
	return row

func _title_label(t: String) -> Label:
	var l: = UI.label(t, 44);l.position = Vector2(28, 20);return l


func show_title() -> void :
	Sound.play_music("menu")
	backdrop.visible = true
	var root: = Control.new();root.name = "Title"
	var dim: = ColorRect.new();dim.color = Color(0.05, 0.07, 0.15, 0.25);dim.set_anchors_preset(Control.PRESET_FULL_RECT);dim.mouse_filter = Control.MOUSE_FILTER_IGNORE;root.add_child(dim)
	var v: = UI.vbox(14);v.alignment = BoxContainer.ALIGNMENT_CENTER
	var logo: = TextureRect.new();logo.texture = load("res://ui/logo.png");logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED;logo.custom_minimum_size = Vector2(660, 240);v.add_child(logo)
	var play: = UI.button("PLAY", func(): show_tracks("race"), 30, 340);play.name = "Play";v.add_child(play)
	var row: = UI.hbox(14);row.alignment = BoxContainer.ALIGNMENT_CENTER
	var mb: = UI.button("MODES", show_modes, 22, 220, "yellow");mb.name = "Modes";row.add_child(mb)
	var di: = Game.daily_info()
	var done: bool = Game.data["daily_done"] == Game.today()
	row.add_child(UI.button("DAILY" + (" ✓" if done else ""), func(): _play_break(di["track"], "daily"), 22, 220, "yellow"))
	v.add_child(row)
	var row2: = UI.hbox(14);row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_child(UI.button("GARAGE", show_garage, 22, 200, "grey"))
	var ab: = UI.button("AWARDS", show_achievements, 22, 200, "grey");ab.name = "Awards";row2.add_child(ab)
	row2.add_child(UI.button("SETTINGS", show_settings, 22, 200, "grey"))
	v.add_child(row2)
	root.add_child(UI.center(v))
	root.add_child(_coins_badge())
	var foot: = UI.label(tr("Daily Challenge: win on %s (%s) for +%d coins") % [Game.TRACKS[di["track"]]["name"], tr(String(di["weather"]).to_upper()), di["reward"]], 16, Color(0.85, 0.9, 1))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT);foot.position = Vector2(20, -36);foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(foot)
	var iap_test: = OS.is_debug_build() and not OS.has_feature("android")
	if not Game.data["remove_ads"] and (IAP.available() or iap_test):
		var ra: = UI.button("REMOVE ADS", func(): IAP.purchase("remove_ads");show_title(), 16, 160, "grey")
		ra.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT);ra.grow_horizontal = Control.GROW_DIRECTION_BEGIN;ra.grow_vertical = Control.GROW_DIRECTION_BEGIN
		ra.position = Vector2(-20, -20);ra.visible = IAP.available() or iap_test
		root.add_child(ra)
	_set_screen(root)
	if not Game.autotest or OS.get_environment("TTR_LOGIN") == "1": _maybe_daily_login()


var track_cup: = 1
func show_tracks(mode: String) -> void :
	var root: = Control.new()
	var mtitle: = {"race": tr("CUP %d") % track_cup, "time_trial": tr("TIME TRIAL"), "elimination": tr("ELIMINATION"), "checkpoint": tr("CHECKPOINT")}
	root.add_child(_title_label(mtitle.get(mode, "") + ("" if mode == "race" else "  ·  " + tr("CUP %d") % track_cup)))
	root.add_child(_coins_badge())
	var tabs: = UI.hbox(14);tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	for cup in [1, 2]:
		var first: = _cup_first(cup)
		var lbl: = "CUP %d" % cup
		if not Game.track_unlocked(first): lbl += "  %d★" % int(Game.TRACKS[first]["stars_needed"])
		var tb: = UI.button(lbl, func(): track_cup = cup;show_tracks(mode), 20, 200, "green" if cup == track_cup else "grey");tb.name = "Cup%d" % cup
		tabs.add_child(tb)
	var info: = UI.label(tr("Cup 1: 5 classic tracks, 3 laps, 4 rivals") if track_cup == 1 else tr("Cup 2: bigger, harder tracks, 2 laps, obstacles, 7 rivals"), 16, Color(0.85, 0.9, 1))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var h: = UI.hbox(10);h.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in Game.TRACKS.size():
		var td: Dictionary = Game.TRACKS[i]
		if int(td.get("cup", 1)) != track_cup: continue
		var p: = UI.panel(); var v: = UI.vbox(8);p.add_child(v);p.custom_minimum_size = Vector2(176, 0)
		v.add_child(UI.label(td["name"], 17))
		var stars: = int(Game.data["stars"].get(td["id"], 0))
		v.add_child(UI.label("★".repeat(stars) + "☆".repeat(3 - stars), 26, Color(1, 0.82, 0.25)))
		var best: float = float(Game.data["best"].get(td["id"], 0.0))
		v.add_child(UI.label(tr("Best:") + " " + (Race.fmt_time(best) if best > 0 else "--:--"), 14, Color(0.8, 0.85, 1)))
		var mm: = TrackPreview.new();mm.def = td;mm.custom_minimum_size = Vector2(160, 104);v.add_child(mm)
		v.add_child(UI.label(tr(Game.weather_for(i).to_upper()) + "  ·  " + tr("%d laps") % Game.laps_for(i), 12, Color(0.75, 0.8, 0.95)))
		if Game.track_unlocked(i):
			var b: = UI.button("RACE", func(): _play_break(i, mode), 20, 160);b.name = "Race%d" % i;v.add_child(b)
		else:
			var b: = UI.button(tr("%d★") % td["stars_needed"], func(): pass, 18, 160, "grey");b.disabled = true;v.add_child(b)
		h.add_child(p)
	var outer: = UI.vbox(16);outer.alignment = BoxContainer.ALIGNMENT_CENTER;outer.add_child(tabs);outer.add_child(info);outer.add_child(h)
	_scroll_screen(root, outer, show_title if mode == "race" else show_modes, 90)
	_set_screen(root)

func _cup_first(cup: int) -> int:
	for i in Game.TRACKS.size():
		if int(Game.TRACKS[i].get("cup", 1)) == cup: return i
	return 0


var garage_sel: = ""
func show_garage() -> void :
	if garage_sel == "": garage_sel = Game.data["car"]
	var root: = Control.new()
	var dim: = ColorRect.new();dim.color = Color(0.06, 0.08, 0.18, 0.78);dim.set_anchors_preset(Control.PRESET_FULL_RECT);root.add_child(dim)
	root.add_child(_title_label("GARAGE"))
	var badge: = _coins_badge();root.add_child(badge);_coins_label = badge.get_child(0).get_child(0)
	var c: = Game.car_def(garage_sel)

	var svc: = _preview(garage_sel)
	var paint: = Game.paint_of(garage_sel)
	Paint.set_paint(garage_sel, paint)

	var main: = UI.hbox(24);main.alignment = BoxContainer.ALIGNMENT_CENTER

	var pp: = UI.panel(); var pv: = UI.vbox(10);pp.add_child(pv);pv.add_child(UI.label(tr("PAINT ($%d)") % Game.PAINT_COST, 22))
	_swatches.clear()
	var grid: = GridContainer.new();grid.columns = 3;grid.add_theme_constant_override("h_separation", 8);grid.add_theme_constant_override("v_separation", 8)
	for i in Paint.COLORS.size():
		var b: = Button.new();b.custom_minimum_size = Vector2(52, 52)
		var sb: = StyleBoxFlat.new();sb.bg_color = Paint.COLORS[i] if i > 0 else Color(0.35, 0.38, 0.5);sb.set_corner_radius_all(10)
		if i == paint: sb.border_color = Color.WHITE;sb.set_border_width_all(4)
		for st in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(st, sb)
		if i == 0: b.text = "—"
		b.pressed.connect( func(): _buy_paint(i))
		grid.add_child(b)
		_swatches.append(b)
		b.add_theme_font_size_override("font_size", 14)
	pv.add_child(grid)
	_paint_label = UI.label(Paint.NAMES[paint], 18, Color(1, 0.85, 0.4));pv.add_child(_paint_label)
	_refresh_paint_ui.call_deferred(paint)
	_paint_msg = UI.label("" if Game.car_owned(garage_sel) else "Own this car to paint it", 15, Color(1, 0.55, 0.5));pv.add_child(_paint_msg)
	main.add_child(pp)
	var mid: = UI.vbox(6);mid.alignment = BoxContainer.ALIGNMENT_CENTER
	var nl: = UI.label(c["name"], 36);nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;mid.add_child(nl)
	mid.add_child(svc)
	var owned: = Game.car_owned(garage_sel)
	var act: Button
	if owned:
		if Game.data["car"] == garage_sel: act = UI.button("SELECTED", func(): pass, 24, 300, "grey");act.disabled = true
		else: act = UI.button("SELECT", func(): Game.data["car"] = garage_sel;Game.save_game();show_garage(), 24, 300)
	elif int(c["level"]) > 1:
		act = UI.button(tr("REACH LEVEL %d") % c["level"], func(): pass, 22, 300, "grey");act.disabled = true
	else:
		act = UI.button(tr("BUY  $%d") % c["price"], func(): pass, 24, 300, "yellow")
		var ab: = act;act.pressed.connect( func(): _buy_car(c, ab))
		_dim(act, int(Game.data["coins"]) < int(c["price"]))
	act.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mid.add_child(act)
	main.add_child(mid)

	var up: = UI.panel(); var uv: = UI.vbox(8);up.add_child(uv);up.custom_minimum_size.x = 330
	var stats: = Game.car_stats(garage_sel)
	for s in Game.UPGRADES:
		var lvl: = Game.upgrade_level(garage_sel, s)
		uv.add_child(UI.label("%s  Lv %d/%d" % [tr(s.to_upper()), lvl, Game.MAX_UPGRADE], 18, Color(0.8, 0.85, 1)))
		var row: = UI.hbox(8)
		var bar: = ProgressBar.new();bar.max_value = 1.0;bar.value = clamp((float(stats[s]) - 0.8) / 0.6, 0.05, 1.0);bar.show_percentage = false
		bar.custom_minimum_size = Vector2(150, 18);bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill: = StyleBoxFlat.new();fill.bg_color = Color(1, 0.65, 0.2);fill.set_corner_radius_all(6);bar.add_theme_stylebox_override("fill", fill)
		var bgs: = StyleBoxFlat.new();bgs.bg_color = Color(0.2, 0.24, 0.38);bgs.set_corner_radius_all(6);bar.add_theme_stylebox_override("background", bgs)
		row.add_child(bar)
		if lvl < Game.MAX_UPGRADE:
			var b: = UI.button("$%d" % Game.upgrade_cost(garage_sel, s), func(): pass, 18, 70)
			b.pressed.connect( func(): _buy_upgrade(s, b))
			b.custom_minimum_size = Vector2(80, 44)
			_dim(b, not owned or int(Game.data["coins"]) < Game.upgrade_cost(garage_sel, s))
			row.add_child(b)
			var fb: = UI.button("AD", func(): _free_upgrade(s), 16, 50, "yellow");fb.custom_minimum_size = Vector2(56, 44);fb.disabled = not owned
			if owned: _rewarded_gate(fb)
			elif Ads.provider == "none": fb.visible = false
			fb.tooltip_text = "Watch an ad for a free upgrade"
			row.add_child(fb)
		uv.add_child(row)
	main.add_child(up)

	var picker: = UI.hbox(10);picker.alignment = BoxContainer.ALIGNMENT_CENTER
	for car in Game.CARS:
		var lock: = "" if Game.car_owned(car["id"]) else ("  LV%d" % car["level"] if int(car["level"]) > 1 else "  $%d" % car["price"])
		var b: = UI.button(car["name"] + lock, func(): garage_sel = car["id"];show_garage(), 16, 150, "green" if car["id"] == garage_sel else "grey")
		picker.add_child(b)
	var outer: = UI.vbox(16);outer.alignment = BoxContainer.ALIGNMENT_CENTER;outer.add_child(main);outer.add_child(picker)
	var back: = UI.button("BACK", func(): garage_sel = ""; var cb: = garage_back;garage_back = Callable();(cb if cb.is_valid() else show_title).call(), 22, 200, "grey");back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER;outer.add_child(back)
	var cc: = UI.center(outer);cc.offset_top = 60;root.add_child(cc)
	_set_screen(root)

var _swatches: Array[Button] = []
var _paint_label: Label
var _paint_msg: Label
var _coins_label: Label
var _previews: = {}


func _buy_paint(i: int) -> bool:
	if not Game.car_owned(garage_sel):
		_toast(tr("Buy this car first to paint it"), false);Sound.play("beep", 0.5);_shake(_swatches[i] if i < _swatches.size() else null)
		return false
	var cur: = Game.paint_of(garage_sel)
	if i == cur: return true
	var btn: Control = _swatches[i] if i < _swatches.size() else null
	if i != 0:
		if int(Game.data["coins"]) < Game.PAINT_COST:
			_deny(Game.PAINT_COST, btn)
			return false
		Game.data["coins"] = int(Game.data["coins"]) - Game.PAINT_COST
	Game.data["paint"][garage_sel] = i
	if i != 0: Game.stat_add("paints");Progress.check_all()
	Game.save_soon()
	Paint.set_paint(garage_sel, i)
	_refresh_paint_ui(i)
	Sound.play("coin")
	_toast(tr("Painted %s") % tr(Paint.NAMES[i]) + ("  -$%d" % Game.PAINT_COST if i != 0 else ""), true)
	return true

func _refresh_paint_ui(sel: int) -> void :
	for k in _swatches.size():
		var b: = _swatches[k]
		if not is_instance_valid(b): continue
		var sb: StyleBoxFlat = b.get_theme_stylebox("normal")
		sb.set_border_width_all(4 if k == sel else 0);sb.border_color = Color.WHITE
		var locked: bool = k != 0 and k != sel and ( not Game.car_owned(garage_sel) or int(Game.data["coins"]) < Game.PAINT_COST)
		_dim(b, locked);b.text = "—" if k == 0 else ("$%d" % Game.PAINT_COST if locked else "")
	if is_instance_valid(_paint_label): _paint_label.text = Paint.NAMES[sel]
	if is_instance_valid(_paint_msg): _paint_msg.text = "" if Game.car_owned(garage_sel) else "Own this car to paint it"
	if is_instance_valid(_coins_label): _coins_label.text = "$ %d   LV %d" % [Game.data["coins"], Game.level()]

func _preview(car_id: String) -> SubViewportContainer:
	if _previews.has(car_id) and is_instance_valid(_previews[car_id]):
		var p: SubViewportContainer = _previews[car_id]
		if p.get_parent(): p.get_parent().remove_child(p)
		p.position = Vector2.ZERO
		return p
	var c: = Game.car_def(car_id)
	var svc: = SubViewportContainer.new();svc.stretch = true;svc.custom_minimum_size = Vector2(460, 330)
	var sv: = SubViewport.new();sv.transparent_bg = true;sv.own_world_3d = true;svc.add_child(sv)
	var model: Node3D = load(c["model"]).instantiate();sv.add_child(model)
	model.rotation_degrees.y = -35
	Paint.apply(model, car_id, Game.paint_of(car_id), true)
	var cam: = Camera3D.new();cam.position = Vector3(0, 1.5, 2.7);cam.rotation_degrees.x = -24;cam.fov = 40;sv.add_child(cam)
	var l: = DirectionalLight3D.new();l.rotation_degrees = Vector3(-45, 30, 0);sv.add_child(l)
	var we: = WorldEnvironment.new(); var e: = Environment.new();e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color = Color(0.7, 0.72, 0.85);e.ambient_light_energy = 0.9;we.environment = e;sv.add_child(we)
	var tw: = model.create_tween().set_loops();tw.tween_property(model, "rotation_degrees:y", 325.0, 8.0).from(-35.0)
	_previews[car_id] = svc
	return svc



func _warmup_paint() -> void :
	var holder: = Control.new();holder.position = Vector2(-4000, -4000);holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(holder)
	for car in Game.CARS: holder.add_child(_preview(car["id"]))
	for car in Game.CARS: Paint.set_paint(car["id"], 1)

	_toast("Not enough coins: need $0123456789, you have $ -+ Painted Bought upgraded Lv SPEED ACCEL HANDLING DRIFT", false)
	_toast_node.get_child(0).modulate.a = 0.0
	for k in 3: await get_tree().process_frame
	for car in Game.CARS: Paint.set_paint(car["id"], Game.paint_of(car["id"]))
	for k in 2: await get_tree().process_frame
	for p in holder.get_children(): holder.remove_child(p)
	holder.queue_free()
	if is_instance_valid(_toast_node): _toast_node.queue_free()
	last_toast = ""
	paint_warm = true


func _buy_car(c: Dictionary, btn: Control = null) -> bool:
	if Game.car_owned(c["id"]): return true
	if int(Game.data["coins"]) < int(c["price"]): _deny(int(c["price"]), btn);return false
	Game.data["coins"] = int(Game.data["coins"]) - int(c["price"])
	Game.data["owned"].append(c["id"]);Game.data["car"] = c["id"];Progress.check_all();Game.save_game();Sound.play("coin");show_garage()
	_toast(tr("Bought %s!  -$%d") % [c["name"], int(c["price"])], true)
	return true

func _buy_upgrade(stat: String, btn: Control = null) -> bool:
	if not Game.car_owned(garage_sel): _toast(tr("Buy this car first"), false);Sound.play("beep", 0.5);_shake(btn);return false
	var cost: = Game.upgrade_cost(garage_sel, stat)
	if Game.upgrade_level(garage_sel, stat) >= Game.MAX_UPGRADE: return false
	if int(Game.data["coins"]) < cost: _deny(cost, btn);return false
	if not Game.buy_upgrade(garage_sel, stat): return false
	Sound.play("coin");show_garage()
	_toast(tr("%s upgraded to Lv %d  -$%d") % [tr(stat.to_upper()), Game.upgrade_level(garage_sel, stat), cost], true)
	return true


var last_toast: = ""
var _toast_node: Node
func _toast(text: String, good: bool) -> void :
	last_toast = text
	if is_instance_valid(_toast_node): _toast_node.queue_free()
	var pnl: = PanelContainer.new()
	var sb: = StyleBoxFlat.new();sb.bg_color = Color(0.12, 0.5, 0.22, 0.95) if good else Color(0.7, 0.13, 0.13, 0.95)
	sb.set_corner_radius_all(14);sb.content_margin_left = 22;sb.content_margin_right = 22;sb.content_margin_top = 10;sb.content_margin_bottom = 10
	pnl.add_theme_stylebox_override("panel", sb);pnl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lb: = UI.label(text, 24);lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;pnl.add_child(lb)
	var row: = HBoxContainer.new();row.alignment = BoxContainer.ALIGNMENT_CENTER;row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_left = 0;row.anchor_right = 1;row.anchor_top = 0;row.anchor_bottom = 0;row.offset_top = 10;row.offset_bottom = 62
	row.add_child(pnl)
	var layer: = CanvasLayer.new();layer.layer = 50;layer.add_child(row);add_child(layer)
	_toast_node = layer
	var tw: = row.create_tween();tw.tween_interval(2.0);tw.tween_property(row, "modulate:a", 0.0, 0.4);tw.tween_callback(layer.queue_free)

func _deny(cost: int, btn: Control) -> void :
	_toast(tr("Not enough coins: need $%d, you have $%d") % [cost, int(Game.data["coins"])], false)
	Sound.play("beep", 0.5)
	_shake(btn)

func _shake(c: Control) -> void :
	if c == null or not is_instance_valid(c): return
	var tw: = c.create_tween()
	for k in 6: tw.tween_property(c, "position:x", c.position.x + (8.0 if k % 2 == 0 else -8.0), 0.04)
	tw.tween_property(c, "position:x", c.position.x, 0.04)


func _dim(b: Control, locked: bool) -> void :
	b.modulate = Color(1, 1, 1, 0.45) if locked else Color.WHITE
	b.set_meta("locked", locked)


func _tilt_unavailable() -> void :
	var s: Dictionary = Game.data["settings"]
	if TouchControls.layout_from_settings(s) != 2: return
	s["touch_layout"] = 1;s["auto_accel"] = true;s["steer_mode"] = 0;Game.save_game()
	_toast(tr("Tilt not available on this device/browser"), false)
	if screen and screen.find_child("Scroll", true, false) and screen.find_child("Footer", true, false) and not race: show_settings()


func _rewarded_gate(b: Button) -> void :
	if Ads.provider == "none": b.visible = false;return
	if not Ads.rewarded_gated(): return
	var upd: = func():
		if not is_instance_valid(b) or b.has_meta("used"): return
		var ok: = Ads.rewarded_ready()
		b.disabled = not ok;b.modulate.a = 1.0 if ok else 0.45
		b.tooltip_text = "" if ok else tr("Loading ad…")
	upd.call()
	b.pressed.connect( func(): b.set_meta("used", true))
	var t: = Timer.new();t.wait_time = 1.0;t.autostart = true;t.timeout.connect(upd);b.add_child(t)

func _free_upgrade(stat: String) -> void :
	Ads.show_rewarded( func(ok: bool):
		if ok and Game.upgrade_level(garage_sel, stat) < Game.MAX_UPGRADE:
			Game.apply_upgrade(garage_sel, stat);Game.save_game();Sound.play("coin")
		show_garage()
		if not ok: _toast(tr("No ad available right now"), false))


func show_modes() -> void :
	var root: = Control.new();root.add_child(_title_label("MODES"));root.add_child(_coins_badge())
	var h: = UI.hbox(18);h.alignment = BoxContainer.ALIGNMENT_CENTER
	for m in [["TIME TRIAL", "time_trial", "Race the clock and your ghost on any unlocked track."], 
			["ELIMINATION", "elimination", "Last place is knocked out every lap. Be the last car standing!"], 
			["CHECKPOINT", "checkpoint", "Reach each gate before the timer runs out. Gates add time."]]:
		var p: = UI.panel(); var v: = UI.vbox(12);p.add_child(v);p.custom_minimum_size = Vector2(330, 260)
		var t: = UI.label(m[0], 30, Color(1, 0.82, 0.3));t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;v.add_child(t)
		var d: = UI.label(m[2], 18);d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;d.custom_minimum_size = Vector2(300, 110);v.add_child(d)
		var mode: String = m[1]
		var b: = UI.button("SELECT TRACK", func(): show_tracks(mode), 20, 280);b.name = "Mode_" + mode;v.add_child(b)
		h.add_child(p)
	var outer: = UI.vbox(20);outer.alignment = BoxContainer.ALIGNMENT_CENTER;outer.add_child(h)
	var di: = Game.daily_info()
	var done: bool = Game.data["daily_done"] == Game.today()
	var db: = UI.button(tr("DAILY CHALLENGE") + (" ✔" if done else ""), func(): _play_break(di["track"], "daily"), 22, 340, "yellow");db.size_flags_horizontal = Control.SIZE_SHRINK_CENTER;outer.add_child(db)
	var back: = UI.button("BACK", show_title, 22, 200, "grey");back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER;outer.add_child(back)
	root.add_child(UI.center(outer))
	_set_screen(root)


func show_achievements() -> void :
	var root: = Control.new()
	root.add_child(_title_label(tr("AWARDS") + "  %d/%d" % [Game.data["ach"].size(), Progress.ACHIEVEMENTS.size()]));root.add_child(_coins_badge())
	var grid: = GridContainer.new();grid.columns = 3;grid.add_theme_constant_override("h_separation", 10);grid.add_theme_constant_override("v_separation", 10)
	for a in Progress.ACHIEVEMENTS:
		var got: = Progress.has(a["id"])
		var p: = UI.panel();p.custom_minimum_size = Vector2(380, 74);p.clip_contents = true; var v: = UI.vbox(2);p.add_child(v)
		var nl: = UI.label(("★ " if got else "") + tr(a["name"]), 20, Color(1, 0.82, 0.3) if got else Color(0.7, 0.72, 0.8));nl.clip_text = true;nl.custom_minimum_size.x = 350;v.add_child(nl)
		UI.fit_font.call_deferred(nl, 350.0, 20, 14)
		var dl: = UI.label(tr(a["desc"]), 15, Color(0.9, 0.92, 1) if got else Color(0.6, 0.62, 0.7));dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;dl.custom_minimum_size.x = 350;v.add_child(dl)
		p.modulate = Color.WHITE if got else Color(1, 1, 1, 0.6)
		grid.add_child(p)
	var outer: = UI.vbox(16);outer.add_child(grid)
	_scroll_screen(root, outer, show_title, 86)
	_set_screen(root)


var login_layer: CanvasLayer
func _maybe_daily_login() -> void :
	var p: = Progress.login_pending()
	if p.is_empty() or (login_layer and is_instance_valid(login_layer)): return
	login_layer = CanvasLayer.new();login_layer.layer = 30;add_child(login_layer)
	var bg: = ColorRect.new();bg.color = Color(0, 0, 0, 0.6);bg.set_anchors_preset(Control.PRESET_FULL_RECT);bg.theme = UI.make_theme();login_layer.add_child(bg)
	var pn: = UI.panel(); var v: = UI.vbox(14);pn.add_child(v)
	var t: = UI.label("DAILY REWARD", 44, Color(1, 0.82, 0.3));t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;v.add_child(t)
	var st: = UI.label(tr("Login streak: day %d") % int(p["day"]), 22);st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;v.add_child(st)
	var row: = UI.hbox(8);row.alignment = BoxContainer.ALIGNMENT_CENTER
	var day: = int(p["day"])
	for k in Progress.LOGIN_REWARDS.size():
		var box: = UI.panel(); var bv: = UI.vbox(2);box.add_child(bv);box.custom_minimum_size = Vector2(96, 92)
		var sb: = StyleBoxFlat.new();sb.set_corner_radius_all(12)
		sb.bg_color = Color(0.2, 0.6, 0.3) if k + 1 < min(day, 7) else (Color(0.95, 0.65, 0.15) if k + 1 == min(day, 7) else Color(0.18, 0.2, 0.32))
		box.add_theme_stylebox_override("panel", sb)
		var dl: = UI.label(tr("DAY %d") % (k + 1), 16);dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;bv.add_child(dl)
		var cl: = UI.label("$%d" % Progress.LOGIN_REWARDS[k], 22, Color(1, 0.9, 0.5));cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;bv.add_child(cl)
		row.add_child(box)
	v.add_child(row)
	var b: = UI.button(tr("CLAIM $%d") % int(p["reward"]), func():
		var got: = Progress.claim_login()
		Sound.play("coin")
		_toast(tr("Daily reward: +$%d") % got, true)
		login_layer.queue_free();login_layer = null
		if screen and is_instance_valid(screen) and backdrop.visible: show_title(), 26, 300, "yellow")
	b.name = "ClaimLogin";b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER;v.add_child(b)
	bg.add_child(UI.center(pn))


func show_settings() -> void :
	var s: Dictionary = Game.data["settings"]
	var root: = Control.new();root.add_child(_title_label("SETTINGS"))
	var p: = UI.panel(); var v: = UI.vbox(10);p.add_child(v);p.custom_minimum_size.x = 620
	for key in ["music", "sfx"]:
		var row: = UI.hbox(16); var l: = UI.label(key.to_upper(), 24);l.custom_minimum_size.x = 170;row.add_child(l)
		var sl: = HSlider.new();sl.min_value = 0;sl.max_value = 1;sl.step = 0.05;sl.value = float(s[key]);sl.custom_minimum_size = Vector2(320, 40)
		sl.value_changed.connect( func(x): s[key] = x;Game.apply_settings();Game.save_game())
		row.add_child(sl);v.add_child(row)
	var mute: = CheckButton.new();mute.text = "MUTE ALL";mute.button_pressed = bool(s["mute"])
	mute.toggled.connect( func(x): s["mute"] = x;Game.apply_settings();Game.save_game());v.add_child(mute)
	if Game.perf_mode:
		v.add_child(_option_row("GRAPHICS", Game.QUALITY_NAMES, Game.quality_choice(), func(i): Game.set_quality_choice(i);Game.save_game()))
	else:
		v.add_child(_option_row("GRAPHICS", ["LOW", "MEDIUM", "HIGH"], int(s["quality"]), func(i): s["quality"] = i;Game.apply_settings();Game.save_game()))
	v.add_child(_option_row("TOUCH UI", ["AUTO", "ON", "OFF"], int(s["touch"]), func(i): s["touch"] = i;Game.save_game()))
	var cam_names: = ["CHASE CLOSE", "CHASE FAR", "TOP-DOWN", "HOOD", "DRONE", "ISOMETRIC"]
	var cam_opts: Array = ChaseCam.ORDER.map( func(ci): return cam_names[ci])
	v.add_child(_option_row("CAMERA", cam_opts, max(0, ChaseCam.ORDER.find(int(s.get("camera", 1)))), func(i): s["camera"] = ChaseCam.ORDER[i];Game.save_game()))
	v.add_child(_option_row("DIFFICULTY", ["EASY", "NORMAL", "HARD"], int(s.get("difficulty", 1)), func(i): s["difficulty"] = i;Game.save_game()))
	var langs: Array = ["AUTO"] + Loc.LANG_NAMES.values()
	var codes: Array = ["auto"] + Loc.LANG_NAMES.keys()
	if not Loc.english_only(): v.add_child(_option_row("LANGUAGE", langs, max(0, codes.find(String(s.get("lang", "auto")))), func(i): s["lang"] = codes[i];Loc.apply();Game.save_game();show_settings()))
	if not Game.perf_mode: v.add_child(_option_row("AUTO GRAPHICS", ["OFF", "ON"], 1 if bool(s.get("auto_quality", true)) else 0, func(i): s["auto_quality"] = i == 1;Game.save_game()))
	v.add_child(_option_row("SCREEN SHAKE", ["OFF", "ON"], 1 if bool(s.get("shake", true)) else 0, func(i): s["shake"] = i == 1;Game.save_game()))
	v.add_child(_option_row("FLY-BY INTRO", ["OFF", "ON"], 1 if bool(s.get("flyby", true)) else 0, func(i): s["flyby"] = i == 1;Game.save_game()))
	v.add_child(_option_row("CONTROLS", TouchControls.LAYOUT_NAMES, TouchControls.layout_from_settings(s), func(i):
		s["touch_layout"] = i;s["auto_accel"] = i == 1;s["steer_mode"] = 1 if i == 2 else 0;Game.save_game()
		if i == 2: TouchControls.tilt_probe(self, _tilt_unavailable)))
	v.add_child(_slider_row("STEERING SENSITIVITY", 0.5, 1.5, float(s.get("steer", 1.0)), func(x): s["steer"] = x;Game.save_game()))
	v.add_child(_slider_row("TILT SENSITIVITY", 0.5, 2.0, float(s.get("tilt_sens", 1.0)), func(x): s["tilt_sens"] = x;Game.save_game()))
	v.add_child(_option_row("INVERT TILT", ["OFF", "ON"], 1 if bool(s.get("tilt_invert", false)) else 0, func(i): s["tilt_invert"] = i == 1;Game.save_game()))
	v.add_child(UI.recalibrate_button(22))
	v.add_child(_slider_row("BUTTON SIZE", 0.7, 1.4, float(s.get("touch_size", 1.0)), func(x): s["touch_size"] = x;Game.save_game()))
	v.add_child(_slider_row("BUTTON OPACITY", 0.3, 1.0, float(s.get("touch_opacity", 0.7)), func(x): s["touch_opacity"] = x;Game.save_game()))
	v.add_child(_option_row("NITRO BUTTON", TouchControls.NITRO_POS_NAMES, clampi(int(s.get("nitro_pos", 0)), 0, 2), func(i): s["nitro_pos"] = i;Game.save_game()))
	v.add_child(_option_row("LEFT-HANDED", ["OFF", "ON"], 1 if bool(s.get("touch_lefty", false)) else 0, func(i): s["touch_lefty"] = i == 1;Game.save_game()))
	v.add_child(_option_row("VIBRATION", ["OFF", "ON"], 1 if bool(s.get("haptics", true)) else 0, func(i): s["haptics"] = i == 1;Game.save_game()))
	v.add_child(UI.label("Keys: WASD / arrows drive, S + steer drift, Shift or Space nitro, C camera, R reset, P pause" if OS.has_feature("crazygames") else "Keys: WASD / arrows drive, S + steer drift, Shift or Space nitro, C camera, R reset, Esc pause", 15, Color(0.8, 0.85, 1)))
	var outer: = UI.vbox(16);outer.add_child(p)
	var reset: = UI.red_button(tr("RESET PROGRESS"), func(): _confirm(tr("Are you sure? This deletes all cars, coins and stars."), _reset_progress), 20, 300)
	reset.name = "ResetProgress";reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var rs: = UI.button("RESET SETTINGS", func(): _confirm(tr("Put every setting back to its default?"), func(): Game.reset_settings();Loc.apply();show_settings()), 20, 300, "grey")
	rs.name = "ResetSettings";rs.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.add_child(rs)
	outer.add_child(reset)
	_scroll_screen(root, outer, show_title, 80)
	_set_screen(root)


func _confirm(text: String, yes_cb: Callable) -> void :
	var layer: = CanvasLayer.new();layer.layer = 50;layer.name = "Confirm";add_child(layer)
	var dim: = ColorRect.new();dim.color = Color(0, 0, 0, 0.6);dim.set_anchors_preset(Control.PRESET_FULL_RECT);dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var cc: = CenterContainer.new();cc.set_anchors_preset(Control.PRESET_FULL_RECT);dim.add_child(cc)
	var p: = UI.panel(); var v: = UI.vbox(18);p.add_child(v);cc.add_child(p)
	var l: = UI.label(text, 24);l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;l.custom_minimum_size.x = 520
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;l.name = "Text";v.add_child(l)
	var row: = UI.hbox(24);row.alignment = BoxContainer.ALIGNMENT_CENTER;v.add_child(row)
	var yes: = UI.red_button(tr("YES"), func(): layer.queue_free();yes_cb.call(), 24, 200);yes.name = "Yes"
	var no: = UI.button(tr("NO"), func(): layer.queue_free(), 24, 200, "grey");no.name = "No"
	row.add_child(yes);row.add_child(no)
	no.call_deferred("grab_focus")

func _reset_progress() -> void :
	Game.reset_progress()
	show_title()



func _scroll_screen(root: Control, content: Control, back_cb: Callable, top: float) -> ScrollContainer:
	const FOOT: = 78.0
	var sc: = ScrollContainer.new();sc.name = "Scroll";sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.offset_top = top;sc.offset_bottom = - FOOT;sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 8
	var pad: = MarginContainer.new();pad.add_theme_constant_override("margin_bottom", 12);pad.add_theme_constant_override("margin_top", 6)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cc: = CenterContainer.new();cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL;cc.add_child(content);pad.add_child(cc);sc.add_child(pad)
	root.add_child(sc)
	sc.gui_input.connect( func(e): _smooth_wheel(sc, e))

	sc.get_v_scroll_bar().gui_input.connect( func(e): if e is InputEventMouseButton and e.pressed: _stop_wheel(sc))


	for n in [content] + content.find_children("*", "Control", true, false):
		if n.mouse_filter == Control.MOUSE_FILTER_STOP and (n is PanelContainer or n is Panel or n is ColorRect or n is TextureRect or n is Container):
			n.mouse_filter = Control.MOUSE_FILTER_PASS


	for bt in content.find_children("*", "BaseButton", true, false): _guard_button(bt, sc)

	for sl in content.find_children("*", "Range", true, false):
		if sl is Slider:
			sl.scrollable = false
			_guard_slider(sl, sc)
	var foot: = PanelContainer.new();foot.name = "Footer";foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE);foot.offset_top = - FOOT
	var fsb: = StyleBoxFlat.new();fsb.bg_color = Color(0.05, 0.07, 0.16, 0.82);fsb.border_width_top = 2;fsb.border_color = Color(1, 1, 1, 0.12)
	foot.add_theme_stylebox_override("panel", fsb)
	var back: = UI.button("BACK", back_cb, 22, 200, "grey");back.name = "Back";back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER;back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fc: = CenterContainer.new();fc.add_child(back);foot.add_child(fc)
	root.add_child(foot)
	return sc



func _smooth_wheel(sc: ScrollContainer, e: InputEvent) -> void :
	if not (e is InputEventMouseButton and e.pressed): return
	var dir: = 0
	if e.button_index == MOUSE_BUTTON_WHEEL_DOWN: dir = 1
	elif e.button_index == MOUSE_BUTTON_WHEEL_UP: dir = -1
	if dir == 0:
		_stop_wheel(sc)
		return
	sc.accept_event()
	var tw: Tween = sc.get_meta("wheel_tw") if sc.has_meta("wheel_tw") else null
	var gliding: bool = tw != null and tw.is_valid() and tw.is_running()
	var base: float = float(sc.get_meta("wheel_target")) if gliding and sc.has_meta("wheel_target") else float(sc.scroll_vertical)
	var vmax: float = max(0.0, sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page)

	var step: float = 90.0 * clampf(e.factor if e.factor > 0.0 else 1.0, 0.15, 1.5)
	var target: float = clamp(base + dir * step, 0.0, vmax)
	sc.set_meta("wheel_target", target)
	if gliding: tw.kill()
	tw = sc.create_tween();tw.tween_property(sc, "scroll_vertical", int(target), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	sc.set_meta("wheel_tw", tw)

func _stop_wheel(sc: ScrollContainer) -> void :
	var tw: Tween = sc.get_meta("wheel_tw") if sc.has_meta("wheel_tw") else null
	if tw and tw.is_valid(): tw.kill()
	sc.remove_meta("wheel_tw");sc.remove_meta("wheel_target")




func _guard_slider(sl: Slider, sc: ScrollContainer) -> void :
	sl.gui_input.connect( func(e: InputEvent):
		if e is InputEventMouseButton:
			if e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]: _smooth_wheel(sc, e);return
			if e.button_index != MOUSE_BUTTON_LEFT: return
			sl.accept_event()
			if e.pressed:
				_stop_wheel(sc)
				sl.set_meta("p0", e.global_position);sl.set_meta("s0", sc.scroll_vertical);sl.set_meta("mode", "")
			elif sl.has_meta("p0"):
				if str(sl.get_meta("mode")) == "": _slider_at(sl, e.position.x)
				sl.remove_meta("p0")
		elif e is InputEventMouseMotion and sl.has_meta("p0"):
			sl.accept_event()
			var d: Vector2 = e.global_position - sl.get_meta("p0")
			var mode: = str(sl.get_meta("mode"))
			if mode == "":
				if absf(d.x) > 10.0 and absf(d.x) > absf(d.y): mode = "x"
				elif absf(d.y) > 10.0: mode = "y"
				sl.set_meta("mode", mode)
			if mode == "x": _slider_at(sl, e.position.x)
			elif mode == "y": sc.scroll_vertical = int(float(sl.get_meta("s0")) - d.y)
		elif e is InputEventScreenTouch or e is InputEventScreenDrag:
			sl.accept_event())

func _guard_button(bt: BaseButton, sc: ScrollContainer) -> void :
	bt.gui_input.connect( func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_stop_wheel(sc);bt.set_meta("p0", e.global_position);bt.set_meta("s0", sc.scroll_vertical);bt.set_meta("mode", "")
			else:
				if bt.has_meta("p0") and str(bt.get_meta("mode")) == "y": bt.accept_event()
				bt.remove_meta("p0")
		elif e is InputEventMouseMotion and bt.has_meta("p0"):
			var d: Vector2 = e.global_position - bt.get_meta("p0")
			if str(bt.get_meta("mode")) == "" and absf(d.y) > 10.0 and absf(d.y) > absf(d.x):
				bt.set_meta("mode", "y")
				var was: = bt.disabled;bt.disabled = true;bt.disabled = was
			if str(bt.get_meta("mode")) == "y":
				bt.accept_event();sc.scroll_vertical = int(float(bt.get_meta("s0")) - d.y))

func _slider_at(sl: Slider, x: float) -> void :
	var g: = 12.0
	var r: float = clampf((x - g) / maxf(1.0, sl.size.x - 2.0 * g), 0.0, 1.0)
	sl.value = sl.min_value + r * (sl.max_value - sl.min_value)

func _slider_row(title: String, lo: float, hi: float, val: float, cb: Callable) -> Control:
	var row: = UI.hbox(16); var l: = UI.label(title, 22);l.custom_minimum_size.x = 250;row.add_child(l)
	var sl: = HSlider.new();sl.min_value = lo;sl.max_value = hi;sl.step = 0.05;sl.value = val;sl.custom_minimum_size = Vector2(260, 40)
	sl.value_changed.connect(cb);row.add_child(sl)
	return row

func _option_row(title: String, opts: Array, sel: int, cb: Callable) -> Control:
	var row: = UI.hbox(16); var l: = UI.label(title, 22);l.custom_minimum_size.x = 250;row.add_child(l)
	var ob: = OptionButton.new();for o in opts: ob.add_item(tr(o))
	ob.selected = sel;ob.custom_minimum_size = Vector2(260, 46);ob.item_selected.connect(cb);row.add_child(ob)
	ob.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	return row


func start_race(track: int, mode: String) -> void :
	last_race = {"track": track, "mode": mode}
	_detach_previews()
	Game.flush_save()
	if screen: screen.queue_free();screen = null
	backdrop.visible = false
	if race: _free_race()
	race = Race.new();race.setup(track, mode)
	race.race_finished.connect(_on_race_finished)
	race.quit_requested.connect( func(): _free_race();show_title())
	add_child(race)




func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_GO_BACK_REQUEST: go_back()

func go_back() -> void :
	var dlg: = get_node_or_null("Confirm")
	if dlg and not dlg.is_queued_for_deletion():
		var no: = dlg.find_child("No", true, false) as Button
		if no: no.pressed.emit()
		else: dlg.queue_free()
		return
	if login_layer and is_instance_valid(login_layer):
		var cl: = login_layer.find_child("ClaimLogin", true, false) as Button
		if cl: cl.pressed.emit()
		return
	if race and is_instance_valid(race) and race.state != "done":
		if race.state in ["racing", "countdown", "flyby"] and not Ads.is_held(): race._toggle_pause()
		return
	if screen == null or not is_instance_valid(screen) or screen.name == "Title":
		Game.flush_save();Game.save_game();get_tree().quit();return
	for b in screen.find_children("*", "Button", true, false):
		var bt: = b as Button
		if bt.is_visible_in_tree() and not bt.disabled and (bt.name == "Back" or bt.text in ["BACK", "MENU", tr("BACK"), tr("MENU")]):
			bt.pressed.emit();return
	show_title()



func _unhandled_input(e: InputEvent) -> void :
	if not (e.is_action_pressed("ui_up") or e.is_action_pressed("ui_down") or e.is_action_pressed("ui_left") or e.is_action_pressed("ui_right")): return
	if get_viewport().gui_get_focus_owner() != null: return
	if race and is_instance_valid(race) and race.state == "racing" and not get_tree().paused: return
	var b: = _first_button(self)
	if b: b.grab_focus();get_viewport().set_input_as_handled()

func _first_button(root: Node) -> Button:

	var layers: Array = []
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n.visible and n.layer >= 10: layers.append(n)
	layers.sort_custom( func(a, b): return a.layer > b.layer)
	for l in layers + ([screen] if screen and is_instance_valid(screen) else []):
		for c in l.find_children("*", "Button", true, false):
			if c.is_visible_in_tree() and not c.disabled and c.focus_mode != Control.FOCUS_NONE: return c
	return null


func _free_race() -> void :
	if race == null: return
	Game.keep_resources(race)
	race.queue_free();race = null

func _on_race_finished(res: Dictionary) -> void :
	if res.get("restart", false):
		start_race(last_race["track"], last_race["mode"]);return

	var td: Dictionary = Game.TRACKS[res["track"]]
	var lvl_before: = Game.level(); var stars_before: = Game.total_stars()
	Game.data["coins"] = int(Game.data["coins"]) + int(res["coins"])
	Game.data["xp"] = int(Game.data["xp"]) + int(res["xp"])
	if res["mode"] != "elimination": Game.data["stars"][td["id"]] = max(int(Game.data["stars"].get(td["id"], 0)), int(res["stars"]))
	if res["new_record"]: Game.data["best"][td["id"]] = res["time"]

	var won: bool = res["finished"] and int(res["position"]) == 1 and res["mode"] in ["race", "daily", "elimination"]
	if res["finished"]: Game.stat_add("races_done")
	if won: Game.stat_add("wins")
	if won and res["mode"] == "elimination": Game.stat_add("elim_wins")
	if won and res["weather"] == "night": Game.stat_add("night_wins")
	if won and res["weather"] == "rain": Game.stat_add("rain_wins")
	if res["mode"] == "checkpoint" and res["finished"]: Game.stat_add("cp_clears")
	if res["mode"] == "time_trial" and int(res["stars"]) == 3: Game.stat_add("tt3")
	Game.stat_add("drift", float(res["drift"]))
	for m in res.get("missions", []):
		if m["done"]: Game.stat_add("missions")
	if res.has("daily_bonus"): Game.data["daily_done"] = Game.today()
	Game.data["races"] = int(Game.data["races"]) + 1
	Progress.check_all()
	Game.save_game()
	Ads.report_progress(Game.level(), Game.total_stars(), won)
	var unlocks: Array = []
	for i in Game.TRACKS.size():
		if Game.total_stars() >= int(Game.TRACKS[i]["stars_needed"]) and stars_before < int(Game.TRACKS[i]["stars_needed"]): unlocks.append(tr("Track: %s") % Game.TRACKS[i]["name"])
	for c in Game.CARS:
		if int(c["level"]) > lvl_before and int(c["level"]) <= Game.level(): unlocks.append(tr("Car: %s") % c["name"])
	show_results(res, unlocks)

func show_results(res: Dictionary, unlocks: Array) -> void :
	var root: = Control.new()
	var dim: = ColorRect.new();dim.color = Color(0.03, 0.05, 0.12, 0.55);dim.set_anchors_preset(Control.PRESET_FULL_RECT);root.add_child(dim)
	var p: = UI.panel(); var v: = UI.vbox(10);p.add_child(v);p.custom_minimum_size.x = 520
	var places: = ["1ST PLACE!", "2ND PLACE", "3RD PLACE", "4TH PLACE", "5TH PLACE", "6TH PLACE", "7TH PLACE", "8TH PLACE"]
	var head: String = tr(places[clamp(int(res["position"]) - 1, 0, 7)])
	if res["mode"] == "time_trial": head = tr("FINISHED")
	if res["mode"] == "checkpoint": head = tr("CLEARED!") if res["finished"] else tr("TIME UP!")
	if res["mode"] == "elimination" and not res["finished"]: head = tr("ELIMINATED") + " · " + head
	var hl: = UI.label(head, 56, Color(1, 0.82, 0.25));hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;v.add_child(hl)
	var st: = UI.label("★".repeat(res["stars"]) + "☆".repeat(3 - res["stars"]), 54, Color(1, 0.82, 0.25));st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;v.add_child(st)
	v.add_child(UI.label(tr("Time: %s") % Race.fmt_time(res["time"]) + ("   " + tr("NEW RECORD!") if res["new_record"] else ""), 24))
	v.add_child(UI.label(tr("Best lap: %s    Drift: %d") % [Race.fmt_time(res["best_lap"]) if res["best_lap"] < 9000 else "--", res["drift"]], 20, Color(0.8, 0.85, 1)))
	if int(res.get("pickup_coins", 0)) > 0: v.add_child(UI.label(tr("Track coins: +%d") % res["pickup_coins"], 18, Color(1, 0.85, 0.4)))
	var mp: = UI.vbox(2)
	mp.add_child(UI.label(tr("MISSIONS") + "  (+%d)" % res.get("mission_bonus", 0), 18, Color(1, 0.82, 0.3)))
	for m in res.get("missions", []):
		mp.add_child(UI.label(("✔ " if m["done"] else "✖ ") + Progress.mission_text(m), 17, Color(0.5, 1, 0.6) if m["done"] else Color(0.75, 0.75, 0.8)))
	mp.name = "Missions";v.add_child(mp)
	if res.has("daily_bonus"): v.add_child(UI.label(tr("Daily challenge bonus: +%d") % res["daily_bonus"], 20, Color(0.5, 1, 0.6)))
	var coins_l: = UI.label(tr("+%d coins   +%d XP") % [res["coins"], res["xp"]], 30, Color(1, 0.82, 0.3));v.add_child(coins_l)
	for u in unlocks: v.add_child(UI.label(tr("UNLOCKED") + "  " + u, 22, Color(0.5, 1, 0.6)))
	var row: = UI.hbox(12);row.alignment = BoxContainer.ALIGNMENT_CENTER
	var dbl: = UI.button("x2 COINS (AD)", func(): pass, 20, 230, "yellow")
	dbl.pressed.connect( func():
		dbl.disabled = true
		Ads.show_rewarded( func(ok):
			if ok:
				Game.data["coins"] = int(Game.data["coins"]) + int(res["coins"]);Game.save_game();Sound.play("coin")
				coins_l.text = tr("+%d coins (doubled!)   +%d XP") % [int(res["coins"]) * 2, res["xp"]]
			else:
				dbl.disabled = false;dbl.remove_meta("used");_toast(tr("No ad available right now"), false)))
	row.add_child(dbl)
	v.add_child(row)
	_rewarded_gate(dbl)

	var md: String = last_race["mode"]; var tr_i: int = int(last_race["track"])
	var nxt: = _next_track(tr_i) if md != "daily" else -1
	var nav: = UI.hbox(10);nav.alignment = BoxContainer.ALIGNMENT_CENTER
	if nxt >= 0:
		var nb: = UI.button("NEXT RACE", func(): _after_race( func(): track_cup = int(Game.TRACKS[nxt].get("cup", 1));start_race(nxt, md)), 22, 210);nb.name = "Continue"
		nav.add_child(nb)
	else:
		var tmode: String = md if md in ["race", "time_trial", "elimination", "checkpoint"] else "race"
		var tb: = UI.button("TRACKS", func(): _after_race( func(): track_cup = int(Game.TRACKS[tr_i].get("cup", 1));show_tracks(tmode)), 22, 190);tb.name = "Continue"
		nav.add_child(tb)
	nav.add_child(UI.button("RETRY", func(): _after_race( func(): start_race(last_race["track"], last_race["mode"])), 20, 140, "grey"))
	var gb: = UI.button("GARAGE", func(): _after_race( func(): _garage_from_results(tr_i, md)), 20, 150, "grey");gb.name = "Garage"
	nav.add_child(gb)
	nav.add_child(UI.button("MENU", func(): _after_race(show_title), 20, 130, "grey"))
	row = nav
	v.add_child(row)
	root.add_child(UI.center(p))
	_set_screen(root)
	Sound.play("coin")

var garage_back: Callable = Callable()


func _play_break(t: int, mode: String) -> void :
	Ads.show_interstitial( func(): start_race(t, mode))

func _garage_from_results(t: int, md: String) -> void :
	var tmode: String = md if md in ["race", "time_trial", "elimination", "checkpoint"] else "race"
	garage_back = func(): track_cup = int(Game.TRACKS[t].get("cup", 1));show_tracks(tmode)
	show_garage()


func _next_track(t: int) -> int:
	var n: = t + 1
	if n < Game.TRACKS.size() and Game.track_unlocked(n): return n
	return -1


func _after_race(next: Callable) -> void :
	Ads.show_interstitial( func():
		if race: _free_race()
		next.call())
