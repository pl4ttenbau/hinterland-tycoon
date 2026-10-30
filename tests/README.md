Train path regression checks run with Godot 4.7 from the project root:

```sh
godot --headless --path . --log-file /tmp/train-path-tests.log res://tests/train_path_test.tscn -- --no-mcp
```

The scene exits with code 1 if a check fails. It builds a small rail network without terrain or vehicle meshes and exercises the real movement and fork-setting code. Checks cover continuous junction headings, rotation between nodes, last-moment switching, preserved approach geometry, occupied-switch derailment, stationary trains, wagon spacing, exact reversal, reversed track connections, buffers, and listener cleanup.

The current project also reports an unresolved `EditorSignals` autoload UID and existing shutdown resource warnings. These are independent of the train checks; a passing test prints `Train path tests: 0 failures`.

Visual review is still needed on the game map, especially wheel/rail alignment at sharp junctions: joining the movement curve aligns the outgoing handle with the incoming heading, while the rendered track geometry remains unchanged. Junction occupancy currently uses vehicle lengths around their curve positions; it does not model a switch's physical footprint or bogies.
