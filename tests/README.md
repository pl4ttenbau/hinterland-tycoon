Headless regression checks run with Godot 4.7 from the project root:

Infrastructure smoothing checks:

```sh
godot --headless --path . --log-file /tmp/infr-smoothing-tests.log --script res://tests/infr_smoothing_test.gd -- --no-mcp
```

These compare the generated Bezier curve with an independent centripetal Catmull-Rom evaluator and cover open endpoints, uneven point spacing, repeated points, recalculation after editing, Y-only smoothing, legacy mirrored handles, road/rail JSON round trips, and the road `autosmooth` option. Success prints `Infrastructure smoothing tests: 141 checks, 0 failures` and exits 0. Full smoothing recalculates handles without moving points; import preserves existing nonzero handle pairs. JSON now stores independent `handleIn` and `handleOut` arrays, including endpoint handles; older `handleIn`-only data still loads with mirrored outgoing handles.

Train path regression command:

```sh
godot --headless --path . --log-file /tmp/train-path-tests.log res://tests/train_path_test.tscn -- --no-mcp
```

The scene exits with code 1 if a check fails. It builds a small rail network without terrain or vehicle meshes and exercises the real movement and fork-setting code. Checks cover continuous junction headings, rotation between nodes, last-moment switching, preserved approach geometry, occupied-switch derailment, stationary trains, wagon spacing, exact reversal, reversed track connections, buffers, and listener cleanup.

The current project also reports an unresolved `EditorSignals` autoload UID and existing shutdown resource warnings. These are independent of the train checks; a passing test prints `Train path tests: 0 failures`.

Visual review is still needed on the game map, especially wheel/rail alignment at sharp junctions: joining the movement curve aligns the outgoing handle with the incoming heading, while the rendered track geometry remains unchanged. Junction occupancy currently uses vehicle lengths around their curve positions; it does not model a switch's physical footprint or bogies.

Type catalog and initialization checks:

```sh
godot --headless --path . --log-file /tmp/type-catalog-tests.log res://tests/type_catalog_test.tscn -- --no-mcp
```

These cover initialization order, persistent definitions between sessions, and atomic rejection of invalid rail and residence catalogs. Validation errors printed during invalid-catalog checks are expected; success prints `Type catalog tests: 0 failures` and exits 0.

Residence editor/runtime conversion: every catalog house has an `editor_<house>.tscn` variant beside its original scene. Use the editor variant for map placement and set `placed_town_num`; all four maps now reference these variants. Each variant inherits the existing house scene, sharing its freely arranged model, collider, and Door markers. At runtime the loader replaces only the authoring root with `Residence3D`, preserves children, transforms, and per-instance overrides, and registers simulation data once. The catalog continues to reference the original scenes for direct runtime spawning. The world-services test verifies all 35 variants and duplicate-registration prevention. Road connections remain a separate step.

Residence definitions live in `game/jsondata/residence_types.json`. Each entry requires a unique `key`, a nonempty `name`, a `res://` scene path in `scene_path`, and `pops` containing two nonnegative integer counts. `block_auto_placement` is optional and defaults to `false`. The two population counts are explicit data; the loader does not derive the second count from the first. Scene paths are independent of residence keys. Existing model paths are retained by this migration; catalog validation does not load or check the scene assets.

Residence `themes` is an optional array of uppercase `Enums.Location` names: `NORTHERN_GERMANY`, `SOUTHERN_GERMANY`, `POLAND`, and `SOVIET_UNION`. Omitted or empty themes mean unclassified; duplicates and unknown names are rejected. The loader converts names into the typed `ResBldType.themes` enum array. Theme assignments are maintained in the JSON catalog. Map metadata keeps the JSON field `loc`, using the same uppercase names; `MapData.loc` holds the corresponding enum value. These fields are metadata for future house placement; this change does not filter house generation.

Infrastructure drawing checks:

```sh
godot --headless --path . --log-file /tmp/infr-drawing-tests.log --script res://tests/infr_drawing_test.gd -- --no-mcp
```

These exercise endpoint filtering and exact-height snapping, preview versus accepted points, duplicate-click rejection, cancellation, unique road/rail IDs, scene ownership, and commit/undo/redo operations using an isolated history adapter. In the editor, select Create Road or Create Rail: click to add points, Enter to finish, Backspace to remove the last point, Escape to cancel the draft. A green sphere indicates endpoint snapping. Scene changes and tool switches discard the draft. New lines are saved in the existing infrastructure containers; JSON export remains explicit. Viewport interaction still needs a visual editor check.

Infrastructure JSON persistence checks:

```sh
godot --headless --path . --log-file /tmp/infr-json-tests.log --script res://tests/infr_json_test.gd -- --no-mcp
```

The editor panel has separate **Save/Load Roads JSON** and **Save/Load Rails JSON** buttons. They use the active world's `map_key` and `world/<map>/jsondata/roads.json` or `tracks.json`. Saving a scene does not save JSON. Finish or cancel a draft before saving/loading.

Each overwrite retains a separate, byte-for-byte backup beside the original (`roads.json.bak-<timestamp>-<unique suffix>`, likewise for tracks). The complete replacement is written to a temporary file before backup and rename; if backup fails, the original stays unchanged. A first save creates the file without a backup because no previous file exists.

Save preserves types/gauges, tags, crossings, stations, and unknown metadata. Existing records absent from a partially generated editor scene are retained. After explicit Load, removing a loaded record and saving deletes that record. Load replaces the matching editor container and can be undone/redone; saving JSON itself is not undone by scene undo. Changing the point count of a record carrying crossing/station metadata is rejected to avoid assigning it to the wrong anchor. New roads default to `rural_road`, and new rails to `NORMAL_GAUGE`; existing types remain unchanged. The renderer is unchanged.

Editor infrastructure lives directly under the map-owned `EditorCache`, outside the instanced `EditorObjects` scene. This cache has its own script and does not use legacy GeneratedRoadWays/GeneratedRailLines containers or number groups. Old grouped cache layouts flatten automatically on opening/use, preserving world transforms and map ownership. Drawing and JSON load/save target the cache; runtime spawning removes it.

After a successful Save Roads/Rails JSON, that domain's visible cache is cleared. The other domain remains untouched. Load JSON restores saved geometry, and scene Undo can also restore the cleared cache. Undo history may retain detached nodes until the map closes. Failed saves leave the cache visible. Repeating Save on a flushed cache preserves the JSON records rather than treating the empty cache as deletions.
