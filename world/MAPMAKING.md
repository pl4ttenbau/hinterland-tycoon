

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
