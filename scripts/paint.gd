class_name Paint



const CELLS: = {
	"yellow": [7, 2, 0.5479], "red": [11, 2, 0.26], "purple": [1, 1, 0.1676], "green": [1, 3, 0.2194], "bike": [1, 3, 0.2194], 
}
const NAMES: = ["Factory", "Racing Red", "Ocean Blue", "Lime", "Sunburst", "Snow", "Midnight", "Tangerine", "Bubblegum"]
const COLORS: = [Color(0, 0, 0, 0), Color(0.86, 0.16, 0.14), Color(0.16, 0.45, 0.92), Color(0.45, 0.85, 0.2), Color(1.0, 0.78, 0.1), 
	Color(0.95, 0.95, 0.97), Color(0.13, 0.14, 0.2), Color(1.0, 0.5, 0.12), Color(1.0, 0.45, 0.75)]

static var _shader: Shader
static var _mats: = {}

static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = "\nshader_type spatial;\nuniform sampler2D albedo_tex : source_color, filter_nearest;\nuniform vec4 cell_rect; // uv min.xy, max.xy\nuniform vec4 paint : source_color; // alpha 0 = factory colours\nuniform float ref_lum;\nvoid fragment() {\n\tvec4 t = texture(albedo_tex, UV);\n\tvec3 c = t.rgb;\n\tif (paint.a > 0.5 && UV.x >= cell_rect.x && UV.x < cell_rect.z && UV.y >= cell_rect.y && UV.y < cell_rect.w) {\n\t\tfloat lum = dot(c, vec3(0.2126, 0.7152, 0.0722));\n\t\tc = paint.rgb * clamp(lum / ref_lum, 0.45, 1.6);\n\t}\n\tALBEDO = c;\n\tROUGHNESS = 0.6;\n}\n"
















	return _shader

static func color_of(idx: int) -> Color:
	return COLORS[idx] if idx > 0 and idx < COLORS.size() else Color(0, 0, 0, 0)


static func material_for(car_id: String, body: MeshInstance3D = null) -> ShaderMaterial:
	if _mats.has(car_id): return _mats[car_id]
	var cell: Array = CELLS[car_id]
	var mat: = ShaderMaterial.new()
	mat.shader = shader()
	var base: StandardMaterial3D = body.mesh.surface_get_material(0) if body else null
	mat.set_shader_parameter("albedo_tex", base.albedo_texture if base and base.albedo_texture else load("res://models/Textures/colormap.png"))
	mat.set_shader_parameter("cell_rect", Vector4(cell[0] / 16.0, cell[1] / 4.0, (cell[0] + 1) / 16.0, (cell[1] + 1) / 4.0))
	mat.set_shader_parameter("ref_lum", float(cell[2]))
	mat.set_shader_parameter("paint", Color(0, 0, 0, 0))
	_mats[car_id] = mat
	return mat


static func set_paint(car_id: String, idx: int) -> void :
	if CELLS.has(car_id): material_for(car_id).set_shader_parameter("paint", color_of(idx))

static func current(car_id: String) -> Color:
	return material_for(car_id).get_shader_parameter("paint") if CELLS.has(car_id) else Color(0, 0, 0, 0)



static func apply(model_root: Node, car_id: String, idx: int, shared: = true) -> void :
	if not CELLS.has(car_id): return
	for body in model_root.find_children("body", "MeshInstance3D", true, false):
		var mat: = material_for(car_id, body)
		if not shared: mat = mat.duplicate()
		mat.set_shader_parameter("paint", color_of(idx))
		if body.material_override != mat: body.material_override = mat
