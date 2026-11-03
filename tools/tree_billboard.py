#!/usr/bin/env python3
"""Bake TSCN/OBJ/glTF trees into transparent, unlit PNGs using background Blender.

Run with ordinary Python; Blender 4+ is the only external dependency.
See doc/tree-billboards.md for examples and the material-map format.
"""

import argparse
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def arguments(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mesh", type=Path, help="Source .tscn, .obj, .glb or .gltf")
    parser.add_argument("-o", "--output", type=Path, required=True, help="Output .png")
    parser.add_argument("--blender", default=os.environ.get("BLENDER", "blender"),
                        help="Blender executable (or set BLENDER)")
    parser.add_argument("--size", type=int, default=1024, help="Square image size (default: 1024)")
    parser.add_argument("--views", type=int, default=1, help="Evenly spaced azimuth views (default: 1)")
    parser.add_argument("--angle", type=float, default=0.0, help="Starting azimuth in degrees")
    parser.add_argument("--padding", type=float, default=0.04,
                        help="Minimum empty border on each side, as image fraction")
    parser.add_argument("--samples", type=int, default=32, help="Cycles CPU samples (default: 32)")
    parser.add_argument("--alpha-cutoff", type=float,
                        help="Override alpha cutout threshold (default: scene material, otherwise 0.5)")
    parser.add_argument("--material-map", type=Path,
                        help="JSON mapping material names to albedo textures, relative to that JSON")
    parser.add_argument("--obj-up", choices=("Y", "Z"), default="Y",
                        help="OBJ source up axis (default: Y, matching this project's trees)")
    parser.add_argument("--force", action="store_true", help="Replace existing generated files")
    args = parser.parse_args(argv)
    args.mesh = args.mesh.expanduser().resolve()
    args.output = args.output.expanduser().resolve()
    if args.material_map:
        args.material_map = args.material_map.expanduser().resolve()
    if not args.mesh.is_file():
        parser.error("Mesh does not exist: %s" % args.mesh)
    if args.mesh.suffix.lower() not in (".tscn", ".obj", ".glb", ".gltf"):
        parser.error("Supported source formats: .tscn, .obj, .glb, .gltf")
    if args.output.suffix.lower() != ".png":
        parser.error("Output must have a .png extension")
    if not 16 <= args.size <= 8192:
        parser.error("--size must be between 16 and 8192")
    if not 1 <= args.views <= 32 or args.samples < 1:
        parser.error("--views must be 1..32 and --samples must be positive")
    if not 0 <= args.padding < 0.45 or (args.alpha_cutoff is not None and not 0 <= args.alpha_cutoff < 1):
        parser.error("--padding must be 0..<0.45; --alpha-cutoff must be 0..<1")
    if not math.isfinite(args.angle):
        parser.error("--angle must be finite")
    if args.material_map and not args.material_map.is_file():
        parser.error("Material map does not exist: %s" % args.material_map)
    return args


def outputs(args):
    images = [args.output] if args.views == 1 else [
        args.output.with_name("%s_%02d.png" % (args.output.stem, i))
        for i in range(args.views)
    ]
    return images, args.output.with_suffix(".json")


def material_overrides(args):
    if not args.material_map:
        return {}
    mapping = json.loads(args.material_map.read_text())
    if not isinstance(mapping, dict):
        raise ValueError("Material map must be a JSON object of material-name: texture-path")
    result = {}
    for name, value in mapping.items():
        if not isinstance(value, str):
            raise ValueError("Texture path for %s must be a string" % name)
        texture = (args.material_map.parent / value).resolve()
        if not texture.is_file():
            raise ValueError("Missing texture for %s: %s" % (name, texture))
        result[name] = texture
    return result


def make_unlit(material, texture_path, cutoff, scene_material=None):
    """Keep imported base-colour/alpha graphs; replace lighting with emission."""
    import bpy

    material.use_nodes = True
    material.use_backface_culling = False
    nodes, links = material.node_tree.nodes, material.node_tree.links
    principled = next((node for node in nodes if node.type == "BSDF_PRINCIPLED"), None)
    output = next((node for node in nodes if node.type == "OUTPUT_MATERIAL" and node.is_active_output), None)
    if output is None:
        output = nodes.new("ShaderNodeOutputMaterial")
    colour = alpha = None
    colour_value = tuple(material.diffuse_color)
    alpha_value = colour_value[3]
    if principled:
        base = principled.inputs["Base Color"]
        opacity = principled.inputs["Alpha"]
        colour_value, alpha_value = tuple(base.default_value), opacity.default_value
        colour = base.links[0].from_socket if base.is_linked else None
        alpha = opacity.links[0].from_socket if opacity.is_linked else None
    elif not texture_path:
        raise ValueError("Material %r has no Principled BSDF; supply --material-map" % material.name)
    if texture_path:
        texture = nodes.new("ShaderNodeTexImage")
        texture.image = bpy.data.images.load(str(texture_path), check_existing=True)
        colour, alpha = texture.outputs["Color"], texture.outputs["Alpha"]
        if scene_material:
            scale, offset = scene_material["uv_scale"], scene_material["uv_offset"]
            if scale != [1, 1, 1] or offset != [0, 0, 0]:
                uv = nodes.new("ShaderNodeTexCoord")
                mapping = nodes.new("ShaderNodeVectorMath")
                mapping.operation = "MULTIPLY_ADD"
                mapping.inputs[1].default_value = scale
                mapping.inputs[2].default_value = offset
                links.new(uv.outputs["UV"], mapping.inputs[0])
                links.new(mapping.outputs[0], texture.inputs["Vector"])
    if scene_material:
        tint = scene_material["tint"]
        colour_value = tint
        alpha_value = tint[3] if scene_material["use_alpha"] else 1.0
        if colour and tint[:3] != [1, 1, 1]:
            multiply = nodes.new("ShaderNodeMixRGB")
            multiply.blend_type = "MULTIPLY"
            multiply.inputs[0].default_value = 1.0
            multiply.inputs[2].default_value = tint
            links.new(colour, multiply.inputs[1])
            colour = multiply.outputs[0]
        if not scene_material["use_alpha"]:
            alpha = None
        elif alpha and tint[3] != 1:
            multiply_alpha = nodes.new("ShaderNodeMath")
            multiply_alpha.operation = "MULTIPLY"
            multiply_alpha.inputs[1].default_value = tint[3]
            links.new(alpha, multiply_alpha.inputs[0])
            alpha = multiply_alpha.outputs[0]
    emission = nodes.new("ShaderNodeEmission")
    if colour:
        links.new(colour, emission.inputs["Color"])
    else:
        emission.inputs["Color"].default_value = colour_value
        print("WARNING: %s has constant colour; use --material-map if a texture is missing" % material.name)
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    cutout = nodes.new("ShaderNodeMath")
    cutout.operation = "GREATER_THAN"
    cutout.inputs[1].default_value = cutoff
    if alpha:
        links.new(alpha, cutout.inputs[0])
    else:
        cutout.inputs[0].default_value = alpha_value
    mix = nodes.new("ShaderNodeMixShader")
    links.new(cutout.outputs[0], mix.inputs[0])
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(emission.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], output.inputs["Surface"])


