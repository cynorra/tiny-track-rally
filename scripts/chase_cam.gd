class_name ChaseCam extends Camera3D


var target: Vehicle
var mode: = 0
var heading: = Vector3.FORWARD
var smoothed_pos: = Vector3.ZERO
var look_point: = Vector3.ZERO
var _init_done: = false

const MODES: = [
	{"dist": 7.5, "height": 3.6, "ahead": 7.0, "fov": 62.0, "fov_add": 12.0, "pos_k": 6.0, "rot_k": 3.5}, 
	{"dist": 11.5, "height": 5.8, "ahead": 10.0, "fov": 58.0, "fov_add": 10.0, "pos_k": 5.0, "rot_k": 3.0}, 
	{"dist": 4.0, "height": 26.0, "ahead": 9.0, "fov": 50.0, "fov_add": 6.0, "pos_k": 5.0, "rot_k": 2.0}, 
	{"hood": true, "fov": 72.0, "fov_add": 14.0}, 
	{"dist": 15.0, "height": 11.0, "ahead": 12.0, "fov": 55.0, "fov_add": 8.0, "pos_k": 2.2, "rot_k": 1.4}, 
	{"iso": true, "fov": 38.0, "fov_add": 0.0}, 
]

const ORDER: = [1, 0, 3, 2, 4, 5]
const NAMES: = ["CAM_CLOSE", "CAM_FAR", "CAM_TOP", "CAM_HOOD", "CAM_DRONE", "CAM_ISO"]
const EN_NAMES: = ["CHASE CLOSE", "CHASE FAR", "TOP-DOWN", "HOOD", "DRONE", "ISOMETRIC"]


static func display_name(m: int) -> String:
	m = clampi(m, 0, NAMES.size() - 1)
	var t: = TranslationServer.translate(NAMES[m])
	return t if t != NAMES[m] else String(EN_NAMES[m])
var shake: = 0.0
func add_shake(a: float) -> void : shake = min(1.0, shake + a)

func _ready() -> void :
	far = Game.draw_distance(Game.quality_level())
	near = 0.2
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_mode = Node.PROCESS_MODE_ALWAYS



static func _k(rate: float, delta: float) -> float:
	return 1.0 - exp( - rate * delta)

func snap() -> void :
	_init_done = false

func _process(delta: float) -> void :

	if target == null: return
	var m: Dictionary = MODES[mode]
	var car: Vector3 = target.vehicle_model.get_global_transform_interpolated().origin

	var fwd: Vector3 = target.vehicle_model.get_global_transform_interpolated().basis.z;fwd.y = 0
	var vel: Vector3 = target.linear_velocity;vel.y = 0
	var want: Vector3 = fwd.normalized()
	if vel.length() > 3.0 and vel.normalized().dot(want) > 0.0: want = (want + vel.normalized()).normalized()
	if not _init_done:
		heading = want;smoothed_pos = car;look_point = car;_init_done = true
	shake = max(0.0, shake - delta * 2.5)
	var jitter: = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * shake * 0.35 if Game.data["settings"].get("shake", true) else Vector3.ZERO
	if m.get("hood", false):

		var bx: Basis = target.vehicle_model.get_global_transform_interpolated().basis
		var fz: Vector3 = bx.z; var bike: bool = target.get("motorcycle") != null; var hood_h: = 0.62 if bike else 0.62
		global_position = car + bx.y * hood_h + fz * (0.2 if bike else 1.15) + jitter
		look_at(global_position + fz * 10.0 - bx.y * 0.6, Vector3.UP)
		fov = lerp(fov, float(m["fov"]) + float(m["fov_add"]) * clamp(target.speed_mps() / 16.0, 0.0, 1.0), _k(3.0, delta))
		heading = want;smoothed_pos = car
		return
	if m.get("iso", false):

		smoothed_pos = smoothed_pos.lerp(car, _k(5.0, delta))
		global_position = smoothed_pos + Vector3(16, 19, 16) + jitter
		look_at(smoothed_pos + heading * 2.0, Vector3.UP)
		heading = heading.slerp(want, _k(1.0, delta)).normalized() if heading.dot(want) > -0.99 else want
		fov = float(m["fov"])
		return
	heading = heading.slerp(want, _k(m["rot_k"], delta)).normalized() if heading.dot(want) > -0.99 else want
	smoothed_pos = smoothed_pos.lerp(car, _k(m["pos_k"] * 2.0, delta))
	var speed_k: float = clamp(target.speed_mps() / 16.0, 0.0, 1.0)
	var dist: float = m["dist"] * (1.0 + speed_k * 0.15)
	var cam_target_pos: Vector3 = smoothed_pos - heading * dist + Vector3.UP * m["height"]
	global_position = global_position.lerp(cam_target_pos, _k(m["pos_k"], delta)) if _init_done and global_position != Vector3.ZERO else cam_target_pos
	var ahead: Vector3 = smoothed_pos + heading * (m["ahead"] * (0.5 + speed_k))
	look_point = look_point.lerp(ahead, _k(8.0, delta))
	global_position += jitter
	if global_position.distance_to(look_point) > 0.1:
		look_at(look_point, Vector3.UP)
	fov = lerp(fov, float(m["fov"]) + float(m["fov_add"]) * speed_k + (6.0 if target.nitro_active else 0.0), _k(3.0, delta))
