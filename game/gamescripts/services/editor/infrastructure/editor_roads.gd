@icon("uid://dyg1oiarkflpi")
@tool
class_name GeneratedRoadWays extends Node3D

@export_tool_button("Generate Roadways")
var gen_tracks = Callable(self, "do_generate_roadways")

@export_tool_button("Clear Roads")
var clear_btn = Callable(self, "do_clear")

@export_storage var curr_max_road_num: int = 0
@export_storage var curr_road_num_group_index: int = 0
@export_storage var curr_road_num_group: Node

#region Actions
func do_generate_roadways():
	var generator := WorldRoadsGenerator.new()
	generator.spawn_road_paths()
	generator.queue_free()

func do_clear():
	self.clear()
#endregion

func add_road(line3d: EditorInfrLine3D):
	var group_node: Node = self.get_num_group(line3d.num)
	group_node.add_child(line3d)
	# self.add_child(line3d)
	self.curr_max_road_num = line3d.num
	line3d.owner = EditorInterface.get_edited_scene_root()

func create_num_groups_towards(max_num: int):
	@warning_ignore("integer_division")
	var max_group_index: int = floori(max_num / 50)
	Loggie.info("Creating road groups")
	for group_index in range(0, max_group_index +1):
		var group_min: int = group_index * 50
		var group_max: int = group_min + 49
		Loggie.info("%d__%d" % [group_min, group_max])
		var group_node: Node = Node.new()
		self.add_child(group_node)
		group_node.owner = EditorInterface.get_edited_scene_root()
		group_node.name = "%d__%d" % [group_min, group_max]

func get_num_group(road_num: int) -> Node:
	var group_index: int = floori(road_num / 50)
	var group_min: int = group_index * 50
	var group_max: int = group_min + 49
	var group_name = "%d__%d" % [group_min, group_max]
	var group_node: Node = self.get_node(group_name)
	return group_node

func clear():
	for child in self.get_children():
		child.queue_free()
