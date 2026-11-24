class_name SkidMarks extends MultiMeshInstance3D


const MAX: = 1600
var next: = 0
var last: = {}



static var _mm: MultiMesh

func _ready() -> void :
	if _mm == null:
		_mm = MultiMesh.new();_mm.transform_format = MultiMesh.TRANSFORM_3D;_mm.use_colors = false
		var q: = QuadMesh.new();q.size = Vector2(0.16, 0.5);q.orientation = PlaneMesh.FACE_Y
		var mat: = StandardMaterial3D.new();mat.albedo_color = Color(0.05, 0.05, 0.06, 0.55);mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		q.material = mat
		_mm.mesh = q;_mm.instance_count = MAX
		_mm.set_instance_transform(0, Transform3D())
	_mm.visible_instance_count = 0
	multimesh = _mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func mark(v: Vehicle, on: bool) -> void :
	var id: = v.get_instance_id()
	if not on or not v.raycast.is_colliding():
		last.erase(id);return
	var b: Basis = v.vehicle_model.global_basis
	var o: Vector3 = v.vehicle_model.global_position
	var pts: = [o + b.x * 0.27 - b.z * 0.33, o - b.x * 0.27 - b.z * 0.33]
	if not last.has(id): last[id] = pts;return
	for k in 2:
		var a: Vector3 = last[id][k]; var c: Vector3 = pts[k]
		var seg: = c - a;seg.y = 0
		var l: = seg.length()
		if l < 0.25: continue
		var mid: = (a + c) * 0.5;mid.y = 0.02
		var fwd: = seg / l
		var basis: = Basis(fwd.cross(Vector3.UP), Vector3.UP, - fwd * (l / 0.5))
		multimesh.set_instance_transform(next, Transform3D(basis, mid))
		next = (next + 1) % MAX
		multimesh.visible_instance_count = MAX if next == 0 else max(multimesh.visible_instance_count, next)
		last[id][k] = c
