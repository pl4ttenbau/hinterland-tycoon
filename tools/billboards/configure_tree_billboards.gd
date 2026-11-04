## Install tree LOD scenes after baking their PNGs with tree_billboard.py.
## Existing scenes are reused; add --rebuild-scenes to refresh their geometry.
## Run: godot --headless --path . --script res://tools/billboards/configure_tree_billboards.gd -- --no-mcp
extends SceneTree

const FAR_DISTANCE: float = 350.0
# A flat card needs a broader light response than an individual leaf plane.
# Scale the source leaves' backlight to match the average crown brightness.
const BILLBOARD_BACKLIGHT_FACTOR: float = 0.67
const SPECIES: Array[Dictionary] = [
	{"directory": "tree2_oak", "name": "oak", "scene": "tree2_oak.tscn"},
	{"directory": "tree1_fir", "name": "fir", "scene": "tree1_fir.tscn"},
	{"directory": "tree3_kastanie", "name": "chestnut", "scene": "tree3_kastanie.tscn"},
	{"directory": "tree4_apple", "name": "apple", "scene": "tree4_apple.tscn"},
	{"directory": "tree5_pine", "name": "pine", "scene": "deco_tree5_pine.tscn"},
	{"directory": "tree6_birch", "name": "birch", "scene": "deco_tree6_birch.tscn"},
	{"directory": "lilac_tree_1", "name": "lilac", "scene": "lilac_tree_1.tscn"},
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var replacements: Dictionary = {}
	var embedded_species: Dictionary = {}
	for species: Dictionary in SPECIES:
		var directory: String = "res://assets/meshes/nature/" + species.directory + "/"
		var original: String = directory + species.scene
		var output: String = directory + "billboard_lods_" + species.name + ".tscn"
		var metadata_path: String = directory + "billboard_" + species.name + ".json"
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
		var texture: Texture2D = load(directory + "billboard_" + species.name + ".png")
		var reloaded: PackedScene
		if ResourceLoader.exists(output) and not "--rebuild-scenes" in OS.get_cmdline_user_args():
			reloaded = load(output)
		else:
			reloaded = _build_scene(load(original), data, texture, output)
		if reloaded == null:
			return
		if not _refresh_billboard_lighting(reloaded, output):
			return
		var probe := Terrain3DMeshAsset.new()
		probe.scene_file = reloaded
		if probe.get_lod_count() != 2:
			_fail("Terrain3D did not detect two LODs: " + output)
			return
		replacements[original] = reloaded
		replacements[output] = reloaded
		embedded_species[_mesh_signature(probe.get_mesh(0))] = {"name":species.name, "directory":directory, "data":data, "texture":texture}
	for map: String in ["franzburger", "mpsb", "harzmountains", "sachalin"]:
		var path: String = "res://world/%s/mapscenes/terrain/terrain_assets_%s.res" % [map, map]
		var assets: Terrain3DAssets = load(path)
		var changed: int = 0
		var settings_changed: bool = false
		for i: int in range(assets.get_mesh_count()):
			var asset: Terrain3DMeshAsset = assets.get_mesh_asset(i)
			if asset == null or asset.scene_file == null:
				continue
			var replacement: PackedScene = replacements.get(asset.scene_file.resource_path)
			if replacement == null and (asset.scene_file.is_built_in() or asset.scene_file.resource_path.get_file().begins_with("billboard_lods_")):
				var recipe: Dictionary = embedded_species.get(_mesh_signature(asset.get_mesh(0)), {})
				if not recipe.is_empty():
					# Keep the embedded tree's own near mesh/materials instead of replacing
					# them with the canonical species scene.
					if not asset.scene_file.is_built_in() and not "--rebuild-scenes" in OS.get_cmdline_user_args():
						replacement = asset.scene_file
						if not _refresh_billboard_lighting(replacement, replacement.resource_path):
							return
					else:
						var output: String = recipe.directory.path_join("billboard_lods_%s_%s_%d.tscn" % [recipe.name, map, i])
						replacement = _build_scene(asset.scene_file, recipe.data, recipe.texture, output)
						if replacement == null:
							return
			if replacement == null:
				continue
			settings_changed = settings_changed or asset.scene_file.resource_path != replacement.resource_path \
				or asset.last_lod != 1 or asset.lod1_range != FAR_DISTANCE \
				or asset.last_shadow_lod != 0 or asset.shadow_impostor != 0
			var near_distance: float = asset.lod0_range
			var asset_name: String = asset.name
			var density: float = asset.density
			asset.scene_file = replacement
			asset.name = asset_name
			asset.density = density
			asset.last_lod = 1
			asset.lod0_range = near_distance
			asset.lod1_range = FAR_DISTANCE
			asset.last_shadow_lod = 0
			asset.shadow_impostor = 0
			changed += 1
		if changed < 2 or (settings_changed and ResourceSaver.save(assets, path, ResourceSaver.FLAG_COMPRESS) != OK):
			_fail("Could not configure tree billboards: " + path)
			return
		print("BILLBOARD_UPDATED ", map, " species ", changed, " far range ", FAR_DISTANCE)
	quit()

func _build_scene(original: PackedScene, data: Dictionary, texture: Texture2D, output: String) -> PackedScene:
	var source: Node3D = original.instantiate()
	var meshes: Array[Node] = source.find_children("*", "MeshInstance3D", true, false)
	var near: MeshInstance3D
	for candidate: Node in meshes:
		if meshes.size() == 1 or candidate.name == "TreeLOD0":
			near = candidate as MeshInstance3D
	if near == null or texture == null:
		source.free()
		_fail("Expected a source tree mesh and billboard texture: " + output)
		return null
	near.get_parent().remove_child(near)
	source.free()
	var root := Node3D.new()
	root.name = "TreeLODs"
	near.name = "TreeLOD0"
	root.add_child(near)
	near.owner = root
	var card := MeshInstance3D.new()
	card.name = "TreeLOD1"
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(data.quad_size[0], data.quad_size[1])
	var centre: Array = data.views[0].quad_center_from_base_right_up
	quad.center_offset = Vector3(centre[0], centre[1] + data.bounds_blender_z_up.min[2], 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.billboard_keep_scale = true
	material.roughness = 1.0
	material.metallic_specular = 0.0
	_configure_billboard_lighting(material, near)
	quad.material = material
	card.mesh = quad
	root.add_child(card)
	card.owner = root
	var packed := PackedScene.new()
	var error := packed.pack(root)
	root.free()
	if error != OK or ResourceSaver.save(packed, output) != OK:
		_fail("Could not save billboard LOD scene: " + output)
		return null
	return ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene

func _configure_billboard_lighting(material: StandardMaterial3D, near: MeshInstance3D) -> void:
	var backlight := Color(0, 0, 0, 1)
	var leaf_materials: int = 0
	for surface: int in range(near.mesh.get_surface_count()):
		var source: Material = near.get_active_material(surface)
		var colour: Variant
		if source is ShaderMaterial:
			colour = source.get_shader_parameter("backlight")
		elif source is StandardMaterial3D and source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			colour = source.backlight if source.backlight_enabled else Color(0, 0, 0, 1)
		if colour is Color:
			backlight.r += colour.r
			backlight.g += colour.g
			backlight.b += colour.b
			leaf_materials += 1
	if leaf_materials > 0:
		var factor: float = BILLBOARD_BACKLIGHT_FACTOR / leaf_materials
		backlight.r *= factor
		backlight.g *= factor
		backlight.b *= factor
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	material.backlight_enabled = backlight.r + backlight.g + backlight.b > 0.0
	material.backlight = backlight
	material.disable_receive_shadows = true

func _refresh_billboard_lighting(packed: PackedScene, output: String) -> bool:
	var root: Node3D = packed.instantiate()
	var near: MeshInstance3D = root.get_node_or_null("TreeLOD0")
	var far: MeshInstance3D = root.get_node_or_null("TreeLOD1")
	var material: StandardMaterial3D = far.get_active_material(0) as StandardMaterial3D if far != null else null
	if near == null or material == null:
		root.free()
		_fail("Cannot update billboard lighting: " + output)
		return false
	# Materials are shared with the PackedScene state; preserve its node IDs and
	# near geometry while updating only the far card's material.
	_configure_billboard_lighting(material, near)
	var error: Error = ResourceSaver.save(packed, output)
	root.free()
	if error != OK:
		_fail("Could not save billboard lighting: " + output)
		return false
	return true

func _mesh_signature(mesh: Mesh) -> String:
	var textures: Array[String] = []
	for surface: int in range(mesh.get_surface_count()):
		var material: Material = mesh.surface_get_material(surface)
		var texture: Texture2D
		if material is ShaderMaterial:
			texture = material.get_shader_parameter("texture_albedo")
		elif material is StandardMaterial3D:
			texture = material.albedo_texture
		textures.append(texture.resource_path if texture != null else "")
	return JSON.stringify(textures)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
