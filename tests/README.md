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

These exercise endpoint filtering and exact-height snapping, preview versus accepted points, duplicate-click rejection, cancellation, unique road/rail IDs, scene ownership, and commit/undo/redo operations using an isolated history adapter. In the editor, select Create Road or Create Rail: click to add points, Enter to finish, Backspace to remove the last point, Escape to cancel the draft. A green sphere indicates endpoint snapping. Scene changes and tool switches discard the draft. New lines enter the map-owned EditorCache; JSON saving remains explicit. Viewport interaction still needs a visual editor check.

Infrastructure JSON persistence checks:

```sh
godot --headless --path . --log-file /tmp/infr-json-tests.log --script res://tests/infr_json_test.gd -- --no-mcp
```

Select the **EditorCache** node in the open world to use its **Save Roads JSON** and **Save Rails JSON** Inspector buttons. These emit `EditorSignals.infrastructure_save_requested(cache, domain)`; the plugin validates the active map, then performs backup, write and flush. Saving a scene does not save JSON. Finish or cancel a draft before saving. To load saved geometry, open `editorobjects_<map>.tscn` separately, select its WorldEditorObjects root, and use its **Load Roads JSON** / **Load Rails JSON** Inspector buttons. They use that root's `map_key` and `world/<map>/jsondata/roads.json` or `tracks.json`. Ctrl+S saves the generated view into the EditorObjects subscene.

Each overwrite retains a separate, byte-for-byte backup beside the original (`roads.json.bak-<timestamp>-<unique suffix>`, likewise for tracks). The complete replacement is written to a temporary file before backup and rename; if backup fails, the original stays unchanged. A first save creates the file without a backup because no previous file exists.

The two editor representations have separate roles:

- **EditorObjects:** saved geometry loaded explicitly through the standalone scene root's Inspector. Generated nodes belong to that edited root, so they are selectable and persist with Ctrl+S. Loads use the plugin's undo history when available. World activation and world JSON saving never regenerate this scene automatically.
- **EditorCache:** map-owned, unsaved new/edited lines directly under the cache, without number groups. It can be saved with the map scene to preserve unfinished authoring work across restarts. Runtime spawning removes both editor representations.

For a line inside a world map, use **Edit In Cache** in its Inspector to create an independent working copy with the same ID and world transform. Repeated clicks select the existing copy. The corresponding source line is temporarily hidden. Staging is undoable; removing/undoing a working copy restores the saved reference without deleting the JSON record. The old Export To Log control has been removed.

**Save Roads/Rails JSON** merges only that domain's cached work into JSON, preserving existing types/gauges, tags, crossings, stations and unknown metadata. Reference geometry is never written back over newer JSON. Removing a cached edit discards the edit; delete saved records in JSON and reload references when a permanent deletion is intended. Changing point count while a record carries crossing/station metadata is rejected rather than reassigning it to another anchor. New roads default to `rural_road`; new rails default to `NORMAL_GAUGE`.

After writing JSON with a backup, Save clears that domain's cache without reloading geometry. The other domain's unsaved cache remains untouched. Failed writes retain cached work. Loading into EditorObjects is a separate, explicit Inspector action. The cache clear can be undone, and history may retain detached nodes until the map closes. Repeating Save with an empty cache preserves JSON records. Saving JSON itself is not undone by scene undo. The renderer is unchanged.

Road endpoint connection checks:

```sh
godot --headless --path . --log-file /tmp/road-connection-tests.log --script res://tests/road_connections_test.gd -- --no-mcp
```

Visible road endpoints in EditorCache and EditorObjects connect when their full XYZ positions are within 0.02 units. Intermediate points, rail endpoints, hidden roads, and self-connections are excluded. EditorInfrLine3D exposes read-only start/end connection arrays (road ID and endpoint 0=start, 1=end) in the Inspector. A cyan sphere marks each connected junction; green pointer snapping remains separate. Curve edits, transforms, visibility changes and adding/removing roads schedule a shared, deferred refresh. Markers and the lookup service are editor-only and not stored in the scene.

Save Roads JSON applies the same endpoint rule to the merged road records, including saved records not currently rendered. It writes reciprocal `cross.connectiveRoads` and records generated additions separately in `autoConnectiveRoads`. Subsequent saves remove stale generated links while preserving manual links and other metadata. Existing backup-before-replacement and flush-after-success behavior is unchanged. No JSON-only snap targets, road splitting, junction meshes, or rail fork generation are added. Source-scene roads remain visible unless a cached copy of the same ID temporarily supersedes them; flushing restores only those automatically suppressed copies.

JSON formatting: point `pos` coordinates use normal rounding to two decimal places, including trailing zeros (e.g. `2.40`). Curve handles retain their precision. Numeric arrays stay inline when they fit within 120 columns (tabs count as four); longer arrays use one value per line. Serialization walks the data structure so strings containing JSON-like text stay intact. Crossing matching uses the same rounded positions as the file.

Object selection and cache save signal checks:

```sh
godot --headless --path . --log-file /tmp/editor-selection-tests.log --script res://tests/editor_selection_test.gd -- --no-mcp
```

**Select Object** is a mutually exclusive toolbar tool. Initially it picks visible EditorInfrLine3D roads/rails in the cache and EditorObjects, using projected baked curve segments with a ten-pixel tolerance. It handles perspective/orthographic cameras, near/far clipping, transformed parents, overlapping depth and terrain-hit occlusion. It runs on clicks, not every frame. Inspector-only inspection bypasses locked scene selection without enabling Editable Children or moving the object; map-owned objects also receive native scene selection. **Free Tool** and Escape clear the active tool only. Towns, industries and other shapes can later register pickers returning the same target/world-position/depth/screen-distance contract. They are not implemented yet.

The old JSON save row is removed from HinterlandTools. Cache Inspector buttons only emit requests through the plugin-owned EditorSignals bus; file I/O remains in InfrJsonStore and cache clearing happens only after successful saving. Requests for inactive maps are rejected, and unfinished drawing drafts must be finished/cancelled first.
