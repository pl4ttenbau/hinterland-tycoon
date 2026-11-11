@tool
@icon("res://assets/icons/nodes_3d/icon_infr_node.svg")
class_name EditorInfrLine3D extends LinePath3D

const RAIL_COLOR = Color.BLACK
const RAIL_MAT_PATH = "res://assets/packed/materials/line3d_rail_track_mat.tres"
const ROAD_COLOR = Color.DARK_ORANGE
const ROAD_MAT_PATH = "res://assets/packed/materials/line3d_roadway_mat.tres"

const LINE_WIDTH = .5
var _connection_service: Node
var _junction_markers: Array[MeshInstance3D] = []

func _validate_property(property: Dictionary) -> void:
	if property.name in ["start_connections", "end_connections"]:
		property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
	elif property.name == "rail_gauge" and infr_domain != Enums.InfrDomain.RAIL:
		property.usage &= ~PROPERTY_USAGE_EDITOR

func _register_connections() -> void:
	if not is_inside_tree():
		return
	var world: Node = get_parent()
	while world != null and not (world is WorldMapScene or world is WorldEditorObjects):
		world = world.get_parent()
	if world != null:
		set_notify_transform(true)
		if not curve_changed.is_connected(_connections_changed):
			curve_changed.connect(_connections_changed)
		_connection_service = RoadEndpointConnection.ensure(world)
		_connection_service.register(self)

func _exit_tree() -> void:
	if is_instance_valid(_connection_service):
		_connection_service.unregister(self)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_connections_changed()

func _connections_changed() -> void:
	if is_instance_valid(_connection_service):
		_connection_service.request_update()

func _connection_entries(entries: Array[EditorEndpointConnection], previous: Array[EditorEndpointConnection]) -> Array[EditorEndpointConnection]:
	var result: Array[EditorEndpointConnection] = []
	for index: int in range(entries.size()):
		var entry: EditorEndpointConnection = entries[index]
		# Keep unchanged resources so a rebuild doesn't collapse Inspector entries.
		if index < previous.size() and previous[index].road == entry.road and previous[index].endpoint == entry.endpoint:
			result.append(previous[index])
		else:
			result.append(entry)
	return result

func apply_endpoint_connections(start: Array[EditorEndpointConnection], end: Array[EditorEndpointConnection], show_start: bool, show_end: bool) -> void:
	var start_entries: Array[EditorEndpointConnection] = _connection_entries(start, start_connections)
	var end_entries: Array[EditorEndpointConnection] = _connection_entries(end, end_connections)
	var changed: bool = start_connections != start_entries or end_connections != end_entries
	start_connections.assign(start_entries)
	end_connections.assign(end_entries)
	if changed:
		notify_property_list_changed()
	# Markers are derived editor visuals: no owner, no saved geometry or collider.
	while _junction_markers.size() < 2:
		_junction_markers.append(null)
	for endpoint: int in [0, 1]:
		_update_junction_marker(endpoint, show_start if endpoint == 0 else show_end)

func _update_junction_marker(endpoint: int, show_marker: bool) -> void:
	var marker: MeshInstance3D = _junction_markers[endpoint]
	if is_instance_valid(marker) and marker.is_queued_for_deletion():
		marker = null
	if show_marker and not is_instance_valid(marker):
		marker = _create_junction_marker()
		_junction_markers[endpoint] = marker
	if is_instance_valid(marker):
		marker.visible = show_marker
		if show_marker and curve and curve.point_count >= 2:
			var idx: int = 0 if endpoint == 0 else curve.point_count - 1
			# Lift only the indicator so it is readable above the road surface.
			marker.position = curve.get_point_position(idx) + Vector3.UP * 0.3

func _create_junction_marker() -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = "EditorEndpointConnection"
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	marker.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.CYAN
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	return marker


@export var num: int = -1
@export var infr_name: String
@export var infr_domain: Enums.InfrDomain
## An empty value keeps the gauge already saved in the map's track record.
@export_enum("600_MM", "750_MM", "1067_MM", "NORMAL_GAUGE") var rail_gauge: String = ""

@export var color: Color:
	get(): return self._get_color()
	
@export var abs_aabb: AABB

@export_group("Smoothing")
@export var autosmooth: bool = false

@export_tool_button("Auto-Smooth Y")
var smooth_y = Callable(self, "do_smooth_y")

@export_tool_button("Auto-Smooth Full")
var smooth_full = Callable(self, "do_smooth_full")

@export_group("Editing")
## For lines inside a world map. The standalone EditorObjects scene is directly editable.
@export_tool_button("Edit In Cache")
var edit_in_cache = Callable(self, "do_edit_in_cache")

