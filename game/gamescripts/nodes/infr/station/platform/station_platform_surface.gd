class_name StationPlatformSurface extends MeshInstance3D

const NINETY_DEG_IN_RAD: float = 1.57079

signal passengers_changed(passenger_count: int)

@export var station_building: StationBuilding3D

@export var station_inventory: GoodsInventory

@export var station_passengers: int = 0

@export var multimesh: MultiMesh

#region Initialization
func _enter_tree() -> void:
		# register on own passenger change signal
	self.passengers_changed.connect(Callable(self, "_on_passengers_changed"))

func _ready() -> void:
	if Engine.is_editor_hint(): return
	# connect to inventory changes
	self.register_station_inventory()
	# create multimesh
	self.create_multimesh()
		
## add inventory & listen to change
func register_station_inventory():
	var found_station_inventory: GoodsInventory = self.get_inventory()
	if found_station_inventory:
		self.station_inventory = found_station_inventory
		found_station_inventory.goods_change.connect(Callable(self, "_on_inventory_goods_changed"))
#endregion

#region Passenger MultiMesh
func create_multimesh():
	self.multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = false
	multimesh.use_custom_data = false
	multimesh.instance_count = 5
	multimesh.mesh = self.get_passenger_mesh()

func reset_buffers():
	var pos_on_platform: Vector3 = self.get_random_pos_on_platform()
	self.multimesh.instance_count = self.station_passengers
	for i: int in range(self.multimesh.instance_count):
		self.multimesh.set_instance_transform(i, WorldUtils.create_transform(
			pos_on_platform,
			Vector3(0, NINETY_DEG_IN_RAD, 0),
			Vector3(1, 1, 1)
		))
		# self.multimesh.custom_aabb = AABB(pos_on_platform, Vector3(10, 10, 10))
	$MultiMeshInstance3D.multimesh = self.multimesh
#endregion

#region Getters
func get_inventory() -> GoodsInventory:
	var node_link_3d: NodeStationLink3D = self.station_building.node_link_3d
	if node_link_3d:
		var station_num: int = node_link_3d.node_station.parent_station_num
		var station_3d: RailStation3D = Managers.stations.get_station_3d_with_num(station_num)
		return station_3d.get_inventory()
	Loggie.error("Cannot get inventory of station from platform %s" % self.name)
	return null

func get_random_pos_on_platform() -> Vector3:
	var platf_size: Vector2 = self.get_platform_size()
	return Vector3(
		randf_range(-platf_size.x /2, platf_size.x /2),
		0,
		randf_range(-platf_size.y /2, platf_size.y /2)
	)

func get_passenger_mesh() -> ArrayMesh:
	return $PassengerMesh/Passenger3Mesh/passenger3.mesh

func get_platform_size() -> Vector2:
	var plane: PlaneMesh = self.mesh as PlaneMesh
	if plane:
		return Vector2( plane.size.x, plane.size.y)
	return Vector2.ZERO
#endregion

#region Callbacks
func _on_inventory_goods_changed():
	var prev_passengers: int = self.station_passengers
	var curr_passengers: int = roundi(self.station_inventory.get_amount("passenger"))
	if prev_passengers != curr_passengers:
		self.station_passengers = curr_passengers
		self.passengers_changed.emit(curr_passengers)

func _on_passengers_changed(_curr_passengers: int):
	self.reset_buffers()
#endregion
