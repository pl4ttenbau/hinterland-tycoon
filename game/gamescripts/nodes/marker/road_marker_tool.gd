## Session-scoped placement input and marker views; authored road geometry is untouched.
class_name RoadMarkerTool extends Node

const MARKER_SCENE: String = "res://assets/meshes/infr/road/waypoint/route_marker.tscn"

var roads: RoadsLoader
var _views: Dictionary = {}
var _message: Label

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode != KEY_M:
		return
	if Managers.roads != roads or UiState.current_diag != null or not is_instance_valid(GlobalState.player):
		return
	if GlobalState.player.in_road_vehicle != null or GlobalState.player.in_train != null:
		return
	var player: BasicFpsPlayer = GlobalState.player.player_parent
	var placement: Dictionary = placement_at(player.global_position, player.get_rid())
	get_viewport().set_input_as_handled()
	if placement.is_empty():
		_show_message("Stand on a road to place a marker.")
		return
	var script: GDScript = load("res://game/gamescripts/ui/dialogs/road_marker/road_marker_dialog.gd")
	if event.shift_pressed:
		placement.side = Enums.RoadSide.BOTH
	get_tree().root.add_child(script.create(self, placement))

## A physical ray prevents selecting a nearby road or a bridge above/below the player.
func placement_at(position: Vector3, exclude: RID = RID()) -> Dictionary:
	if roads.storage.get_containers().is_empty():
		return {}
	var host: RoadWay3D = roads.storage.get_containers()[0]
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 0.5, position - Vector3.UP * 2.0, 1)
	if exclude.is_valid():
		query.exclude = [exclude]
	var hit: Dictionary = host.get_world_3d().direct_space_state.intersect_ray(query)
	var road: Node = hit.get("collider")
	while road != null and not road is RoadWay3D:
		road = road.get_parent()
	if road == null:
		return {}
	var path: Path3D = road.get_path_3d()
	var offset: float = path.curve.get_closest_offset(path.to_local(hit.position))
	var center: Vector3 = path.to_global(path.curve.sample_baked(offset))
	var forward: Vector3 = path.to_global(path.curve.sample_baked(minf(offset + 0.1, path.curve.get_baked_length()))) - path.to_global(path.curve.sample_baked(maxf(0, offset - 0.1)))
	var side: Enums.RoadSide = Enums.RoadSide.RIGHT if (position - center).dot(forward.cross(Vector3.UP)) >= 0 else Enums.RoadSide.LEFT
	return {"road_num": road.road.num, "offset": offset, "side": side}

## Confirm the captured location, even if the player was standing just beside its centreline.
func place(placement: Dictionary, title: String) -> RoadMarkerData:
	var road: RoadWay3D = roads.storage._containers_by_id.get(placement.road_num)
	if road == null or placement.offset < 0 or placement.offset > road.get_path_3d().curve.get_baked_length():
		return null
	var marker := RoadMarkerData.new()
	marker.num = roads.markers.next_num()
	marker.marker_name = title.strip_edges()
	if marker.marker_name.is_empty():
		marker.marker_name = "Marker %d" % marker.num
	marker.road_num = placement.road_num
	marker.offset = placement.offset
	marker.side = placement.side
	roads.markers.markers.append(marker)
	_show_marker(marker, road.get_path_3d())
	return marker

## Signs are visual only: one logical BOTH marker never creates two route targets.
func _show_marker(marker: RoadMarkerData, path: Path3D) -> void:
	var root := Node3D.new()
	root.name = "RoadMarker_%d" % marker.num
	add_child(root)
	root.global_position = path.to_global(path.curve.sample_baked(marker.offset))
	var direction: Vector3 = path.to_global(path.curve.sample_baked(minf(marker.offset + 0.1, path.curve.get_baked_length()))) - path.to_global(path.curve.sample_baked(maxf(0, marker.offset - 0.1)))
	var right: Vector3 = direction.cross(Vector3.UP).normalized()
	var sides: Array[int] = []
	sides.assign([-1, 1] if marker.side == Enums.RoadSide.BOTH else [-1 if marker.side == Enums.RoadSide.LEFT else 1])
	for side: int in sides:
		_add_sign(root, marker, right * 4.0 * side)
	_views[marker.num] = root

func _add_sign(root: Node3D, marker: RoadMarkerData, offset: Vector3) -> void:
	# Set the post on the shoulder/terrain instead of floating at centreline height.
	var position: Vector3 = root.global_position + offset
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 3.0, position - Vector3.UP * 10.0, 1)
	var ground: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(query)
	if not ground.is_empty():
		offset.y = ground.position.y - root.global_position.y
	var post: Node3D = load(MARKER_SCENE).instantiate()
	post.position = offset
	if post is GeometryInstance3D:
		post.layers = 16
	root.add_child(post)
	# Face the road horizontally; sloping shoulders must not tilt the signpost.
	post.look_at(post.global_position + Vector3(-offset.x, 0, -offset.z))
	var label := Label3D.new()
	label.text = marker.marker_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.015
	label.modulate = Color("ffe09a")
	label.position = offset + Vector3.UP * 2.95
	root.add_child(label)

func _show_message(text: String) -> void:
	if not is_instance_valid(_message):
		var canvas := CanvasLayer.new()
		add_child(canvas)
		_message = Label.new()
		_message.position = Vector2(24, 80)
		canvas.add_child(_message)
	_message.text = text
	_message.show()
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(_message): _message.hide())
