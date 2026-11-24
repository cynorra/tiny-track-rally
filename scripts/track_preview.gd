class_name TrackPreview extends Control
var def: Dictionary
func _draw() -> void :
	var cells: = TrackBuilder.path_cells(def)
	var lo: = Vector2(1000000000.0, 1000000000.0); var hi: = Vector2(-1000000000.0, -1000000000.0)
	for c in cells: lo = Vector2(min(lo.x, c.x), min(lo.y, c.y));hi = Vector2(max(hi.x, c.x), max(hi.y, c.y))
	var sc: float = min((size.x - 30) / max(hi.x - lo.x, 1), (size.y - 30) / max(hi.y - lo.y, 1))
	var off: = (size - (hi - lo) * sc) / 2
	var pts: = PackedVector2Array()
	for c in cells: pts.append(off + (Vector2(c) - lo) * sc)
	pts.append(pts[0])
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.18, 0.45, 0.3), true)
	draw_polyline(pts, Color(0.85, 0.85, 0.95), 16, true)
	draw_polyline(pts, Color(0.2, 0.2, 0.25), 11, true)
	draw_circle(pts[0], 6, Color(1, 0.4, 0.3))
