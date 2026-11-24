extends Node
























signal ad_started
signal ad_finished

const ADMOB_INTERSTITIAL_ID: = "ca-app-pub-3940256099942544/1033173712"
const ADMOB_REWARDED_ID: = "ca-app-pub-3940256099942544/5224354917"
const MIN_SECONDS_BETWEEN_INTERSTITIALS: = 90.0

var provider: = "stub"
var test_force: = false
var _last_interstitial: = -30.0
var _busy: = false
var _js_cb_done = null
var _js_cb_sdk = null

var _gm_finish: Callable = Callable()
var _gm_seen_pause: = false
var _gm_was_paused: = false
var _gm_paused_by_ad: = false
const GM_REWARDED_WAIT: = 20.0
const GM_INTERSTITIAL_WAIT: = 8.0
const GD_INTERSTITIAL_WAIT: = 12.0
const GM_MAX_AD_TIME: = 75.0
const GPX_MAX_AD_TIME: = 150.0

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):

		var p = JavaScriptBridge.eval("(window.CrazyGames && window.CrazyGames.SDK) ? 'crazygames' : ((window.__ttrSdk && window.__ttrSdk.provider) ? String(window.__ttrSdk.provider) : 'none')", true)
		provider = str(p)
		if OS.has_feature("crazygames"): provider = "none"
		if provider == "crazygames":
			JavaScriptBridge.eval("window.CrazyGames.SDK.init && window.CrazyGames.SDK.init()", true)
		elif provider in ["gm", "gd", "gpx"]:
			_js_cb_sdk = JavaScriptBridge.create_callback(_on_gm_event)
			JavaScriptBridge.get_interface("window").set("_ttrOnSdk", _js_cb_sdk)
			if bool(JavaScriptBridge.eval("!!(window.__ttrSdk && window.__ttrSdk.adPlaying)", true)): _gm_pause()
		_js_cb_hold = JavaScriptBridge.create_callback(_on_js_hold)
		JavaScriptBridge.get_interface("window").set("_ttrOnHold", _js_cb_hold)
		var early = JavaScriptBridge.eval("JSON.stringify(window.__ttrHolds || {})", true)
		var ed = JSON.parse_string(str(early)) if early != null else null
		if ed is Dictionary:
			for k in ed.keys(): if bool(ed[k]): set_hold(str(k), true)
		if Game.autotest and provider == "none" and not str(JavaScriptBridge.eval("location.search", true)).contains("mode=adtest") and not str(JavaScriptBridge.eval("location.search", true)).contains("realads"): provider = "stub"
	elif OS.has_feature("android") and Engine.has_singleton("PoingGodotAdMob"):
		provider = "admob"
	elif OS.has_feature("android") or OS.has_feature("ios"):
		provider = "none"
	print("[Ads] provider = ", provider)


func sdk_available() -> bool:
	match provider:
		"gm", "gd", "gpx": return bool(JavaScriptBridge.eval("!!(window.__ttrSdk && window.__ttrSdk.available && window.__ttrSdk.available())", true))
		"crazygames", "admob", "stub": return true
	return false


func rewarded_ready() -> bool:
	match provider:
		"gd":
			if bool(JavaScriptBridge.eval("!!(window.__ttrSdk && window.__ttrSdk.rewardedReady)", true)): return true
			JavaScriptBridge.eval("window.__ttrPreloadRewarded && window.__ttrPreloadRewarded()", true)
			return false
	return true


func rewarded_gated() -> bool: return provider == "gd"

func ads_enabled() -> bool:
	return not bool(Game.data.get("remove_ads", false))


func gameplay_start() -> void :
	if provider == "crazygames": JavaScriptBridge.eval("window.CrazyGames.SDK.game.gameplayStart()", true)
func gameplay_stop() -> void :
	if provider == "crazygames": JavaScriptBridge.eval("window.CrazyGames.SDK.game.gameplayStop()", true)


func report_progress(level: int, score: int, happy: bool) -> void :
	if provider == "gpx": JavaScriptBridge.eval("window.__ttrProgress && window.__ttrProgress(%d, %d, %s)" % [level, score, "true" if happy else "false"], true)


