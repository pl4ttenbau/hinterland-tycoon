# World services scene

`scenes/subscenes/world_services.tscn` packages the session's entity services and
map spawning into one reusable scene. `scenes/game_session.tscn` instances it as
`WorldServices` alongside the player, input, and UI.

```text
WorldServices
├── Towns
│   └── WorldTownBldPlacer
├── Infr
│   ├── Rails (fork loader and rail builder)
│   ├── Stations (connectors and passenger spawning)
│   └── Roads (industry exit connector)
├── Vehicles
├── Industries
├── Depots
└── LoadedMap
    ├── WorldUpdateTimer
    └── TerrainRaycaster
```

The scene root uses `WorldServicesCoordinator`, a session-owned Node with explicit
`initialize() -> Error`. It does not initialize automatically on tree entry.
`GameSession` waits for type readiness, connects to the coordinator's completion
signal, and calls `initialize()`. Only after service completion does it emit
`scene_root_ready`.

Initialization proceeds in three stages:

1. Validate required nodes and register all session services in `Managers`.
2. Connect cross-service and global signals. Wiring preserves the existing
   map-loading sequence but no longer depends on sibling order.
3. Start the world/passenger timers, mark readiness, and emit
   `SignalBus.services_initialized`, followed by the root's local
   `services_initialized` signal.

Repeated initialization succeeds without adding connections or emitting completion
again. Initialization requires a ready scene and initialized types; failures emit
the coordinator's `initialization_failed(error)` signal and return an Error. A
second coordinator cannot take over while another session is registered.

Map selection checks both catalog and service readiness. The selected map still
spawns under `Managers.map_spawner` (`LoadedMap`). No new autoload is needed.

Leaving the tree disconnects coordinator-owned signals, stops timers, and clears
only its own `Managers` registrations. Application-scoped services such as
`MapListLoader` remain available. This handles service lifetime; it does not reset
all simulation state in `GlobalState` for a new game.

The coordinator owns dependency wiring; services retain their loading/spawning
methods and local timer handlers. The map-loading signal chain itself is unchanged.
Run initialization, sibling-order, idempotency, and cleanup checks with:

```sh
godot --headless --path . res://tests/world_services_test.tscn
```
