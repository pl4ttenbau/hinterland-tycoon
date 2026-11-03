## Rebuild oak/fir LOD scenes after baking their PNGs with tree_billboard.py.
## Run: godot --headless --path . --script res://tools/configure_tree_billboards.gd -- --no-mcp
extends SceneTree

const FAR_DISTANCE: float = 350.0
const SPECIES: Array[Dictionary] = [
	{"directory": "tree2_oak", "name": "oak", "scene": "tree2_oak.tscn"},
	{"directory": "tree1_fir", "name": "fir", "scene": "tree1_fir.tscn"},
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var replacements: Dictionary = {}
	for species: Dictionary in SPECIES:
		var directory: String = "res://assets/meshes/nature/" + species.directory + "/"
		var original: String = directory + species.scene
		var output: String = directory + "billboard_lods_" + species.name + ".tscn"
		var metadata_path: String = directory + "billboard_" + species.name + ".json"
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
		var source: Node3D = load(original).instantiate()
		var meshes: Array[Node] = source.find_children("*", "MeshInstance3D", true, false)
		if meshes.size() != 1:
			_fail("Expected exactly one source mesh: " + original)
			return
		var near: MeshInstance3D = meshes[0] as MeshInstance3D
		near.get_parent().remove_child(near)
		source.free()
		var root := Node3D.new()
		root.name = species.name.capitalize() + "TreeLODs"
		near.name = "TreeLOD0"
		root.add_child(near)
		near.owner = root
		var card := MeshInstance3D.new()
		card.name = "TreeLOD1"
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var quad := QuadMesh.new()
		quad.size = Vector2(data.quad_size[0], data.quad_size[1])
		var centre: Array = data.views[0].quad_center_from_base_right_up
		# The metadata pivot is at the lowest vertex; restore the source origin.
		quad.center_offset = Vector3(centre[0], centre[1] + data.bounds_blender_z_up.min[2], 0.0)
		var material := StandardMaterial3D.new()
		material.albedo_texture = load(directory + "billboard_" + species.name + ".png")
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		material.billboard_keep_scale = true
		material.roughness = 1.0
		material.metallic_specular = 0.0
		quad.material = material
		card.mesh = quad
		root.add_child(card)
		card.owner = root
		var packed := PackedScene.new()
		var error := packed.pack(root)
		root.free()
		if error != OK or ResourceSaver.save(packed, output) != OK:
			_fail("Could not save billboard LOD scene: " + output)
			return
		var reloaded: PackedScene = ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
		var probe := Terrain3DMeshAsset.new()
		probe.scene_file = reloaded
		if probe.get_lod_count() != 2:
			_fail("Terrain3D did not detect two LODs: " + output)
			return
		replacements[original] = reloaded
		replacements[output] = reloaded
	for map: String in ["franzburger", "mpsb", "harzmountains", "sachalin"]:
		var path: String = "res://world/%s/mapscenes/terrain/terrain_assets_%s.res" % [map, map]
		var assets: Terrain3DAssets = load(path)
		var changed: int = 0
		for i: int in range(assets.get_mesh_count()):
			var asset: Terrain3DMeshAsset = assets.get_mesh_asset(i)
			if asset == null or asset.scene_file == null or not replacements.has(asset.scene_file.resource_path):
				continue
			var near_distance: float = asset.lod0_range
			var asset_name: String = asset.name
			var density: float = asset.density
			asset.scene_file = replacements[asset.scene_file.resource_path]
			asset.name = asset_name
			asset.density = density
			asset.last_lod = 1
			asset.lod0_range = near_distance
			asset.lod1_range = FAR_DISTANCE
			asset.last_shadow_lod = 0
			asset.shadow_impostor = 0
			changed += 1
		if changed != 2 or ResourceSaver.save(assets, path, ResourceSaver.FLAG_COMPRESS) != OK:
			_fail("Expected to update exactly oak and fir: " + path)
			return
		print("BILLBOARD_UPDATED ", map, " oak/fir far range ", FAR_DISTANCE)
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