func show_interstitial(done: Callable) -> void :
	var now: = Time.get_ticks_msec() / 1000.0

	var cooldown: = 0.0 if provider in ["gd", "gpx"] else MIN_SECONDS_BETWEEN_INTERSTITIALS
	if not ads_enabled() or _busy or now - _last_interstitial < cooldown or (Game.autotest and not test_force) or not sdk_available():
		done.call();return
	_last_interstitial = now
	_show("midgame", func(_ok): done.call())



func show_rewarded(done: Callable) -> void :
	if _busy or not sdk_available(): done.call(false);return
	_show("rewarded", done)

func _mute(on: bool) -> void :
	AudioServer.set_bus_mute(0, on or bool(Game.data["settings"]["mute"]) or _holds.size() > 0)


var _js_cb_hold = null
var _holds: = {}
var _hold_was_paused: = false
var _hold_opened_menu: = false
signal hold_changed(on: bool)

func _on_js_hold(args) -> void :
	if args.size() < 2: return
	var src: = str(args[0])
	if src == "blur" and Game.autotest and not test_blur: return
	set_hold(src, bool(args[1]))

var test_blur: = false







func _focus_lost() -> void :
	var race = _race()
	if race and race.state == "racing" and not get_tree().paused and not _busy:
		race._toggle_pause("blur")

func is_held() -> bool:
	for k in _holds.keys(): if k != "sound": return true
	return false


func set_hold(src: String, on: bool) -> void :
	if src == "blur":
		if Game.autotest or OS.is_debug_build(): print("[Ads] focus %s" % ("lost" if on else "back"))
		if on: _focus_lost()
		return
	var was: = is_held()
	if on: _holds[src] = true
	else: _holds.erase(src)
	var now: = is_held()
	if Game.autotest or OS.is_debug_build(): print("[Ads] hold %s %s -> held=%s sound_off=%s" % [src, on, now, _holds.has("sound")])
	_mute(_busy)
	if now == was: return
	var race = _race()
	if now:
		_hold_opened_menu = false
		if race and race.state == "racing" and not get_tree().paused:
			race._toggle_pause("hold");_hold_opened_menu = true
		elif race and get_tree().paused and race.pause_layer.visible and race.pause_by == "blur":


			race.pause_by = "hold";_hold_opened_menu = true
		else:
			_hold_was_paused = get_tree().paused
			get_tree().paused = true
	else:
		if _hold_opened_menu:

			if src == "portal" and race and is_instance_valid(race) and get_tree().paused and race.pause_layer.visible and race.pause_by != "player": race._toggle_pause("hold")
		elif not _gm_paused_by_ad:
			get_tree().paused = _hold_was_paused
		_hold_opened_menu = false
	hold_changed.emit(now)

func _race():
	var sc: = get_tree().current_scene
	if sc and "race" in sc and sc.race and is_instance_valid(sc.race): return sc.race
	return null

func _show(kind: String, done: Callable) -> void :
	_busy = true
	ad_started.emit()
	_mute(true)
	var finish: = func(ok: bool):
		_busy = false
		_mute(false)
		ad_finished.emit()
		done.call(ok)
	match provider:
		"crazygames":
			_js_cb_done = JavaScriptBridge.create_callback( func(args): finish.call(str(args[0]) == "ok"))
			JavaScriptBridge.get_interface("window").set("_ttrAdDone", _js_cb_done)
			JavaScriptBridge.eval("window.CrazyGames.SDK.ad.requestAd('%s', {adFinished: () => window._ttrAdDone('ok'), adError: () => window._ttrAdDone('err')})" % kind, true)
		"gm":
			_gm_show(kind, finish)
		"gd", "gpx":
			_gd_show(kind, finish)
		"admob":

			finish.call(true)
		_:
			_stub_overlay(kind, finish)

var _gm_token: = 0
var _gm_error: = false
var _loading: CanvasLayer



