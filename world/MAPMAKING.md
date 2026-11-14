

### Re-Generate Vegetation Billboards

```bash
python3 /home/cornelinux/.godotproj/hinterland-tycoon/tools/billboards/tree_billboard.py \
  /home/cornelinux/.godotproj/hinterland-tycoon/assets/meshes/nature/tree2_oak/tree2_oak.tscn \
  --blender /home/cornelinux/Apps/Blender5/blender \
  --output /home/cornelinux/.godotproj/hinterland-tycoon/assets/meshes/nature/tree2_oak/billboard_oak.png \
  --size 512 --force
```

```bash```
/home/cornelinux/Apps/Godot_v4.7.2-stable_linux.x86_64 \
  --headless \
  --path /home/cornelinux/.godotproj/hinterland-tycoon \
  --script res://tools/billboards/configure_tree_billboards.gd \
  -- --no-mcp --rebuild-scenes
```

### Regenerate Mineral Maps

Open a world scene and select **EditorObjects → EditorResourceTraces** in the
scene tree. Set **Metres Per Pixel** if needed (default **4**) and click
**Regenerate Mineral Maps**. The editor uses the terrain and paint currently
loaded in the open scene.

The command-line tool reads the saved map. Run it from the project root with
the world key.

```bash
tools/minerals/generate-minerals.sh mpsb
```

Both write the mineral PNGs and `minerals.json` to
`.godot/mineral-maps/<world>` by default. The JSON records the world X/Z
origin, image size, sampling resolution, and richness counts. The images are
previews of the same seeded geology sampled during gameplay.
