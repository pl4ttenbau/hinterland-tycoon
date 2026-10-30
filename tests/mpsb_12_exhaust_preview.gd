extends Node3D
## F6 preview of the production locomotive and its real exhaust/motor integration.
## Space toggles motion. Escape closes the preview. No world or save is loaded.

var _train: Train3D
var _locomotive: Vehicle3D
var _exhaust: Node3D
var _camera: Camera3D
var _frame: int = 0
var _moving: bool = false
var _capture: bool = false


func _ready() -> void:
	_capture = "--capture" in OS.get_cmdline_user_args()
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.78, 0.85)
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	ground.mesh = plane
	ground.position.y = -0.04
	var ground_material: StandardMaterial3D = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.12, 0.15, 0.14)
	ground.material_override = ground_material
	add_child(ground)
	_train = load(Train3D.EMPTY_SCENE_PATH).instantiate() as Train3D
	_train._create_motor(Enums.PathDirection.TRACK_NODES_INCREASE)
	_locomotive = load("res://assets/meshes/vehicles/rail/mpsb_12/model_mpsb_12.tscn").instantiate() as Vehicle3D
	_locomotive.vehicle_obj = VehicleData.new()
	_locomotive.train3d = _train
	_train.add_vehicle(_locomotive, true)
	add_child(_train)
	_train.set_physics_process(false)
	# Freeze the speed ramp; this preview moves the vehicle directly at 4 m/s.
	for child: Node in _train.get_children():
		if child is Timer:
			child.stop()
	_train.motor.start()
	_train.motor.speed.current = 0.6
	_train.motor.speed.target = 0.6
	_exhaust = _locomotive.get_node("Steam/ChimneyExhaust") as Node3D
	_exhaust.chuff_rate_hz = 1.4
	_camera = Camera3D.new()
	_camera.fov = 47.0
	_camera.near = 0.1
	_camera.far = 300.0
	add_child(_camera)
	_camera.make_current()
	_update_camera()
	print("MPSB 12 production-model preview; renderer: ", RenderingServer.get_current_rendering_method())


func _physics_process(delta: float) -> void:
	if _moving:
		_locomotive.position.z -= 4.0 * delta


func _process(_delta: float) -> void:
	_frame += 1
	_update_camera()
	if _capture:
		if _frame == 220:
			_save_frame("mpsb12_stationary.png")
		if _frame == 260:
			_moving = true
			_exhaust.chuff_rate_hz = 0.0
		if _frame == 520:
			_save_frame("mpsb12_moving.png")
		if _frame == 525:
			get_tree().quit()


func _update_camera() -> void:
	var center: Vector3 = _locomotive.global_position
	var focus: Vector3 = center + Vector3(0.8, 4.0, 1.0 if _moving else -0.8)
	_camera.position = focus + Vector3(13.5, 2.8, -13.5)
	_camera.look_at(focus)


func _save_frame(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var directory: String = OS.get_environment("MPSB_STEAM_CAPTURE_DIR")
	if directory.is_empty():
		directory = "user://mpsb12_steam_previews"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var output: String = directory.path_join(filename)
	var status: Error = get_viewport().get_texture().get_image().save_png(output)
	print("MPSB 12 capture ", filename, ": ", error_string(status))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_moving = not _moving
			_exhaust.chuff_rate_hz = 0.0 if _moving else 1.4
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()
