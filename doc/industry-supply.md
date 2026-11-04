# Industry supply warnings

Select a map's **Industries** (`WorldIndustries`) node in the Godot editor. Its
configuration warnings list each consumed good with no producer among that
container's direct `IndustryPlaceholder` children. Each warning names the affected
industries and suggests producer types from the same recipe catalog used at runtime.
Unknown or empty industry type keys produce their own warnings.

Warnings refresh when children are added or removed and when a placeholder's
`type_key` or `ind_name` changes, including undo/redo. Use **Check Industry Supply**
in the Inspector to refresh explicitly after editing the recipe catalog.

Only one producer of any matching type is required. For example, either a coal mine
or a charcoal burner satisfies a coal consumer. A producer counts even if it lacks
its own inputs; those inputs receive separate warnings if no producer exists.
Transport connections, production rates, stock levels, imports, and circular
dependencies are outside this existence check. Intentional imports still show a
warning until an import mechanism is represented.

The checker does not initialize game services, register catalog types, instantiate
industry models, or change map data. It does not run during normal gameplay.

Run the headless checks from the project root:

```sh
godot --headless --path . --script res://tests/industry_supply_test.gd -- --no-mcp
```

The checks cover missing inputs, alternative producers, adding/removing/retyping
industries, unknown types, direct-child scope, and the four authored maps. They
read authored placeholder blocks without loading terrain and exit nonzero on failure.
Adding `--editor` also checks automatic warning refresh scheduling for changes.
