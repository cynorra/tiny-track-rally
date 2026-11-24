class_name FX


static var _spark_mesh: SphereMesh

static func sparks(parent: Node3D, pos: Vector3, normal: Vector3, quality: int) -> void :
	if quality == 0: return
	var p: = CPUParticles3D.new()
	p.one_shot = true;p.emitting = false;p.amount = 18 if quality == 1 else 30;p.lifetime = 0.45;p.explosiveness = 0.95
	p.direction = (normal + Vector3.UP * 0.6).normalized();p.spread = 50.0
	p.initial_velocity_min = 4.0;p.initial_velocity_max = 9.0;p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.05;p.scale_amount_max = 0.1
	if _spark_mesh == null:
		var m: = SphereMesh.new();m.radius = 0.5;m.height = 1.0;m.radial_segments = 4;m.rings = 2
		var mat: = StandardMaterial3D.new();mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color = Color(1, 0.75, 0.2)
		mat.emission_enabled = true;mat.emission = Color(1, 0.6, 0.1);mat.emission_energy_multiplier = 3.0
		m.material = mat;_spark_mesh = m
	p.mesh = _spark_mesh
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

static func confetti(layer: CanvasLayer, size: Vector2, quality: int) -> void :
	for side in [0.0, 1.0]:
		var c: = CPUParticles2D.new()
		c.one_shot = true;c.amount = 60 if quality == 0 else 140;c.lifetime = 3.0;c.explosiveness = 0.9
		c.position = Vector2(size.x * (0.1 + 0.8 * side), size.y + 10)
		c.direction = Vector2(0.45 if side == 0.0 else -0.45, -1);c.spread = 22.0
		c.initial_velocity_min = size.y * 0.9;c.initial_velocity_max = size.y * 1.35
		c.gravity = Vector2(0, 520);c.angular_velocity_min = -360;c.angular_velocity_max = 360
		c.scale_amount_min = 6.0;c.scale_amount_max = 11.0
		var g: = Gradient.new()
		g.colors = PackedColorArray([Color(1, 0.3, 0.3), Color(1, 0.85, 0.2), Color(0.3, 0.85, 0.4), Color(0.3, 0.6, 1), Color(0.9, 0.4, 0.9)])
		g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		c.color_initial_ramp = g
		layer.add_child(c)
		c.emitting = true
		c.finished.connect(c.queue_free)
