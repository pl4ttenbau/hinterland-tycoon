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

Residence definitions live in `game/jsondata/residence_types.json`. Each entry requires a unique `key`, a nonempty `name`, a `res://` scene path in `scene_path`, and `pops` containing two nonnegative integer counts. `block_auto_placement` is optional and defaults to `false`. The two population counts are explicit data; the loader does not derive the second count from the first. Scene paths are independent of residence keys. Existing model paths are retained by this migration; catalog validation does not load or check the scene assets.

Residence `themes` is an optional array of uppercase `Enums.Location` names: `NORTHERN_GERMANY`, `SOUTHERN_GERMANY`, `POLAND`, and `SOVIET_UNION`. Omitted or empty themes mean unclassified; duplicates and unknown names are rejected. The loader converts names into the typed `ResBldType.themes` enum array. Theme assignments are maintained in the JSON catalog. Map metadata keeps the JSON field `loc`, using the same uppercase names; `MapData.loc` holds the corresponding enum value. These fields are metadata for future house placement; this change does not filter house generation.
