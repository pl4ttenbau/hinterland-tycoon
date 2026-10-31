@tool
extends Node

const HOUSE = preload("res://game/gamescripts/nodes/structures/editor_residence_3d.gd")
const CONNECTOR = preload("res://game/gamescripts/services/importexport/infr/connectors/residence_road_connector.gd")
var _visual: MeshInstance3D
var _elapsed: float = 0.0

func _enter_tree() -> void:
	set_process(Engine.is_editor_hint())

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.15:
		return
	_elapsed = 0.0
	var world: Node = EditorInterface.get_edited_scene_root()
	var house: Node3D
	for selected: Node in EditorInterface.get_selection().get_selected_nodes():
		var candidate: Node = selected
		while candidate != null and candidate != world:
			if candidate is HOUSE:
				house = candidate
				break
			candidate = candidate.get_parent()
		if house != null:
			break
	if house == null or world == null:
		clear_preview()
		return
	update_for_house(house, world)

## Live debug only: does not modify the saved house connection or mark a scene dirty.
func update_for_house(house: Node3D, world: Node) -> void:
	var roads: Array[Dictionary] = CONNECTOR.prepare_editor_roads(CONNECTOR.editor_roads(world))
	var origin: Vector3 = CONNECTOR.exit_for(house)
	var connection = CONNECTOR.find_prepared(origin, roads)
	if connection == null:
		clear_preview()
		return
	var endpoint: Vector3
	for road: Dictionary in roads:
		if road.num == connection.road_num:
			endpoint = road.curve.sample_baked(connection.dist_from_zero)
			break
	if is_instance_valid(_visual) and _visual.get_parent() != world:
		clear_preview()
	if not is_instance_valid(_visual):
		_visual = MeshInstance3D.new()
		_visual.name = "_ResidenceRoadPreview"
		_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("65e6c4")
		_visual.material_override = material
		world.add_child(_visual) # No owner: never saved into the map.
		_visual.top_level = true
		_visual.global_transform = Transform3D.IDENTITY
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(origin)
	mesh.surface_add_vertex(endpoint)
	for point: Vector3 in [origin, endpoint]:
		for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			mesh.surface_add_vertex(point - axis * 0.2)
			mesh.surface_add_vertex(point + axis * 0.2)
	mesh.surface_end()
	_visual.mesh = mesh

func clear_preview() -> void:
	if is_instance_valid(_visual):
		_visual.get_parent().remove_child(_visual)
		_visual.queue_free()
	_visual = null

func _exit_tree() -> void:
	clear_preview()