func _gm_show(kind: String, finish: Callable) -> void :
	_gm_finish = finish;_gm_seen_pause = false;_gm_error = false
	var token: = Time.get_ticks_msec();_gm_token = token
	var wait_s: = GM_REWARDED_WAIT if kind == "rewarded" else GM_INTERSTITIAL_WAIT
	var t0: = Time.get_ticks_msec() / 1000.0
	_loading_show( func(): if _gm_token == token: print("[Ads] cancelled by player");_gm_end(false))
	while not sdk_available():
		var failed: = bool(JavaScriptBridge.eval("!!(window.__ttrSdk && window.__ttrSdk.failed)", true))
		if failed or Time.get_ticks_msec() / 1000.0 - t0 > wait_s or _gm_token != token: break
		await get_tree().create_timer(0.25, true, false, true).timeout
	if _gm_token != token: return
	if not sdk_available(): print("[Ads] SDK not available");_gm_end(false);return
	if not bool(JavaScriptBridge.eval("window.__ttrShowAd ? window.__ttrShowAd() : false", true)): _gm_end(false);return
	var left: float = max(3.0, wait_s - (Time.get_ticks_msec() / 1000.0 - t0))
	get_tree().create_timer(left, true, false, true).timeout.connect( func():
		if _gm_token == token and not _gm_seen_pause: print("[Ads] no ad within %.0f s" % wait_s);_gm_end(false))
	get_tree().create_timer(GM_MAX_AD_TIME, true, false, true).timeout.connect( func():
		if _gm_token == token: _gm_resume();_gm_end(true))

var _gd_rewarded: = false
var _gd_kind: = ""



func _gd_show(kind: String, finish: Callable) -> void :
	_gm_finish = finish;_gm_seen_pause = false;_gm_error = false;_gd_rewarded = false;_gd_kind = kind
	var token: = Time.get_ticks_msec();_gm_token = token
	var wait_s: = GM_REWARDED_WAIT if kind == "rewarded" else GD_INTERSTITIAL_WAIT
	var t0: = Time.get_ticks_msec() / 1000.0
	var cancel: = func(): if _gm_token == token: print("[Ads] cancelled by player");JavaScriptBridge.eval("window.__ttrSdk && window.__ttrSdk.cancel && window.__ttrSdk.cancel()", true);_gm_end(false)
	if kind == "rewarded": _loading_show(cancel)
	else: get_tree().create_timer(1.0, true, false, true).timeout.connect( func(): if _gm_token == token and not _gm_seen_pause: _loading_show(cancel))
	while not sdk_available():
		var failed: = bool(JavaScriptBridge.eval("!!(window.__ttrSdk && window.__ttrSdk.failed)", true))
		if failed or Time.get_ticks_msec() / 1000.0 - t0 > wait_s or _gm_token != token: break
		await get_tree().create_timer(0.25, true, false, true).timeout
	if _gm_token != token: return
	if not sdk_available(): print("[Ads] SDK not available");_gm_end(false);return
	if not bool(JavaScriptBridge.eval("window.__ttrShowAd ? window.__ttrShowAd('%s') : false" % ("rewarded" if kind == "rewarded" else "interstitial"), true)): _gm_end(false);return
	var left: float = max(3.0, wait_s - (Time.get_ticks_msec() / 1000.0 - t0))
	get_tree().create_timer(left, true, false, true).timeout.connect( func():
		if _gm_token == token and not _gm_seen_pause: print("[Ads] no ad within %.0f s" % wait_s);JavaScriptBridge.eval("window.__ttrSdk && window.__ttrSdk.cancel && window.__ttrSdk.cancel()", true);_gm_resume();_gm_end(false))
	get_tree().create_timer(GPX_MAX_AD_TIME if provider == "gpx" else GM_MAX_AD_TIME, true, false, true).timeout.connect( func():
		if _gm_token == token: _gm_resume();_gm_end(_gd_ok()))

func _gd_ok() -> bool:
	return _gd_rewarded if _gd_kind == "rewarded" else (_gm_seen_pause and not _gm_error)

