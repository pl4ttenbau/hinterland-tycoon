# Place the world cursor from GPS

Open the world scene (a `WorldMapScene`), select its `WorldCursor3D`, and enter decimal **latitude, longitude** under **GPS** in the Inspector. Click **From GPS Coords**. The cursor moves to that location and samples the open Terrain3D for its height; a running game world is not required. **Put On Ground** resamples terrain at the current cursor position, including zero and negative heights.

The world scene's `map_key` must match a folder under `res://world`, with GPS metadata in `jsondata/mapinfo.json`. For this new map, the key is `gdansk`. The scene's exported `terrain` reference is preferred; nested Terrain3D nodes with other names are also supported.

For area A, useful town-centre reference points from the downloaded OpenStreetMap extract are:

| Place | Paste into GPS |
| --- | --- |
| Nowy Dwór Gdański | `54.2146299, 19.1150846` |
| Nowy Staw | `54.1342754, 19.0086861` |
| Tczew | `54.0865756, 18.7936245` |
| Former Gdańsk narrow-gauge station | `54.346686, 18.672508` |

Gdańsk's central place marker is west of area A and will be rejected as outside the selected bounds. These are reference points for placement, not historical town footprints.

## Coordinate convention

`longLat.topLeft` and `bottomRight` store `[latitude, longitude]` at the outer heightmap sample centres. An N-sample edge has N−1 intervals. Longitude increases along world X, and latitude decreases along world Z. Fractional sample positions are preserved.

`rasterOffset` is the imported sample origin, in the same sample-coordinate units as Terrain3D's importer `import_position`, not metres. It must match the actual terrain import location, including any centred/negative offset. Conversion applies that offset and then multiplies by `Terrain3D.vertex_spacing`. The cursor sets its global position, so moving a cursor parent does not offset the result.

Invalid coordinate text, missing/degenerate metadata, coordinates outside the GPS bounds, or missing terrain height leave the cursor unchanged and report a warning. The conversion utility returns `Vector2(INF, INF)` for a failed conversion rather than a valid-looking origin.

## Regression checks

```sh
godot --headless --path . --script res://tests/gps_cursor_test.gd -- --no-mcp
```

The suite covers rectangular rasters, all four corners, offsets, fractional positions, the real Gdańsk bounds, a Nowy Dwór reference point, malformed input, missing metadata, absent terrain, negative terrain heights, non-default vertex spacing, transformed cursor parents and nested terrain lookup.

The current Gdańsk terrain is imported at sample offset `[-1800, -1800]` with vertex spacing 1. The map metadata records that offset; town coordinates are therefore centred around the world origin.
