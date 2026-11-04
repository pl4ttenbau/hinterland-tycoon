"""Read the static, single-OBJ tree scenes used by this project (no Godot needed).

This deliberately resolves a small TSCN subset, not arbitrary Godot scenes or
shader programs. Unsupported geometry/layouts fail rather than baking the wrong
tree. Node paths, surface indices and outer material overrides are significant.
"""

import copy
import json
import math
from pathlib import Path
import re


IDENTITY = ((1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1))
STRING = r'"(?:[^"\\]|\\.)*"'


def sections(path):
    result = []
    current = None
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        header = re.fullmatch(r"\[([a-z_]+)(.*?)\]\s*", line)
        if header:
            attributes = {}
            pattern = r'(\w+)\s*=\s*(' + STRING + r'|(?:ExtResource|SubResource)\(' + STRING + r'\)|[^\s]+)'
            for key, value in re.findall(pattern, header[2]):
                attributes[key] = json.loads(value) if value.startswith('"') else value
            current = {"kind": header[1], "attributes": attributes, "properties": {}}
            result.append(current)
        elif current:
            prop = re.match(r"\s*([\w/]+)\s*=\s*(.*?)\s*$", line)
            if prop:
                current["properties"][prop[1]] = prop[2]
    return result


def values(value, constructor, count):
    match = re.fullmatch(re.escape(constructor) + r"\(([^()]*)\)", value)
    if match:
        numbers = [float(part.strip()) for part in match[1].split(",")]
        if len(numbers) == count and all(math.isfinite(number) for number in numbers):
            return numbers
    raise ValueError("Expected %s with %d finite components: %s" % (constructor, count, value))


def resource_path(value, owner, root):
    if value.startswith("res://"):
        path = root / value[6:]
    elif "://" in value:
        raise ValueError("Need a file path, not a UID-only resource: %s in %s" % (value, owner))
    else:
        path = owner.parent / value
    path = path.resolve()
    if not path.is_file():
        raise ValueError("Missing scene dependency: %s (from %s)" % (path, owner))
    return path


def tables(parts):
    external = {part["attributes"]["id"]: part for part in parts if part["kind"] == "ext_resource"}
    internal = {part["attributes"]["id"]: part for part in parts if part["kind"] == "sub_resource"}
    return external, internal


def reference(value, external, internal):
    match = re.fullmatch(r'(ExtResource|SubResource)\((' + STRING + r')\)', value)
    if not match:
        raise ValueError("Unsupported resource reference: %s" % value)
    table = external if match[1] == "ExtResource" else internal
    key = json.loads(match[2])
    if key not in table:
        raise ValueError("Unknown resource ID: %s" % key)
    return table[key]


def material(value, external, internal, owner, root):
    part = reference(value, external, internal)
    if part["kind"] == "ext_resource":
        path = resource_path(part["attributes"]["path"], owner, root)
        if path.suffix != ".tres":
            raise ValueError("Scene materials must be inline or text .tres resources: %s" % path)
        parts = sections(path)
        external, internal = tables(parts)
        header = next(p for p in parts if p["kind"] == "gd_resource")
        part = next(p for p in parts if p["kind"] == "resource")
        part = dict(part, attributes=header["attributes"])
        owner = path
    kind, props = part["attributes"].get("type"), part["properties"]
    if kind not in ("ShaderMaterial", "StandardMaterial3D"):
        raise ValueError("Unsupported tree material type: %s in %s" % (kind, owner))
    shader = kind == "ShaderMaterial"
    texture_key = "shader_parameter/texture_albedo" if shader else "albedo_texture"
    tint_key = "shader_parameter/albedo" if shader else "albedo_color"
    texture = None
    if props.get(texture_key, "null") != "null":
        texture_part = reference(props[texture_key], external, internal)
        if texture_part["kind"] != "ext_resource":
            raise ValueError("Albedo must reference an external texture file in %s" % owner)
        texture = resource_path(texture_part["attributes"]["path"], owner, root)
    if shader and texture is None:
        raise ValueError("ShaderMaterial needs an explicit texture_albedo parameter in %s" % owner)
    cutoff_key = "shader_parameter/alpha_scissor_threshold" if shader else "alpha_scissor_threshold"
    cutoff = float(props.get(cutoff_key, "0.5"))
    if not math.isfinite(cutoff) or not 0 <= cutoff < 1:
        raise ValueError("Invalid alpha scissor threshold in %s" % owner)
    if not shader and int(props.get("transparency", "0")) not in (0, 2):
        raise ValueError("Only opaque and alpha-scissor StandardMaterial3D are supported: %s" % owner)
    return {
        "texture": texture,
        "tint": values(props.get(tint_key, "Color(1, 1, 1, 1)"), "Color", 4),
        "alpha_cutoff": cutoff,
        "use_alpha": shader or int(props.get("transparency", "0")) == 2,
        "uv_scale": values(props.get("shader_parameter/uv1_scale" if shader else "uv1_scale",
                                     "Vector3(1, 1, 1)"), "Vector3", 3),
        "uv_offset": values(props.get("shader_parameter/uv1_offset" if shader else "uv1_offset",
                                      "Vector3(0, 0, 0)"), "Vector3", 3),
    }


