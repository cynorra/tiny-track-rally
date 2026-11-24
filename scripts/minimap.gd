class_name Minimap extends Control


var race
var dots: Control
var _lo: = Vector2.ZERO; var _sc: = 1.0; var _off: = Vector2.ZERO

func _ready() -> void :
	dots = Control.new();dots.name = "Dots";dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(dots)
	dots.draw.connect(_draw_dots)
	resized.connect(queue_redraw)

func queue_dots() -> void :
	if dots: dots.queue_redraw()

func _map(p: Vector3) -> Vector2: return _off + (Vector2(p.x, p.z) - _lo) * _sc

func _draw() -> void :
	if race == null or race.points.is_empty(): return
	var pts: Array = race.points
	var lo: = Vector2(1000000000.0, 1000000000.0); var hi: = Vector2(-1000000000.0, -1000000000.0)
	for p in pts:
		lo = Vector2(min(lo.x, p.x), min(lo.y, p.z));hi = Vector2(max(hi.x, p.x), max(hi.y, p.z))
	var pad: = 14.0
	_sc = min((size.x - pad * 2) / max(hi.x - lo.x, 1.0), (size.y - pad * 2) / max(hi.y - lo.y, 1.0))
	_off = (size - (hi - lo) * _sc) / 2;_lo = lo
	var line: = PackedVector2Array()
	for p in pts: line.append(_map(p))
	line.append(line[0])
	draw_polyline(line, Color(0.95, 0.95, 1.0, 0.25), 14.0, true)
	draw_polyline(line, Color(0.2, 0.22, 0.3), 9.0, true)
	draw_circle(line[0], 5, Color(1, 1, 1))
	queue_dots()

const COLORS: = [Color(1, 0.3, 0.25), Color(0.65, 0.4, 0.9), Color(0.3, 0.8, 0.4), Color(1, 0.8, 0.2), Color(0.4, 0.7, 1)]
func _draw_dots() -> void :
	if race == null or race.points.is_empty(): return
	var i: = 0
	for r in race.racers:
		var c: Color = Color(1, 0.85, 0.2) if r["player"] else COLORS[i % COLORS.size()]
		var m: = _map(r["v"].get_vehicle_position())
		dots.draw_circle(m, 8 if r["player"] else 6, Color.WHITE)
		dots.draw_circle(m, 6 if r["player"] else 4, c)
		i += 1
	if race.ghost_node:
		dots.draw_circle(_map(race.ghost_node.global_position), 5, Color(0.6, 0.85, 1, 0.7))
