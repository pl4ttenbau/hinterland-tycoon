## Run road_vehicle_preview.tscn (F6) for an isolated driving/collision playground.
extends Node3D

var player: PlayerAvatar
var manager: VehiclePlacer
var vehicle: RoadVehicle3D
var overview: Camera3D
var status: Label

func _ready() -> void:
	_add_lighting()
	_add_ground()
	var roads: RoadsLoader = _add_services()
	_add_road(roads)
	_add_rail()
	_add_player_and_overview()
	_add_status_label()
	_restart()

func _add_lighting() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("a7b9c2")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.shadow_enabled = true
	add_child(sun)

## Keep the floor below the embankment so road collision can be tested separately.
func _add_ground() -> void:
	var ground := StaticBody3D.new()
	ground.position = Vector3(0, -3.5, -50)
	var box := BoxMesh.new()
	box.size = Vector3(240, 1, 240)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("56634e")
	box.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	ground.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.shape = box.create_trimesh_shape()
	ground.add_child(shape)
	add_child(ground)

func _add_services() -> RoadsLoader:
	var roads := RoadsLoader.new()
	add_child(roads)
	Managers.roads = roads
	manager = VehiclePlacer.new()
	add_child(manager)
	Managers.vehicles = manager
	return roads

## One straight approach and a bend exercise acceleration, steering and stopping.
func _add_road(roads: RoadsLoader) -> void:
	var data := RoadData.of(9101, "rural_road")
	data.curve = Curve3D.new()
	data.curve.add_point(Vector3.ZERO)
	data.curve.add_point(Vector3(0, 0, -70), Vector3(0, 0, 15), Vector3(0, 0, -15))
	data.curve.add_point(Vector3(15, 0, -100), Vector3(-15, 0, 0), Vector3(15, 0, 0))
	data.curve.add_point(Vector3(45, 0, -100))
	# The route editor needs authored node data as well as rendered curve geometry.
	for index: int in range(data.curve.point_count):
		var node := RoadNode.of(index, data.curve.get_point_position(index), data)
		node.rel_position = node.position
		data.add_node(node)
	roads.storage.add(data)
	var road: RoadWay3D = load(RoadData.RURAL_ROAD_SCENE_PATH).instantiate()
	road.road = data
	roads.add_child(road)
	roads.storage.add_container(road)

## Show a raised, solid rail bed alongside the road for on-foot inspection.
func _add_rail() -> void:
	var rail: RailTrack3D = load(RailTrack3D.SCENE_PATH_750MM).instantiate()
	rail.position = Vector3(-15, 0, 0)
	rail.curve = Curve3D.new()
	rail.curve.add_point(Vector3.ZERO)
	rail.curve.add_point(Vector3(0, 0, -70))
	add_child(rail)

func _add_player_and_overview() -> void:
	player = load("res://scenes/subscenes/player.tscn").instantiate()
	player.walking_body.position = Vector3(2.5, 1, -5)
	add_child(player)
	overview = Camera3D.new()
	overview.position = Vector3(60, 65, 12)
	add_child(overview)
	overview.look_at(Vector3(8, 0, -48))

func _add_status_label() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	status = Label.new()
	status.position = Vector2(24, 20)
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_color_override("font_shadow_color", Color.BLACK)
	status.add_theme_constant_override("shadow_offset_x", 2)
	status.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(status)

func _restart() -> void:
	if is_instance_valid(vehicle):
		if player.control.is_in_vehicle():
			player.control.exit_vehicle()
		vehicle.free()
	vehicle = manager.spawn_road_vehicle("trabant_601_green", [9101])
	overview.make_current()
	GlobalState.active_cam = overview
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_E:
		if player.control.is_in_vehicle():
			player.control.exit_vehicle()
		else:
			player.control.enter_road_vehicle(vehicle)
	elif event.physical_keycode == KEY_R and not player.control.is_in_vehicle():
		_restart()
	elif event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(_delta: float) -> void:
	if not is_instance_valid(vehicle):
		return
	status.text = "Road vehicle playground  ·  %s  ·  %.0f km/h\nE: take control / leave   R: route editor (driving) / restart (on foot)\nDrive: W/S or ↑/↓   Steer: A/D or ←/→   Brake: Space\nOn foot: arrow keys + mouse   Esc: release mouse" % ["PLAYER" if vehicle.player_driving else "ROUTE", absf(vehicle.signed_speed_mps()) * 3.6]