def obj_source(path):
    objects, materials = set(), []
    active_material = None
    for line in path.read_text().splitlines():
        if line.startswith("o "):
            objects.add(line[2:].strip())
        elif line.startswith("usemtl "):
            active_material = line[7:].strip()
        elif line.startswith("f ") and active_material not in materials:
            materials.append(active_material)
    if len(objects) != 1 or not materials or None in materials:
        raise ValueError("TSCN baking currently needs one named OBJ object with named materials: %s" % path)
    return {"mesh": path, "mesh_node": next(iter(objects)), "material_names": materials,
            "materials": {}, "material_override": None, "transforms": {}, "scene_files": []}


def node_path(attributes):
    if "parent" not in attributes:
        return "."
    parent = attributes["parent"]
    return attributes["name"] if parent == "." else parent + "/" + attributes["name"]


def prefix_path(prefix, path):
    if prefix == ".":
        return path
    return prefix if path == "." else prefix + "/" + path


def transform(properties, previous):
    matrix = [list(row) for row in previous]
    if "transform" in properties:
        v = values(properties["transform"], "Transform3D", 12)
        matrix = [[v[0], v[3], v[6], v[9]], [v[1], v[4], v[7], v[10]],
                  [v[2], v[5], v[8], v[11]], [0, 0, 0, 1]]
    if "rotation" in properties and any(values(properties["rotation"], "Vector3", 3)):
        raise ValueError("Use a saved Transform3D instead of a separate rotation property in tree scenes")
    if "position" in properties:
        for i, value in enumerate(values(properties["position"], "Vector3", 3)):
            matrix[i][3] = value
    if "scale" in properties:
        for j, scale in enumerate(values(properties["scale"], "Vector3", 3)):
            length = math.sqrt(sum(matrix[i][j] ** 2 for i in range(3)))
            if length == 0 or scale <= 0:
                raise ValueError("Scene scale must be positive and nonzero")
            for i in range(3):
                matrix[i][j] *= scale / length
    return matrix


def resolve_tree_scene(path, root=None, stack=()):
    path = Path(path).resolve()
    if root is None:
        root = next((p for p in path.parents if (p / "project.godot").is_file()), None)
        if root is None:
            raise ValueError("Cannot resolve res:// without a project.godot above %s" % path)
    if path in stack:
        raise ValueError("Cyclic tree scene reference: %s" % path)
    if path.suffix.lower() == ".obj":
        return obj_source(path)
    if path.suffix.lower() != ".tscn":
        raise ValueError("TSCN tree scenes must ultimately instance an OBJ, not %s" % path)
    parts = sections(path)
    external, internal = tables(parts)
    nodes = [p for p in parts if p["kind"] == "node"]
    instances = [node for node in nodes if "instance" in node["attributes"]]
    direct_meshes = [node for node in nodes if "mesh" in node["properties"]]
    if len(instances) + len(direct_meshes) != 1:
        raise ValueError("Expected one instanced tree or OBJ mesh per scene in %s" % path)
    direct = bool(direct_meshes)
    if direct:
        instances = direct_meshes
    instance = instances[0]
    source = reference(instance["properties"]["mesh"] if direct else instance["attributes"]["instance"], external, internal)
    if source["kind"] != "ext_resource":
        raise ValueError("Expected an external tree scene or OBJ in %s" % path)
    mesh_path = resource_path(source["attributes"]["path"], path, root)
    tree = copy.deepcopy(resolve_tree_scene(mesh_path, root, stack + (path,)))
    mount = node_path(instance["attributes"])
    tree["mesh_node"] = mount if direct else prefix_path(mount, tree["mesh_node"])
    tree["transforms"] = {prefix_path(mount, key): value for key, value in tree["transforms"].items()}
    tree["scene_files"].append(path)
    for node in nodes:
        target, props = node_path(node["attributes"]), node["properties"]
        on_branch = target == "." or target == tree["mesh_node"] or tree["mesh_node"].startswith(target + "/")
        if not on_branch:
            raise ValueError("Extra scene nodes are unsupported in a single-tree bake: %s in %s" % (target, path))
        if props.get("visible") == "false":
            raise ValueError("The requested tree is hidden in %s" % path)
        tree["transforms"][target] = transform(props, tree["transforms"].get(target, IDENTITY))
        for key, value in props.items():
            if key != "material_override" and not key.startswith("surface_material_override/"):
                continue
            if target != tree["mesh_node"]:
                raise ValueError("Material override does not target the OBJ mesh: %s in %s" % (target, path))
            spec = None if value == "null" else material(value, external, internal, path, root)
            if key == "material_override":
                tree["material_override"] = spec
            else:
                index = int(key.rsplit("/", 1)[1])
                if not 0 <= index < len(tree["material_names"]):
                    raise ValueError("Invalid OBJ surface index %d in %s" % (index, path))
                if spec is None:
                    tree["materials"].pop(index, None)
                else:
                    tree["materials"][index] = spec
    return tree
