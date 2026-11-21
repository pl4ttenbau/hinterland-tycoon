# Selective terrain height compression

Applied on 2026-11-08 first to the **Wiślinka phosphogypsum pile**, then to the **Sobieszewo dune belt** after the pile was accepted. Southwest hills remain deferred. No backups were created.

The saved Terrain3D height maps were edited directly, without reimporting or modifying the source EXR. The pile's peak changed from **Y 49.94706 to Y 27.58941** (35.29917 to 12.94152 above the existing water plane at Y 14.647888). Exactly 2,127 terrain samples changed, in two region files. All other 255 region files, every texture-control and colour map, and every unselected height sample were verified unchanged. See `wislinka_pile_validation.json`.

## Method

This is a monotonic remapping of elevation, not spatial smoothing. Heights at or below **Y 20** are bit-for-bit unchanged, preserving flat terrain, water, riverbeds and low banks. From Y 20 to Y 24, a quadratic transition gradually changes the slope of the height function from 1 to 0.2. Above Y 24, each additional metre of original height contributes 0.2 metres to the result. No neighbouring height samples are averaged. This preserves the pile's plan shape and fine relief while lowering its upper portion. For a rectangular selection, the boundary must lie entirely below the unchanged-height threshold. Polygon selections instead use a smooth boundary weight so the operation can end naturally beside connected high ground without an abrupt edge.

## Reuse

`compress_heights.gd` defaults to `wislinka_pile.json`. Run it with a different JSON configuration through `--config=res://world/gdansk/source/selective_height_compression/your_feature.json`. Inspect first without `--apply`; add `--apply` to save. A headless project with the Terrain3D extension loaded is sufficient. The working isolated project used here was `/tmp/gdansk_roads_probe`; the actual world data is shared through its `world` symlink.

For another feature, set its world X/Z selection bounds, unchanged-height threshold, transition height and upper-height factor. Supply the intersecting region filenames, integer region locations and their **current** SHA-256 hashes. Reusing stale hashes is intentionally rejected, preventing accidental double compression or overwriting intervening edits. Keep bounds outside the feature's raised terrain. The helper reloads each saved region and verifies heights, colour and texture controls. Settings and validation are persistent records; original region data is not archived.

Example command for a prepared isolated project:

```sh
XDG_DATA_HOME=/tmp/gdansk_roads_probe/userdata /home/cornelinux/Apps/Godot_v4.7.2-stable_linux.x86_64 --headless --path /tmp/gdansk_roads_probe --script res://world/gdansk/source/selective_height_compression/compress_heights.gd -- --config=res://world/gdansk/source/selective_height_compression/your_feature.json
```

After the dry-run output is satisfactory, append `--apply`. The original pile configuration has already been applied and will now correctly reject another run because its input hashes no longer match.

## Sobieszewo dunes — second pass

`sobieszewo_dunes.json` reuses the accepted pile curve (unchanged below Y20; 4-unit vertical transition; upper height factor 0.2). A polygon follows the island dune belt and excludes the pile, southwest hills and the embankment extending south of the dunes. The change tapers to zero over 10 game units inside the polygon edge. This is blending the amount of vertical reduction, not averaging or blurring terrain samples.

Peak within the treated selection: **Y 41.64737 → Y 30.75763**. The boundary transition retains more height near the eastern connection; core ridges receive the full curve. A total of **35,370** samples changed in **nine** region files. Native reload verification confirmed exact expected height data and unchanged texture-control/colour maps. The other **248** region files and the source EXR were unchanged. The pile's samples lie outside the dune selection and were preserved, including within the shared region file. See `sobieszewo_dunes_validation.json` for the saved results.
