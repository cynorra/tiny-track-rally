extends Node3D

@export_group("Properties")
@export var target: Vehicle

@onready var camera = $Camera



func _physics_process(delta):



	self.position = self.position.lerp(target.get_vehicle_position(), delta * 4)



	var speed_factor = clamp(abs(target.linear_speed), 0.0, 1.0)
	var target_z = remap(speed_factor, 0.0, 1.0, 10, 20)

	camera.position.z = lerp(camera.position.z, target_z, delta * 0.5)
