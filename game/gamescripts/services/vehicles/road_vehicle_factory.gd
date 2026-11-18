## Assemble a catalog vehicle before its caller places it in the scene tree.
class_name RoadVehicleFactory extends RefCounted

const DEFAULT_WIDTH_AND_HEIGHT: float = 1.8
const DEFAULT_WHEELBASE_RATIO: float = 0.6
const WHEEL_MOUNT_HEIGHT: float = 0.1
const SUSPENSION_REST_LENGTH: float = 0.18
const VEHICLE_RENDER_LAYERS: int = 64

static func create(type_key: String) -> RoadVehicle3D:
	if GameTypes.ensure_initialized() != OK:
		return null
	var type := GameTypes.get_veh_type(type_key) as RoadVehicleTypeData
	if type == null:
		push_warning("Cannot spawn road vehicle type: %s" % type_key)
		return null
	var model: Node3D = _load_model(type)
	if model == null:
		return null
	var authored := model as RoadVehicleModel3D
	var error: String = _validate_model(authored, type)
	if not error.is_empty():
		model.free()
		push_warning("Cannot spawn %s: %s" % [type.key, error])
		return null

	var body := RoadVehicle3D.new()
	_configure_body(body, type)
	if authored != null:
		_mount_authored_model(body, authored)
	else:
		_mount_legacy_model(body, model, type)
	_prepare_model_visuals(model)
	body.add_child(model)
	_add_camera(body, body.dimensions_metres.z, body.dimensions_metres.y)
	_add_inventory(body, type)
	return body

static func _validate_model(model: RoadVehicleModel3D, type: RoadVehicleTypeData) -> String:
	if model != null:
		return model.configuration_error()
	if type.length_metres <= 0.0:
		return "Use a RoadVehicleModel3D scene with a chassis and axles."
	return ""

## Move the authored collider under the physics body. The model and its axle
## hubs use ground level as Y=0, while the physics origin stays above the road.
static func _mount_authored_model(body: RoadVehicle3D, model: RoadVehicleModel3D) -> void:
	var axles: Array[RoadVehicleAxle3D] = model.get_axles()
	var rear: RoadVehicleAxle3D = axles.front()
	var front: RoadVehicleAxle3D = axles.back()
	body.dimensions_metres = model.get_dimensions()
	body.wheelbase = front.position.z - rear.position.z
	var ride_height: float = rear.position.y + SUSPENSION_REST_LENGTH - WHEEL_MOUNT_HEIGHT

	var chassis: CollisionShape3D = model.chassis
	var chassis_pose: Transform3D = model.get_chassis_transform()
	chassis.owner = null
	chassis.get_parent().remove_child(chassis)
	chassis_pose.origin.y -= ride_height
	chassis.transform = chassis_pose
	body.add_child(chassis)

	var mount_offset := Vector3.UP * (SUSPENSION_REST_LENGTH - ride_height)
	for index: int in range(axles.size()):
		var axle: RoadVehicleAxle3D = axles[index]
		var name_prefix: String = "Axle%d" % (index + 1)
		if axle == front:
			name_prefix = "Front"
		elif axle == rear:
			name_prefix = "Rear"
		_add_wheel_pair(body, axle.position + mount_offset, axle.wheel_centres(), axle.wheel_radius,
			name_prefix, axle == front, axle == rear)
	model.position.y = -ride_height

## Compatibility for older catalogs that supply dimensions alongside plain scenes.
static func _mount_legacy_model(body: RoadVehicle3D, model: Node3D, type: RoadVehicleTypeData) -> void:
	var width: float = float(type.width_metres) if type.width_metres != null else DEFAULT_WIDTH_AND_HEIGHT
	var height: float = float(type.height_metres) if type.height_metres != null else DEFAULT_WIDTH_AND_HEIGHT
	var wheel_radius: float = clampf(width * 0.2, 0.28, 0.45)
	var ride_height: float = wheel_radius + SUSPENSION_REST_LENGTH - WHEEL_MOUNT_HEIGHT
	body.dimensions_metres = Vector3(width, height, type.length_metres)
	body.wheelbase = float(type.wheelbase_metres) if type.wheelbase_metres != null else type.length_metres * DEFAULT_WHEELBASE_RATIO

	_add_legacy_chassis(body, ride_height)
	var half_track: float = width * 0.4
	var centres := PackedVector3Array([Vector3(-half_track, 0, 0), Vector3(half_track, 0, 0)])
	for front: bool in [false, true]:
		var axle_z: float = type.axle_offset_metres + body.wheelbase * (0.5 if front else -0.5)
		_add_wheel_pair(body, Vector3(0, WHEEL_MOUNT_HEIGHT, axle_z), centres, wheel_radius,
			"Front" if front else "Rear", front, not front)
	model.set_script(null)
	if not is_zero_approx(type.model_yaw_degrees):
		model.rotation.y += deg_to_rad(type.model_yaw_degrees)
	model.position.y = -ride_height

