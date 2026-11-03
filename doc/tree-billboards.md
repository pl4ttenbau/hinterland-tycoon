# Tree billboard textures

`tools/tree_billboard.py` uses Blender 4+ in a separate background process to
render a mesh into a transparent PNG. Run it with ordinary Python 3.8+; no pip
packages are needed. It does not change source assets, map scenes, or an open
Blender session. Blender must be on PATH, supplied through `--blender`, or set in
the `BLENDER` environment variable.

## Examples

Run from the project root. This machine's Blender is at
`/home/cornelinux/Apps/Blender5/blender`.

```sh
python3 tools/tree_billboard.py \
  assets/meshes/nature/tree2_oak/tree2_oak.obj \
  --material-map tools/billboard_materials/oak.json \
  --blender /home/cornelinux/Apps/Blender5/blender \
  --output /tmp/tree_billboards/oak.png
```

The fir's OBJ/MTL already has texture assignments, so no mapping is required:

```sh
python3 tools/tree_billboard.py \
  assets/meshes/nature/tree1_fir/tree1.obj \
  --blender /home/cornelinux/Apps/Blender5/blender \
  --output /tmp/tree_billboards/fir.png
```

Use `--views 4` to render four directions spaced 90 degrees apart. This writes
`oak_00.png` through `oak_03.png` and one `oak.json`; it does not pack an atlas or
select views at runtime. `--angle 45` changes the starting azimuth. Every image
shares the same orthographic scale, so trees do not change size between views.
`--size 512` makes smaller textures. Existing outputs require `--force` to replace.

## Materials and rendering

Inputs are `.obj`, `.glb`, and `.gltf`. OBJ defaults to Y-up (as used by these
trees); use `--obj-up Z` for Z-up source models. glTF has a defined coordinate
system and needs no axis setting. Supply a source containing one tree at one
detail level, with any trunk/leaf submeshes. Files containing several visible
LODs will render all of them together. Godot `.tscn` scenes and their shaders
are not interpreted.

The bake keeps both sides of leaf cards visible, extracts imported Principled
BSDF base colour and alpha, and renders those with emission and transparent
shaders. There is no baked lighting, wind, ground, or shadow. Materials without
textures generate a warning. Missing files and unknown mapping names fail with
an error. Other custom shader graphs need explicit texture mappings.

For missing or Godot-only material assignments, provide a JSON object mapping
each imported material name to its albedo texture. Paths are relative to the JSON:

```json
{
  "bark_material": "../textures/bark.png",
  "leaves_material": "../textures/leaves.png"
}
```

Texture alpha supplies the leaf silhouette. `--alpha-cutoff 0.5` is the default,
matching the oak's leaf material; adjust for other species. Texture alpha is
thresholded before antialiasing, so this is intended for opaque bark and cutout
leaves, not glass or translucent materials. CPU Cycles rendering works without
a GPU/display. `--samples 32` controls edge quality and render time. Standard
colour management avoids baking an AgX contrast/exposure treatment into albedo.

## Placement in Godot

The companion JSON includes square quad dimensions, actual tree height, bounds,
and a base pivot for every view. Dimensions use source mesh units, so an extra
scene scale applied only in Godot must also be applied to the billboard.
`quad_size` includes transparent padding: use this size for the quad rather than
stretching the visible tree to the full image. `quad_center_from_base_right_up`
gives the quad centre relative to the trunk base in view-right and up units.
`pivot_uv_bottom_left` is the same base point in bottom-left UV coordinates;
for top-left image coordinates use `1 - v`.

Use a material with the PNG as albedo, alpha scissor, and a billboard mode that
keeps the tree upright (fixed Y). Let the game light this albedo texture; using
an unshaded material in game would keep the tree equally bright at night.
Check alpha-border fixing and mipmaps in the Godot texture import settings to
avoid dark outlines. Keep detailed meshes nearby and introduce billboards at
distance. This tool generates textures and metadata only; runtime LOD wiring,
view selection and a simplified shadow caster are separate steps.
