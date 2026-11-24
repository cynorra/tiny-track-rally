class_name Vehicle extends Node3D



@onready var sphere: RigidBody3D = $Sphere
@onready var raycast: RayCast3D = $Ground



@onready var vehicle_model = $Container
@onready var vehicle_body = get_node_or_null("Container/Model/body")



@onready var wheel_fl = get_node_or_null("Container/Model/wheel-front-left")
@onready var wheel_fr = get_node_or_null("Container/Model/wheel-front-right")
@onready var wheel_bl = get_node_or_null("Container/Model/wheel-back-left")
@onready var wheel_br = get_node_or_null("Container/Model/wheel-back-right")



@onready var trail_left = get_node_or_null("Container/TrailLeft")
@onready var trail_right = get_node_or_null("Container/TrailRight")



@onready var screech_sound: AudioStreamPlayer3D = $Container / ScreechSound
@onready var engine_sound: AudioStreamPlayer3D = $Container / EngineSound
@onready var impact_sound: AudioStreamPlayer3D = $Container / ImpactSound

var input: Vector3
var normal: Vector3

var acceleration: float
var angular_speed: float
var linear_speed: float

var colliding: bool

var linear_velocity: Vector3
var prev_position: Vector3

var calculated_lean: float


var enabled: = false
var ai = null
var stats: = {"speed": 1.0, "accel": 1.0, "handling": 1.0, "drift": 1.0}
var boost: = 1.0
var nitro_active: = false
var drift_intensity: = 0.0
var volume_offset: = 0.0
var touch_input: = Vector2.ZERO



var assist: = false
var steer_sens: = 1.0
const STEER_RAMP_IN: = 0.2
const STEER_RAMP_OUT: = 0.1




const STEER_RAMP_IN_TOUCH: = 0.28
const STEER_AT_SPEED: = 0.72
const STRAIGHTEN: = 9.0
const GRIP: = 5.0
const GRIP_DRIFT: = 2.5
static var _nogrip: = OS.get_environment("TTR_NOGRIP") == "1"
var steer_out: = 0.0
var smoke_t: = 0.0
var tilt_steer: = false



const TILT_AT_SPEED: = 0.66
var nitro_held: = false
var drift_gate: = 1.0


var model_drop: = 0.5
func _ready() -> void :
	var cs: CollisionShape3D = sphere.get_node_or_null("CollisionShape")
	if cs and cs.shape is SphereShape3D: model_drop = (cs.shape as SphereShape3D).radius

func forward() -> Vector3:
	return vehicle_model.global_basis.z

func speed_mps() -> float:
	return Vector2(linear_velocity.x, linear_velocity.z).length()

func place(pos: Vector3, dir: Vector3) -> void :
	sphere.global_position = pos + Vector3(0, 0.6, 0)
	sphere.linear_velocity = Vector3.ZERO
	sphere.angular_velocity = Vector3.ZERO
	linear_speed = 0.0;acceleration = 0.0;angular_speed = 0.0
	vehicle_model.global_basis = Basis(Vector3.UP, atan2(dir.x, dir.z))
	vehicle_model.position = sphere.position - Vector3(0, model_drop, 0)
	prev_position = vehicle_model.position
	reset_physics_interpolation()



func get_vehicle_position() -> Vector3: return vehicle_model.global_position