def bake(args):
    import bpy
    from mathutils import Matrix, Vector

    if bpy.app.version < (4, 0, 0):
        raise ValueError("Blender 4.0 or newer is required")
    mapping = material_overrides(args)
    source = args.scene_source
    source_mesh = source["mesh"] if source else args.mesh
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if source_mesh.suffix.lower() == ".obj":
        bpy.ops.wm.obj_import(filepath=str(source_mesh), up_axis=args.obj_up,
                              forward_axis="NEGATIVE_Z" if args.obj_up == "Y" else "Y")
    else:
        bpy.ops.import_scene.gltf(filepath=str(source_mesh))
    scene = bpy.context.scene
    meshes = [obj for obj in scene.objects if obj.type == "MESH" and not obj.hide_render]
    if not meshes:
        raise ValueError("Source contains no renderable meshes")
    # Input lights/cameras must not affect a colour-only bake.
    for obj in list(scene.objects):
        if obj.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(obj, do_unlink=True)
    materials = {slot.material for obj in meshes for slot in obj.material_slots if slot.material}
    missing = set(mapping) - {material.name for material in materials}
    if missing:
        raise ValueError("Unknown material names: %s. Available: %s" %
                         (sorted(missing), sorted(mat.name for mat in materials)))
    if any(not obj.material_slots or any(not slot.material for slot in obj.material_slots) for obj in meshes):
        raise ValueError("Every mesh surface needs a material")
    scene_materials = {}
    if source:
        scene_materials = {name: source["material_override"] or source["materials"].get(i)
                           for i, name in enumerate(source["material_names"])}
        scene_transform = Matrix.Identity(4)
        for path in sorted(source["transforms"], key=lambda p: (p.count("/"), p != ".")):
            scene_transform = scene_transform @ Matrix(source["transforms"][path])
        axes = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        scene_transform = axes @ scene_transform @ axes.inverted()
        for obj in meshes:
            obj.matrix_world = scene_transform @ obj.matrix_world
    for material in materials:
        spec = scene_materials.get(material.name)
        texture = mapping.get(material.name) or (spec["texture"] if spec else None)
        cutoff = args.alpha_cutoff if args.alpha_cutoff is not None else (spec["alpha_cutoff"] if spec else 0.5)
        make_unlit(material, texture, cutoff, spec)
    for image in bpy.data.images:
        if (image.source == "FILE" and not image.packed_file
                and not Path(bpy.path.abspath(image.filepath)).is_file()):
            raise ValueError("An imported texture could not be loaded: %s" % image.filepath)
    image_paths, metadata_path = outputs(args)
    source_textures = {Path(bpy.path.abspath(image.filepath)).resolve()
                       for image in bpy.data.images if image.source == "FILE"}
    if source_textures.intersection(image_paths + [metadata_path]):
        raise ValueError("Output would overwrite a source texture")

    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    corners = [obj.matrix_world @ Vector(corner) for source in meshes
               for obj in [source.evaluated_get(depsgraph)] for corner in obj.bound_box]
    lower = Vector(tuple(min(p[i] for p in corners) for i in range(3)))
    upper = Vector(tuple(max(p[i] for p in corners) for i in range(3)))
    if upper.z - lower.z <= 0:
        raise ValueError("Mesh has no vertical extent; check --obj-up")
    centre = (lower + upper) * 0.5
    base = Vector((0.0, 0.0, lower.z))
    angles = [math.radians(args.angle + i * 360.0 / args.views) for i in range(args.views)]
    rights = [Vector((math.cos(angle), math.sin(angle), 0.0)) for angle in angles]
    half_width = max(abs((p - centre).dot(right)) for p in corners for right in rights)
    scale = max(2.0 * half_width, upper.z - lower.z) / (1.0 - 2.0 * args.padding)
    distance = max((upper - lower).length * 2.0, 1.0)

    camera_data = bpy.data.cameras.new("BillboardCamera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = scale
    camera_data.clip_start = distance * 0.001
    camera_data.clip_end = distance * 4.0
    camera = bpy.data.objects.new("BillboardCamera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = args.samples
    scene.cycles.use_denoising = False
    # Leaf cards overlap many times; avoid prematurely terminating transparent rays.
    scene.cycles.transparent_max_bounces = 128
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = args.size
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = scene.render.pixel_aspect_y = 1.0
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
    scene.render.use_compositing = False
    scene.render.use_sequencer = False
    args.output.parent.mkdir(parents=True, exist_ok=True)
    views = []
    for index, (angle, right, image_path) in enumerate(zip(angles, rights, image_paths)):
        direction = Vector((math.sin(angle), -math.cos(angle), 0.0))
        camera.location = centre + direction * distance
        camera.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(image_path)
        bpy.ops.render.render(write_still=True)
        views.append({
            "image": image_path.name,
            "azimuth_degrees": (args.angle + index * 360.0 / args.views) % 360.0,
            "pivot_uv_bottom_left": [0.5 + (base - centre).dot(right) / scale,
                                     0.5 + (base.z - centre.z) / scale],
            "quad_center_from_base_right_up": [(centre - base).dot(right), centre.z - base.z],
        })
    metadata = {
        "source": str(args.mesh), "mesh": str(source_mesh), "image_size": [args.size, args.size],
        "quad_size": [scale, scale], "tree_height": upper.z - lower.z,
        "units": "source mesh units (metres if source is metre-scaled)",
        "shading": "unlit albedo, double sided, alpha cutout, no baked shadows",
        "alpha_cutoff": args.alpha_cutoff,
        "scene_materials": {name: dict(spec, texture=str(spec["texture"]) if spec["texture"] else None)
                            for name, spec in scene_materials.items() if spec},
        "camera": "orthographic, horizontal; 0 degrees looks from Blender -Y towards +Y",
        "pivot": "source origin X/Y at lowest mesh Z, after import into Blender Z-up",
        "bounds_blender_z_up": {"min": list(lower), "max": list(upper)},
        "views": views,
    }
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n")
    print("Billboard bake complete: %s" % metadata_path)


def main(argv=None):
    worker = argv is None and "--" in sys.argv and "--billboard-worker" in sys.argv
    if worker:
        argv = sys.argv[sys.argv.index("--") + 1:]
        argv.remove("--billboard-worker")
    args = arguments(sys.argv[1:] if argv is None else argv)
    args.scene_source = None
    if args.mesh.suffix.lower() == ".tscn":
        if args.obj_up != "Y":
            raise ValueError("Godot scenes use Y-up; --obj-up Z is only for raw OBJ inputs")
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        from godot_tree_source import resolve_tree_scene
        args.scene_source = resolve_tree_scene(args.mesh)
    images, metadata = outputs(args)
    existing = [str(path) for path in images + [metadata] if path.exists()]
    if existing and not args.force:
        raise ValueError("Output already exists; choose another name or use --force: %s" % existing)
    if args.mesh in images + [metadata] or args.material_map in images + [metadata]:
        raise ValueError("Output would overwrite an input file")
    material_overrides(args)  # Fail early, before starting Blender.
    if worker:
        bake(args)
        return 0
    blender = shutil.which(args.blender)
    if not blender:
        raise ValueError("Blender not found. Pass --blender /path/to/blender or set BLENDER")
    # Argument arrays preserve spaces and never invoke a shell. All scene changes
    # happen in a disposable background process; no open Blender session is touched.
    command = [blender, "--background", "--factory-startup", "--disable-autoexec",
               "--python-exit-code", "1", "--python", str(Path(__file__).resolve()),
               "--", "--billboard-worker"] + list(sys.argv[1:] if argv is None else argv)
    with tempfile.TemporaryDirectory(prefix="tree-billboard-") as temporary:
        environment = os.environ.copy()
        for resource in ("CONFIG", "SCRIPTS", "DATAFILES", "EXTENSIONS"):
            directory = Path(temporary) / resource.lower()
            directory.mkdir()
            environment["BLENDER_USER_" + resource] = str(directory)
        return subprocess.run(command, check=False, env=environment).returncode


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError) as error:
        print("ERROR: %s" % error, file=sys.stderr)
        sys.exit(1)
