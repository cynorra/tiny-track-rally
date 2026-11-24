class_name UI


static func make_theme() -> Theme:
	var th: = Theme.new()
	th.default_font = Loc.font()
	th.default_font_size = 24
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var tex: Texture2D = load("res://ui/btn_green.png") if state != "disabled" else load("res://ui/btn_grey.png")
		if state == "focus":
			th.set_stylebox(state, "Button", StyleBoxEmpty.new());continue
		var sb: = StyleBoxTexture.new()
		sb.texture = tex
		sb.texture_margin_left = 12;sb.texture_margin_right = 12;sb.texture_margin_top = 12;sb.texture_margin_bottom = 16
		sb.content_margin_left = 18;sb.content_margin_right = 18;sb.content_margin_top = 8;sb.content_margin_bottom = 12
		if state == "hover": sb.modulate_color = Color(1.1, 1.1, 1.1)
		if state == "pressed": sb.modulate_color = Color(0.8, 0.8, 0.8)
		th.set_stylebox(state, "Button", sb)
	th.set_color("font_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(0.35, 0.35, 0.4))
	th.set_constant("outline_size", "Button", 6)
	th.set_color("font_outline_color", "Button", Color(0.1, 0.2, 0.1, 0.8))
	th.set_constant("outline_size", "Label", 8)
	th.set_color("font_outline_color", "Label", Color(0.08, 0.1, 0.18))
	var panel: = StyleBoxFlat.new()
	panel.bg_color = Color(0.08, 0.1, 0.18, 0.82)
	panel.set_corner_radius_all(18)
	panel.content_margin_left = 16;panel.content_margin_right = 16;panel.content_margin_top = 12;panel.content_margin_bottom = 12
	th.set_stylebox("panel", "PanelContainer", panel)
	return th

static func label(text: String, size: = 24, color: = Color.WHITE) -> Label:
	var l: = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func button(text: String, cb: Callable, size: = 26, min_w: = 280, style: = "green") -> Button:
	var b: = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 64)
	b.add_theme_font_size_override("font_size", size)
	if style != "green":
		var sb: = StyleBoxTexture.new()
		sb.texture = load("res://ui/btn_%s.png" % style)
		sb.texture_margin_left = 12;sb.texture_margin_right = 12;sb.texture_margin_top = 12;sb.texture_margin_bottom = 16
		sb.content_margin_left = 18;sb.content_margin_right = 18;sb.content_margin_top = 8;sb.content_margin_bottom = 12
		b.add_theme_stylebox_override("normal", sb)
		var sh: StyleBoxTexture = sb.duplicate();sh.modulate_color = Color(1.1, 1.1, 1.1)
		b.add_theme_stylebox_override("hover", sh)
		if style == "grey": b.add_theme_color_override("font_color", Color(0.15, 0.17, 0.25));b.add_theme_constant_override("outline_size", 0)
	b.pressed.connect( func(): Sound.play("click");cb.call())
	return b



static func recalibrate_button(size: = 22) -> Button:
	var b: = UI.button("RECALIBRATE TILT", func(): pass, size, 300, "grey");b.name = "RecalibrateTilt"
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = "Hold the device the way you play, then tap."
	b.pressed.connect( func():
		TouchControls.tilt_recalibrate()
		b.text = "TILT CENTRED"
		b.get_tree().create_timer(1.5).timeout.connect( func(): if is_instance_valid(b): b.text = "RECALIBRATE TILT"))
	return b


static func fit_font(l: Label, width: float, size: int, min_size: = 12) -> void :
	var f: Font = l.get_theme_font("font")
	if f == null: return
	var s: = size
	while s > min_size and f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width: s -= 1
	l.add_theme_font_size_override("font_size", s)


static func red_button(text: String, cb: Callable, size: = 24, min_w: = 240) -> Button:
	var b: = button(text, cb, size, min_w)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb: = StyleBoxFlat.new();sb.set_corner_radius_all(12)
		sb.bg_color = {"normal": Color(0.78, 0.16, 0.14), "hover": Color(0.88, 0.22, 0.18), "pressed": Color(0.6, 0.1, 0.1), "focus": Color(0.88, 0.22, 0.18)}[st]
		sb.border_width_bottom = 5;sb.border_color = Color(0.45, 0.06, 0.06)
		if st == "focus": sb.border_width_left = 3;sb.border_width_right = 3;sb.border_width_top = 3;sb.border_color = Color(1, 1, 1, 0.85)
		sb.content_margin_left = 18;sb.content_margin_right = 18;sb.content_margin_top = 8;sb.content_margin_bottom = 12
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color(1, 1, 1));b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	return b

static func panel() -> PanelContainer:
	return PanelContainer.new()

static func vbox(sep: = 12) -> VBoxContainer:
	var v: = VBoxContainer.new();v.add_theme_constant_override("separation", sep);return v

static func hbox(sep: = 12) -> HBoxContainer:
	var h: = HBoxContainer.new();h.add_theme_constant_override("separation", sep);return h

static func center(child: Control) -> CenterContainer:
	var c: = CenterContainer.new();c.set_anchors_preset(Control.PRESET_FULL_RECT);c.add_child(child);return c