@export_tool_button("Place On Ground")
var place_on_ground = Callable(self, "do_place_on_ground")

@export_group("Road Connections")
## Derived editor information; each entry identifies the other road and its end.
@export var start_connections: Array[EditorEndpointConnection] = []
@export var end_connections: Array[EditorEndpointConnection] = []
@export_group("")

#region Initialization
static func of(_domain: Enums.InfrDomain, _num: int, _name: String = "unnamed", _autosmooth: bool = false) -> EditorInfrLine3D:
	var inst := EditorInfrLine3D.new()
	inst.infr_domain = _domain
	inst.num = _num
	inst.infr_name = _name
	inst.autosmooth = _autosmooth
	# auto-set node name
	inst.name = inst._get_node_name()
	return inst
	
static func ofRoad(_num: int, _name: String = "unnamed", _autosmooth: bool = false) -> EditorInfrLine3D:
	return EditorInfrLine3D.of(Enums.InfrDomain.ROAD, _num, _name, _autosmooth)

static func ofRail(_num: int, _name: String = "unnamed") -> EditorInfrLine3D:
	return EditorInfrLine3D.of(Enums.InfrDomain.RAIL, _num, _name, true)
	
func _enter_tree():
	super()
	self.material = self._get_material(self.infr_domain)
	if Engine.is_editor_hint():
		_register_connections.call_deferred()
#endregion

#region Curve
func create_curve_from_dict(infr_dict: Dictionary):
	if infr_domain == Enums.InfrDomain.RAIL:
		rail_gauge = infr_dict.get("type", "")
	self.curve = Curve3D.new()
	var abs_points: PackedVector3Array = []
	var point_handle_in: PackedVector3Array = []
	var point_handle_out: PackedVector3Array = []
	# build abs pos & handle in vector array
	for point_json in infr_dict.points:
		abs_points.append(WorldUtils.vec3_from_float_arr(point_json.pos))
		var handle_in: Vector3 = self._get_handle_in_from_point_json(point_json)
		point_handle_in.append(handle_in)
		# Older maps stored only handleIn and assumed mirrored handles.
		var handle_out: Vector3 = -handle_in
		if point_json.has("handleOut"):
			handle_out = WorldUtils.vec3_from_float_arr(point_json.get("handleOut"))
		point_handle_out.append(handle_out)
	# make relative positions from absolute ones & set to curve
	var point_i: int = 0
	for abs_pos in abs_points:
		var rel_pos: Vector3 = abs_pos - self.position
		var handle_in: Vector3 = point_handle_in[point_i]
		# add point pos with handles to curve
		self.curve.add_point(rel_pos, handle_in, point_handle_out[point_i])
		point_i += 1
	# generate aabb
	self.abs_aabb = InfrUtils.get_aabb(abs_points)
	if self.autosmooth:
		InfrUtils.smooth_curve3d(self.curve, true)

func _get_handle_in_from_point_json(point_json: Dictionary) -> Vector3:
	if point_json.has("handleIn"):
		var handle_in_arr: Array = point_json.get("handleIn")
		var point_in_vec3: Vector3 = WorldUtils.vec3_from_float_arr(handle_in_arr)
		return point_in_vec3
	else: return Vector3.ZERO
	
func do_smooth_y():
	InfrUtils.smooth_curve3d_y(self.curve)

func do_smooth_full():
	InfrUtils.smooth_curve3d(self.curve)
#endregion

#region Editing
func do_edit_in_cache() -> void:
	_register_connections()
	if not is_instance_valid(_connection_service):
		return
	var copy: Node3D = _connection_service.edit_in_cache(self)
	if copy != null and Engine.is_editor_hint():
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(copy)

func do_place_on_ground():
	Infr3DExporter.place_on_ground(self)
#endregion

#region Helper-Methods
func _get_color() -> Color:
	if self.infr_domain == Enums.InfrDomain.RAIL:
		return RAIL_COLOR
	elif self.infr_domain == Enums.InfrDomain.ROAD:
		return ROAD_COLOR
	return Color.MAGENTA
	
func _get_material(_domain: Enums.InfrDomain) -> ShaderMaterial:
	if _domain == Enums.InfrDomain.RAIL:
		return preload(RAIL_MAT_PATH) as ShaderMaterial
	elif _domain == Enums.InfrDomain.ROAD:
		return preload(ROAD_MAT_PATH) as ShaderMaterial
	return null
	
func _get_node_name() -> String:
	var name_prefix: String = "RailTrack"
	if self.infr_domain == Enums.InfrDomain.ROAD:
		name_prefix = "RoadWay"
	return name_prefix + "_" + str(self.num)
#endregion
