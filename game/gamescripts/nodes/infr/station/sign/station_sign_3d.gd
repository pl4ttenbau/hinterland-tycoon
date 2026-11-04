@tool
class_name StationSign3D extends Sprite3D

@export var node_station_link_3d: NodeStationLink3D

@export var parent_station: AbstractStation

@export var station_inventory: GoodsInventory

@export var station_name: String:
	set(value):
		station_name = value
		if is_instance_valid(self.station_sign_ui):
			self.station_sign_ui.station_name = value

@export var station_sign_ui: StationSignPanel

@export_group("Current Good Amounts", "amount_")
@export var amount_passengers: float:
	set(value):
		amount_passengers = value
		if is_instance_valid(self.station_sign_ui):
			self.station_sign_ui.passengers_amount = roundi(value)

@export var amount_cargo: float:
	set(value):
		amount_cargo = value
		if is_instance_valid(self.station_sign_ui):
			self.station_sign_ui.cargo_amount = roundi(value)

#region Initialization
func _enter_tree() -> void:
	if not Engine.is_editor_hint() and is_instance_valid(self.node_station_link_3d) \
			and not self.node_station_link_3d.node_station_changed.is_connected(self._on_node_station_changed):
		self.node_station_link_3d.node_station_changed.connect(self._on_node_station_changed)

func _ready() -> void:
	# Legacy rail scenes override this resource in their enclosing scene. Resolve
	# its path relative to that resource's scene, keeping a serializable texture
	# for editor previews rather than saving Viewport.get_texture()'s live handle.
	var viewport_texture := self.texture as ViewportTexture
	if viewport_texture != null:
		var texture_scene: Node = viewport_texture.get_local_scene()
		if is_instance_valid(texture_scene):
			viewport_texture.viewport_path = texture_scene.get_path_to(self.get_node("SubViewport"))
	self.station_sign_ui.station_name = self.station_name
	if not Engine.is_editor_hint() and is_instance_valid(self.node_station_link_3d):
		self._on_node_station_changed(self.node_station_link_3d.node_station)
	else:
		self._on_inventory_change()
#endregion

#region Callbacks
func _on_node_station_changed(node_station: NodeStationLinkData):
	if node_station == null or node_station.parent_station == null:
		return
	var station_3d: RailStation3D = self.node_station_link_3d.get_parent_station_3d()
	self.bind_station(node_station.parent_station, station_3d.get_inventory())

## Both rail and road stops use the same name panel and inventory counters.
## Editor labels leave the data/inventory unbound and save only station_name.
func bind_station(station: AbstractStation, inventory: GoodsInventory) -> void:
	self._disconnect_inventory()
	self.parent_station = station
	self.station_inventory = inventory
	self.visible = station != null
	self.station_name = station.station_name if station != null else ""
	if inventory != null:
		inventory.goods_change.connect(self._on_inventory_change)
	self._on_inventory_change()

func _on_inventory_change():
	self.amount_passengers = self.station_inventory.storage.total_passengers if self.station_inventory != null else 0.0
	self.amount_cargo = self.station_inventory.storage.total_cargo if self.station_inventory != null else 0.0

func _disconnect_inventory() -> void:
	if self.station_inventory != null and self.station_inventory.goods_change.is_connected(self._on_inventory_change):
		self.station_inventory.goods_change.disconnect(self._on_inventory_change)

func _exit_tree() -> void:
	self._disconnect_inventory()
	if is_instance_valid(self.node_station_link_3d) and self.node_station_link_3d.node_station_changed.is_connected(self._on_node_station_changed):
		self.node_station_link_3d.node_station_changed.disconnect(self._on_node_station_changed)
#endregion