## Convert catalog tonnes and kW into physics kilograms and watts. Missing
## specifications use the same defaults as the original road vehicle builder.
static func _configure_body(body: RoadVehicle3D, type: RoadVehicleTypeData) -> void:
	body.vehicle_obj = VehicleData.of(type.key)
	body.name = "RoadVehicle_%d" % body.vehicle_obj.num
	body.mass = float(type.mass_tonnes) * 1000.0 if type.mass_tonnes != null else 1000.0
	body.maximum_speed_kmh = float(type.max_speed_kmh) if type.max_speed_kmh != null else 50.0
	body.motor_power_watts = float(type.motor_power_kw) * 1000.0 if type.motor_power_kw != null else 25000.0

	body.continuous_cd = true
	# The tall chassis box must not lift the centre of mass above the wheels.
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3.ZERO
	body.collision_layer = 2
	body.collision_mask = 15

static func _add_legacy_chassis(body: RoadVehicle3D, ride_height: float) -> void:
	var dimensions: Vector3 = body.dimensions_metres
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions * Vector3(0.85, 0.65, 0.9)
	collision.shape = box
	collision.position.y = dimensions.y * 0.65 - ride_height
	body.add_child(collision)

## One wheel per end of the axle. +X is the driver's left.
static func _add_wheel_pair(body: RoadVehicle3D, mount: Vector3, centres: PackedVector3Array,
		radius: float, name_prefix: String, steering: bool, traction: bool) -> void:
	for centre: Vector3 in centres:
		var wheel := VehicleWheel3D.new()
		wheel.name = name_prefix + ("Left" if centre.x > 0 else "Right")
		wheel.position = mount + centre
		wheel.use_as_steering = steering
		wheel.use_as_traction = traction
		wheel.wheel_radius = radius
		wheel.wheel_rest_length = SUSPENSION_REST_LENGTH
		wheel.suspension_travel = 0.2
		wheel.suspension_stiffness = 40.0
		wheel.suspension_max_force = body.mass * 10.0
		wheel.damping_compression = 0.5
		wheel.damping_relaxation = 0.8
		body.add_child(wheel)

## The model scene supplies its meshes, textures and material resources. Some
## scenes are also used as static props, so remove their legacy physics nodes.
static func _load_model(type: RoadVehicleTypeData) -> Node3D:
	var scene := load(type.model_scene_path) as PackedScene
	if scene == null or not scene.can_instantiate():
		push_warning("Cannot load road vehicle model: %s" % type.model_scene_path)
		return null
	var instance: Node = scene.instantiate()
	if not instance is Node3D:
		instance.free()
		push_warning("Road vehicle model requires a Node3D root: %s" % type.model_scene_path)
		return null
	return instance as Node3D

static func _prepare_model_visuals(node: Node) -> void:
	if node is GeometryInstance3D:
		node.layers = VEHICLE_RENDER_LAYERS
	for child: Node in node.get_children():
		if child is CollisionObject3D:
			child.free()
		else:
			_prepare_model_visuals(child)

static func _add_camera(body: RoadVehicle3D, length: float, height: float) -> void:
	var camera := Camera3D.new()
	camera.name = "DrivingCamera"
	camera.position = Vector3(0, height + 2.0, -length - 4.0)
	camera.rotation = Vector3(-0.18, PI, 0)
	camera.set_meta("cam_name", &"CAM_ROAD_VEHICLE")
	body.camera = camera
	body.add_child(camera)

static func _add_inventory(body: RoadVehicle3D, type: RoadVehicleTypeData) -> void:
	var inventory := InventoryContainer.new()
	inventory.name = "Inventory"
	inventory.display_name = "%s #%d" % [type.display_name, body.vehicle_obj.num]
	inventory.capacity_override = float(type.capacity.amount) if type.capacity != null else 0.0
	if type.capacity != null:
		inventory.accepted_categories.append(type.capacity.goods_cat)
	body.inventory_component = inventory
	body.add_child(inventory)
	inventory.get_inventory()