func _physics_process(delta):



	if assist and ai == null and raycast.target_position.y > -0.9: raycast.target_position.y = -0.95
	handle_input(delta)

	var direction = sign(linear_speed)
	if direction == 0: direction = sign(input.z) if abs(input.z) > 0.1 else 1

	var steering_grip = clamp(abs(linear_speed), 0.2, 1.0)

	var steer_x: float = steer_out if (assist and ai == null) else input.x
	var target_angular = - steer_x * steering_grip * 4 * direction * float(stats["handling"])
	var yaw_k: = 4.0
	if assist and ai == null and absf(steer_x) < 0.05: yaw_k = STRAIGHTEN
	angular_speed = lerp(angular_speed, target_angular, delta * yaw_k)

	vehicle_model.rotate_y(angular_speed * delta)
	if assist and ai == null and raycast.is_colliding() and not _nogrip: _grip(delta)



	if raycast.is_colliding():
		if !colliding:
			if vehicle_body != null: vehicle_body.position = Vector3(0, 0.1, 0)
			if not (assist and ai == null): input.z = 0

		normal = raycast.get_collision_normal()



		if normal.dot(vehicle_model.global_basis.y) > 0.5:
			var xform = align_with_y(vehicle_model.global_transform, normal)
			vehicle_model.global_transform = vehicle_model.global_transform.interpolate_with(xform, 0.2).orthonormalized()

	colliding = raycast.is_colliding()

	var target_speed = input.z
	var accel_k = float(stats["accel"])

	if (target_speed < 0 and linear_speed > 0.01):
		linear_speed = lerp(linear_speed, 0.0, delta * 8)
	else:
		if (target_speed < 0):
			linear_speed = lerp(linear_speed, target_speed / 2, delta * 2)
		else:
			linear_speed = lerp(linear_speed, target_speed, delta * 6 * accel_k)

	acceleration = lerpf(acceleration, linear_speed + (abs(sphere.angular_velocity.length() * linear_speed) / 100), delta * 1)



	vehicle_model.position = sphere.position - Vector3(0, model_drop, 0)
	raycast.position = sphere.position



	linear_velocity = (vehicle_model.position - prev_position) / delta
	prev_position = vehicle_model.position



	effect_engine(delta)
	effect_body(delta)
	effect_wheels(delta)
	effect_trails()



func handle_input(delta):

	if raycast.is_colliding():
		if not enabled:
			input.x = 0.0;input.z = 0.0
		elif ai != null:
			var v: Vector2 = ai.get_drive_input(self)
			input.x = v.x;input.z = v.y
		else:
			input.x = clamp(Input.get_axis("left", "right") + touch_input.x, -1.0, 1.0)
			input.z = clamp(Input.get_axis("back", "forward") + touch_input.y, -1.0, 1.0)
			if nitro_held and input.z > -0.1: input.z = 1.0
	elif enabled and ai == null and assist:

		input.x = clamp(Input.get_axis("left", "right") + touch_input.x, -1.0, 1.0)
	if assist and ai == null: _assist(delta)

	var power = 100.0 * float(stats["speed"]) * boost
	sphere.angular_velocity += vehicle_model.get_global_transform().basis.x * (linear_speed * power) * delta




func _grip(delta: float) -> void :
	var lv: Vector3 = sphere.linear_velocity
	var hv: = Vector2(lv.x, lv.z)
	if hv.length() < 2.0: return
	var nose: Vector3 = vehicle_model.global_basis.z
	var fwd: = Vector2(nose.x, nose.z)
	if fwd.length() < 0.1: return
	fwd = fwd.normalized()
	if hv.dot(fwd) < 0.0: fwd = - fwd
	var ang: = hv.angle_to(fwd)
	var turn: = ang * (1.0 - exp( - lerpf(GRIP, GRIP_DRIFT, drift_gate) * delta))
	var rot: = Basis(Vector3.UP, - turn)
	sphere.linear_velocity = rot * lv
	sphere.angular_velocity = rot * sphere.angular_velocity

func _assist(delta: float) -> void :
	var want: = clampf(input.x, -1.0, 1.0)

	var back: = absf(want) < absf(steer_out) - 0.001 or signf(want) != signf(steer_out)
	var touch_arrows: = touch_input.x != 0.0 and not tilt_steer and Input.get_axis("left", "right") == 0.0
	var rate: = (1.0 / STEER_RAMP_OUT) if back else (1.0 / (STEER_RAMP_IN_TOUCH if touch_arrows else STEER_RAMP_IN))
	var target: = want
	var spd: = clampf((absf(linear_speed) - 0.3) / 0.7, 0.0, 1.0)
	target *= lerpf(1.0, STEER_AT_SPEED, spd) * clampf(steer_sens, 0.5, 1.5)
	if tilt_steer and Input.get_axis("left", "right") == 0.0: target *= lerpf(1.0, TILT_AT_SPEED, spd)
	target = clampf(target, -1.0, 1.0)
	steer_out = move_toward(steer_out, target, rate * delta)

	var held: = absf(want)
	if touch_arrows: held *= clampf(absf(steer_out) / maxf(absf(target), 0.01), 0.0, 1.0)
	var hard: = clampf((held - 0.75) / 0.2, 0.0, 1.0) * clampf((absf(linear_speed) - 0.55) / 0.2, 0.0, 1.0)
	var braking: = 1.0 if (input.z < -0.1 and absf(want) > 0.4 and absf(linear_speed) > 0.3) else 0.0
	drift_gate = lerpf(drift_gate, maxf(hard, braking), clampf(delta * 6.0, 0.0, 1.0))

