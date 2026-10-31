# Type catalog initialization

`GameTypes` holds shared definitions across game sessions. `GameSession._ready()`
connects to `SignalBus.all_types_initialized` before calling
`GameTypes.ensure_initialized()`. After type success it initializes the
`WorldServicesCoordinator`; only after services complete does it emit
`scene_root_ready`. A later session checks `GameTypes.is_initialized` and starts
without reloading or expecting the completion signal to repeat.

Load order: goods, infrastructure, industries, residences, rail vehicles.
Each loader extends `AbstractGameTypeLoader` (a `RefCounted` helper), implements
`load_types() -> Error`, and emits `loading_finished()` after successful
registration. Construction never loads definitions. Loading is currently
synchronous; connect before starting it rather than awaiting a signal afterward.

Global signals:

- `type_catalog_loaded(type_name: StringName)`: progress for one category.
- `all_types_initialized()`: every category and cross-reference validated.
- `types_initialization_failed(error: int)`: initialization failed; partial catalogs
  have been cleared and another explicit attempt is possible.
- `res_bld_types_loaded()`: compatibility notification after complete initialization.

New listeners check `GameTypes.is_initialized` to handle already-loaded catalogs.
Initialization returns `ERR_BUSY` during a reentrant attempt. Maps cannot be
selected before both catalog and world-service initialization succeed.

Rail definitions live in `game/jsondata/rail_vehicle_types.json` and are loaded by
`RailVehicleTypesLoader` as `RailVehicleTypeData`, which extends `VehicleTypeData`.
The shared base contains common fields; rail model/preview conventions belong to
the rail subclass. JSON entries use numeric speeds/lengths, `display_name`,
`model_scene_path`, `has_motor`, `usable_infr` (subtype only), and optional
`capacity`. The rail loader supplies the runtime infrastructure domain. `mass_tonnes`
(empty mass in metric tonnes) and `motor_power_kw` (power in kilowatts) accept numbers
or `null` for unknown values. Null values stay unknown when loading.
The export
preset includes `game/jsondata/*.json` because these files use `FileAccess`.

Road vehicles should have their own `RoadVehicleTypeData`, loader, and JSON file.
Their loader can append to the common vehicle catalog after checking key
uniqueness; rail composition UI selects only rail definitions.

Run the catalog lifecycle and invalid-input checks with:

```sh
godot --headless --path . res://tests/type_catalog_test.tscn
```
