"""Run with Blender --background SOURCE.blend --python THIS_SCRIPT.

Export the approved merged master without saving or modifying the source file.
The only game adjustment is centering the coupler envelope longitudinally.
"""
import hashlib
import json
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/meshes/vehicles/rail/harz_99_23_24/mesh"
SOURCE = Path(bpy.data.filepath)
source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
assert len(objects) == 1, "Merge the approved source before importing a vehicle"
obj = objects[0]
obj.data.calc_loop_triangles()
assert len(obj.data.loop_triangles) == 17031
assert len(obj.data.materials) == 1
assert bpy.context.scene.unit_settings.scale_length == 1.0
points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
bounds = [[min(p[i] for p in points), max(p[i] for p in points)] for i in range(3)]
center_y = sum(bounds[1]) / 2.0
obj.location.y -= center_y
# The master has a legacy UV map as well as the atlas. Export only the map
# actually used by its material, so all maps use Godot's primary UV channel.
uv_nodes = [n for n in obj.data.materials[0].node_tree.nodes if n.type == "UVMAP"]
assert len(uv_nodes) == 1
atlas_uv = uv_nodes[0].uv_map
assert atlas_uv in obj.data.uv_layers
for layer in list(obj.data.uv_layers):
    if layer.name != atlas_uv:
        obj.data.uv_layers.remove(layer)
obj.data.uv_layers.active_index = 0
obj.data.uv_layers[0].active_render = True
bpy.ops.object.select_all(action="DESELECT")
obj.hide_set(False)
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
DEST.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(DEST / "harz_99_23_24.gltf"),
    export_format="GLTF_SEPARATE", use_selection=True, export_yup=True,
    export_materials="EXPORT", export_texcoords=True, export_normals=True,
    export_tangents=True, export_animations=False, export_cameras=False,
    export_lights=False,
)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == source_hash
report = {
    "source": str(SOURCE), "source_sha256": source_hash,
    "triangles": len(obj.data.loop_triangles), "materials": 1,
    "source_bounds_xyz": bounds, "centering_blender_y": -center_y,
    "godot_forward": "-Z (Blender +Y)", "metres_per_unit": 1.0,
    "coupler_envelope_length_metres": bounds[1][1] - bounds[1][0],
    "textures": [{"name": image.name, "size": list(image.size)}
                 for image in bpy.data.images if image.packed_file],
}
(DEST.parent / "import_report.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