func effect_body(delta):

	var lean_x: float = steer_out if (assist and ai == null) else input.x
	calculated_lean = lerp_angle(calculated_lean, - lean_x / 5 * linear_speed, delta * 5)



	if vehicle_body != null:

		vehicle_body.rotation.x = lerp_angle(vehicle_body.rotation.x, - (linear_speed - acceleration) / 6, delta * 10)
		vehicle_body.rotation.z = calculated_lean

		vehicle_body.position = vehicle_body.position.lerp(Vector3(0, 0.2, 0), delta * 5)

func effect_wheels(delta):



	for wheel in [wheel_fl, wheel_fr, wheel_bl, wheel_br]:
		if wheel != null:
			wheel.rotation.x += acceleration



	var wx: float = steer_out if (assist and ai == null) else input.x
	if wheel_fl != null: wheel_fl.rotation.y = lerp_angle(wheel_fl.rotation.y, - wx / 1.5, delta * 10)
	if wheel_fr != null: wheel_fr.rotation.y = lerp_angle(wheel_fr.rotation.y, - wx / 1.5, delta * 10)



func effect_engine(delta):

	var speed_factor = clamp(abs(linear_speed), 0.0, 1.0)
	var throttle_factor = clamp(abs(input.z), 0.0, 1.0)

	var target_volume = remap(speed_factor + (throttle_factor * 0.5), 0.0, 1.5, -15.0, -5.0)
	engine_sound.volume_db = lerp(engine_sound.volume_db, target_volume + volume_offset, delta * 5.0)

	var target_pitch = remap(speed_factor, 0.0, 1.0, 0.5, 3) + (0.4 if nitro_active else 0.0)
	if throttle_factor > 0.1: target_pitch += 0.2

	engine_sound.pitch_scale = lerp(engine_sound.pitch_scale, target_pitch, delta * 2.0)



func effect_trails():

	var gate: float = drift_gate if (assist and ai == null) else 1.0
	drift_intensity = (abs(linear_speed - acceleration) + (abs(calculated_lean) * 2.0) * gate) * float(stats["drift"])
	var should_emit = drift_intensity > 0.25 or nitro_active or smoke_t > 0.0
	smoke_t = maxf(0.0, smoke_t - get_physics_process_delta_time())

	if trail_left != null: trail_left.emitting = should_emit
	if trail_right != null: trail_right.emitting = should_emit

	var target_volume = -80.0
	if should_emit: target_volume = remap(clamp(drift_intensity, 0.25, 2.0), 0.25, 2.0, -10.0, 0.0)

	screech_sound.pitch_scale = lerp(screech_sound.pitch_scale, clamp(abs(linear_speed), 1.0, 3.0), 0.1)
	screech_sound.volume_db = lerp(screech_sound.volume_db, target_volume + volume_offset, 10.0 * get_physics_process_delta_time())



func align_with_y(xform, new_y):

	xform.basis.y = new_y
	xform.basis.x = - xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform



func _on_sphere_body_entered(_body: Node) -> void :

	if vehicle_body == null: return

	if not impact_sound.playing:
		var impact_velocity: = absf(linear_velocity.dot(vehicle_body.global_basis.z))
		impact_sound.volume_db = clampf(remap(impact_velocity, 0.0, 6.0, -20.0, 0.0), -20.0, 0.0)
		impact_sound.play()