func _on_gd_event(ev: String) -> void :
	var token: = _gm_token
	match ev:
		"pause":
			_gm_seen_pause = true;_gm_pause()
			if provider == "gpx":
				if not (_loading and is_instance_valid(_loading)): _loading_show( func(): pass)
				_loading_ad_running()
			else: _loading_hide()
		"reward": _gd_rewarded = true
		"start":
			_gm_resume()

			get_tree().create_timer(2.0, true, false, true).timeout.connect( func(): if _gm_token == token and _gm_finish.is_valid(): _gm_end(_gd_ok()))
		"done": _gm_resume(); if _gm_finish.is_valid(): _gm_end(_gd_ok())
		"skip", "error":
			if ev == "error": _gm_error = true
			_gm_resume()
			if _gm_finish.is_valid(): _gm_end(_gd_ok() if _gd_kind == "rewarded" else false)

func _loading_show(on_cancel: Callable) -> void :
	_loading_hide()
	_loading = CanvasLayer.new();_loading.layer = 99;_loading.process_mode = Node.PROCESS_MODE_ALWAYS;_loading.name = "AdLoading"
	var bg: = ColorRect.new();bg.color = Color(0.02, 0.03, 0.08, 0.72);bg.set_anchors_preset(Control.PRESET_FULL_RECT);bg.theme = UI.make_theme()
	_loading.add_child(bg)
	var p: = UI.panel(); var v: = UI.vbox(14);p.add_child(v)
	var l: = UI.label(tr("Loading ad…"), 30, Color(1, 0.82, 0.3));l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;l.custom_minimum_size.x = 340;v.add_child(l)
	var spin: = Control.new();spin.custom_minimum_size = Vector2(60, 60);spin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	spin.draw.connect( func():
		var a: = Time.get_ticks_msec() / 1000.0 * 5.0
		spin.draw_arc(Vector2(30, 30), 22, a, a + PI * 1.4, 32, Color(1, 0.82, 0.3), 6.0, true)
		spin.queue_redraw())
	v.add_child(spin)
	var c: = UI.button("CANCEL", on_cancel, 20, 180, "grey");c.name = "AdCancel";c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER;v.add_child(c)
	bg.add_child(UI.center(p))
	get_tree().root.add_child(_loading)

func _loading_ad_running() -> void :
	var c: = _loading.find_child("AdCancel", true, false)
	if c: c.visible = false

func _loading_hide() -> void :
	if _loading and is_instance_valid(_loading): _loading.queue_free()
	_loading = null

func _on_gm_event(args) -> void :
	var ev: = str(args[0]) if args.size() > 0 else ""
	if Game.autotest or OS.is_debug_build(): print("[Ads] %s event %s" % [provider, ev])
	if provider == "gd" or provider == "gpx": _on_gd_event(ev);return
	match ev:
		"pause": _gm_seen_pause = true;_loading_hide();_gm_pause()
		"start":
			_gm_resume()
			if _gm_finish.is_valid(): _gm_end(_gm_seen_pause and not _gm_error)
		"error":
			_gm_error = true
			_gm_resume()
			if _gm_finish.is_valid(): _gm_end(false)


func _gm_pause() -> void :
	if _gm_paused_by_ad: return
	_gm_paused_by_ad = true
	_gm_was_paused = get_tree().paused
	get_tree().paused = true
	_mute(true)


func _gm_resume() -> void :
	if not _gm_paused_by_ad: _mute(_busy);return
	_gm_paused_by_ad = false
	get_tree().paused = _gm_was_paused or is_held()
	_mute(false)

func _gm_end(ok: bool) -> void :
	_gm_token = 0
	_loading_hide()
	var f: = _gm_finish;_gm_finish = Callable()
	if f.is_valid(): f.call(ok)

func _stub_overlay(kind: String, finish: Callable) -> void :
	var layer: = CanvasLayer.new();layer.layer = 100
	var bg: = ColorRect.new();bg.color = Color(0, 0, 0, 0.85);bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var l: = Label.new();l.text = "[ AD PLACEHOLDER: %s ]\n(stub provider)" % kind
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT);l.add_theme_font_size_override("font_size", 32)
	bg.add_child(l);layer.add_child(bg);get_tree().root.add_child(layer)
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(1.2, true, false, true).timeout
	layer.queue_free()
	finish.call(true)
