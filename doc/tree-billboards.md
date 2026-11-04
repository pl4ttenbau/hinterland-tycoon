# Tree billboard textures

`tools/billboards/tree_billboard.py` uses Blender 4+ in a separate background process to
render a mesh into a transparent PNG. Run it with ordinary Python 3.8+; no pip
packages are needed. It does not change source assets, map scenes, or an open
Blender session. Blender must be on PATH, supplied through `--blender`, or set in
the `BLENDER` environment variable.

Billboard tooling is grouped under `tools/billboards/`: the Python generator,
its scene reader, the Godot configuration script, and optional material maps in
`material_maps/`. Generated PNGs, metadata and LOD scenes stay with the tree assets.

## Examples

Run from the project root. This machine's Blender is at
`/home/cornelinux/Apps/Blender5/blender`.

```sh
python3 tools/billboards/tree_billboard.py \
  assets/meshes/nature/tree2_oak/tree2_oak.tscn \
  --blender /home/cornelinux/Apps/Blender5/blender \
  --output /tmp/tree_billboards/oak.png
```

The scene resolves the OBJ and its material overrides automatically. The fir
works the same way, with no material JSON required:

```sh
python3 tools/billboards/tree_billboard.py \
  assets/meshes/nature/tree1_fir/tree1_fir.tscn \
  --blender /home/cornelinux/Apps/Blender5/blender \
  --output /tmp/tree_billboards/fir.png
```

Use `--views 4` to render four directions spaced 90 degrees apart. This writes
`oak_00.png` through `oak_03.png` and one `oak.json`; it does not pack an atlas or
select views at runtime. `--angle 45` changes the starting azimuth. Every image
shares the same orthographic scale, so trees do not change size between views.
`--size 512` makes smaller textures. Existing outputs require `--force` to replace.

## Materials and rendering

Inputs are `.tscn`, `.obj`, `.glb`, and `.gltf`. OBJ defaults to Y-up (as used by these
trees); use `--obj-up Z` for Z-up source models. glTF has a defined coordinate
system and needs no axis setting. Supply a source containing one tree at one
detail level, with any trunk/leaf submeshes. Files containing several visible
LODs will render all of them together.

TSCN input follows nested tree scenes or a direct OBJ mesh reference to one named
OBJ object, resolves `res://`
from the enclosing `project.godot`, and uses the scene's per-surface or global
material overrides instead of the OBJ's MTL assignments. Inline and text `.tres`
materials are supported, including albedo textures/colours, cutout thresholds,
and UV scale/offset. Outer scene overrides take precedence. Saved `Transform3D`,
position and positive scale are applied. Separate nonzero rotation properties,
multiple tree instances, embedded meshes and non-OBJ scene sources fail explicitly.
All seven existing tree species and their wrappers are supported. This is a static
scene reader: arbitrary Godot shader code, wind and procedural canopy shading
are not executed in Blender.

The bake keeps both sides of leaf cards visible, extracts imported Principled
BSDF base colour and alpha, and renders those with emission and transparent
shaders. There is no baked lighting, wind, ground, or shadow. Materials without
textures generate a warning. Missing files and unknown mapping names fail with
an error. Other custom shader graphs need explicit texture mappings.

For raw mesh inputs, or an explicit texture override, provide a JSON object mapping
each imported material name to its albedo texture. Paths are relative to the JSON:

```json
{
  "bark_material": "../textures/bark.png",
  "leaves_material": "../textures/leaves.png"
}
```

Texture alpha supplies the leaf silhouette. TSCN input uses each material's
cutout threshold; raw meshes default to 0.5. `--alpha-cutoff` overrides these.
Texture alpha is
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
distance.

## Installed tree LODs

All four map Terrain3D asset libraries now use billboard LODs for their existing
oak, fir, chestnut, apple, pine, birch and lilac entries. Harzmountains has no
chestnut entry, so it uses six species; the other maps use seven. No trees are
added or moved. LOD0 preserves the original detailed tree and its
previous distance (128 m, or 200 m for fir on Franzburger/Harzmountains). LOD1 is
a single upright camera-facing quad (two triangles) with a 512-pixel alpha-cutout
texture, visible to **350 m**. Only LOD0 casts shadows. Other asset types retain
their existing ranges. Embedded chestnut scenes get a dedicated LOD scene in
the species' `assets/meshes/nature/` folder, preserving their own near geometry
and materials. Map variants include the map name and asset ID in their filename;
MPSB uses `tree3_kastanie/billboard_lods_chestnut_mpsb_8.tscn`.
This is an initial range budget, not a measured FPS improvement.

Billboard materials use Lambert wrap diffuse lighting and a reduced average of
the source leaf materials' backlight (`BILLBOARD_BACKLIGHT_FACTOR`, currently
0.67). This approximates the light response of a volume of leaves instead of
shading the whole crown as one dark flat plane. The cards remain lit by the
scene, with no emission, and do not receive shadows. The updater refreshes these
lighting properties on existing LOD scenes without rebuilding near geometry or
rebaking textures. It saves map asset libraries only when their LOD settings
actually change.

To refresh the installed textures, bake each original tree scene with
`--size 512 --force`. The scene and output basenames below are relative to
`assets/meshes/nature/`:

| Original scene | Output texture |
| --- | --- |
| `tree2_oak/tree2_oak.tscn` | `tree2_oak/billboard_oak.png` |
| `tree1_fir/tree1_fir.tscn` | `tree1_fir/billboard_fir.png` |
| `tree3_kastanie/tree3_kastanie.tscn` | `tree3_kastanie/billboard_chestnut.png` |
| `tree4_apple/tree4_apple.tscn` | `tree4_apple/billboard_apple.png` |
| `tree5_pine/deco_tree5_pine.tscn` | `tree5_pine/billboard_pine.png` |
| `tree6_birch/deco_tree6_birch.tscn` | `tree6_birch/billboard_birch.png` |
| `lilac_tree_1/lilac_tree_1.tscn` | `lilac_tree_1/billboard_lilac.png` |

Let Godot import the PNGs, then rebuild the LOD scenes and apply the map settings:

```sh
godot --headless --path . --script res://tools/billboards/configure_tree_billboards.gd -- --no-mcp
```

The updater preserves the current LOD0 distance and reuses existing LOD scenes.
Add `--rebuild-scenes` after `--` to refresh their geometry after source changes.
`FAR_DISTANCE` in that script
controls the shared billboard cutoff. Frame time in representative forests
should guide changes to this range; extra distance still increases visible tree
instances and alpha overdraw. Multi-angle runtime view selection and a
simplified shadow caster are separate steps.
