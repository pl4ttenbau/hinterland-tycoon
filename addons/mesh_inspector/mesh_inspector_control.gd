@tool
extends VBoxContainer
class_name MeshInspectorControl

## The object we are getting stats on. Should be a MeshInstance3D or Mesh
var object: Object

# Something to put all our controls into
var main_container: VBoxContainer

func _ready():
	main_container = VBoxContainer.new()
	add_child(main_container)
	update_stats()

func update_stats():
	# Clear previous stats
	for child in main_container.get_children():
		child.queue_free()

	if not object:
		return

	var mesh: Mesh = null
	var node_transform := Transform3D.IDENTITY

	if object is MeshInstance3D:
		mesh = object.mesh
		node_transform = object.global_transform
	elif object is Mesh:
		mesh = object

	if not mesh:
		return

	var vertex_total := 0
	var face_total := 0
	var surface_count := mesh.get_surface_count()

	for i in surface_count:
		var mdt := MeshDataTool.new()
		mdt.create_from_surface(mesh, i)
		vertex_total += mdt.get_vertex_count()
		face_total += mdt.get_face_count()

	# Bounding box
	var aabb := mesh.get_aabb()
	var local_size := aabb.size.abs()
	var local_volume := aabb.get_volume() if aabb.has_volume() else 0.0

	# bounding box after world transform applied
	var world_aabb := node_transform * aabb if object is MeshInstance3D else aabb
	var world_size := world_aabb.size.abs()
	var world_volume := world_aabb.get_volume() if world_aabb.has_volume() else 0.0

	# Main section
	var stats_fold = FoldableContainer.new()
	var stats_vbox = VBoxContainer.new()

	stats_fold.title = "Mesh Stats"

	main_container.add_child(stats_fold)
	stats_fold.add_child(stats_vbox)

	# Add some stats
	add_float(stats_vbox, 'Material Count', surface_count)
	add_float(stats_vbox, 'Vertex Count', vertex_total, 'verts')
	add_float(stats_vbox, 'Face Count', face_total, 'tris')


	# Bounding box section
	var bb_fold = FoldableContainer.new()
	var bb_vbox = VBoxContainer.new()
	bb_fold.title = "Local Bounding Box Stats"
	main_container.add_child(bb_fold)
	bb_fold.add_child(bb_vbox)

	add_vec3(bb_vbox, "Size", local_size)
	add_float(bb_vbox, 'Volume', local_volume)

	if object is MeshInstance3D:
		# Again if we have a world transform
		var wbb_fold = FoldableContainer.new()
		var wbb_vbox = VBoxContainer.new()
		wbb_fold.title = "World Bounding Box Stats"
		main_container.add_child(wbb_fold)
		wbb_fold.add_child(wbb_vbox)

		add_vec3(wbb_vbox, "Transformed Size", world_size)
		add_float(wbb_vbox, 'Transformed Volume', world_volume)


func add_vec3(container: Container, label: String, value: Vector3) -> void:
	add_label(container, label)

	var grid = GridContainer.new()
	grid.columns = 3
	container.add_child(grid)
	add_value(grid, value.x, 'x', 'm', Color(0.8,0.2,0))
	add_value(grid, value.y, 'y', 'm', Color(0.5,0.8,0))
	add_value(grid, value.z, 'z', 'm', Color(0,0.5,0.9))

func add_float(container : Container, label: String, value: float, suffix: String = "") -> void:
	var grid = GridContainer.new()
	grid.columns = 2
	container.add_child(grid)
	add_label(grid, label)
	add_value(grid, value, '', suffix)

func add_label(container : Container, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(lbl)

func add_value(container : Container, value: float, prefix: String = '', suffix: String = '', prefix_colour = null):
	var slider = EditorSpinSlider.new()
	slider.allow_greater = true
	slider.max_value = value
	slider.label = prefix
	slider.value = value
	slider.suffix = suffix
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.read_only = true
	slider.control_state = EditorSpinSlider.ControlState.CONTROL_STATE_HIDE

	if prefix_colour != null:
		slider.add_theme_color_override(&"read_only_label_color", prefix_colour)

	container.add_child(slider)
