extends Node



const LANG_NAMES: = {"en": "English", "es": "Español", "pt_BR": "Português (BR)", "fr": "Français", "de": "Deutsch", 
	"ru": "Русский", "tr": "Türkçe", "hi": "हिन्दी"}
var lang: = "en"
var _fonts: = {}

func _ready() -> void :
	for i in Strings.LANGS.size():
		var t: = Translation.new();t.locale = Strings.LANGS[i]
		for k in Strings.T.keys(): t.add_message(k, Strings.T[k][i])
		TranslationServer.add_translation(t)
	apply()

func detect() -> String:
	var l: = OS.get_locale()
	if OS.has_feature("web"):
		var pl: = str(JavaScriptBridge.eval("(window.__ttrSdk && window.__ttrSdk.lang) || ''", true))
		if pl != "" and pl != "null": l = pl
	l = l.replace("-", "_")
	if l.begins_with("pt"): return "pt_BR"
	var base: = l.split("_")[0]
	return base if LANG_NAMES.has(base) else "en"



func english_only() -> bool: return OS.has_feature("crazygames")

func apply() -> void :
	var s: String = String(Game.data["settings"].get("lang", "auto")) if Game.data.has("settings") else "auto"
	lang = detect() if s == "auto" or not LANG_NAMES.has(s) else s
	if english_only(): lang = "en"
	TranslationServer.set_locale(lang)

func _load(path: String) -> FontFile:
	if not _fonts.has(path): _fonts[path] = load(path)
	return _fonts[path]



func font() -> Font:
	var pixel: = _load("res://ui/font.ttf"); var rubik: = _load("res://ui/fonts/Rubik.ttf")
	var deva: = _load("res://ui/fonts/NotoSansDevanagari.ttf"); var sym: = _load("res://ui/fonts/Symbols.ttf")
	var key: = lang
	if _fonts.has("v_" + key): return _fonts["v_" + key]
	var primary: FontFile
	var fb: Array[Font] = []
	match lang:
		"ru", "tr":
			primary = rubik.duplicate();fb = [deva, sym]
		"hi":
			primary = deva.duplicate();fb = [rubik, sym]
		_:
			primary = pixel.duplicate();fb = [rubik, deva, sym]
	primary.fallbacks = fb
	var fv: = FontVariation.new();fv.base_font = primary
	if lang in ["ru", "tr", "hi"]: fv.variation_embolden = 0.6
	_fonts["v_" + key] = fv
	return fv
