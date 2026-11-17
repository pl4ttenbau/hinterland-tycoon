# Train speed and the rail network graph

## Speed model

`TrainMovement` integrates a physical speed (`speed_mps`, metres per second) every
physics tick in `update_speed()`, then `move_forwards()` advances by it. The
`VehicleSpeed` fractions are unchanged for the UI: `speed.target` is the driver's
request and `speed.current` mirrors the physical speed, both as a fraction of the
consist's maximum speed. Writing `speed.current` from outside sets the physical speed.

`TrainDynamics` reads the consist on demand, so coupling and splitting need no
notification:

| Quantity | Source |
| --- | --- |
| Maximum speed | Slowest `max_speed_kmh` in the consist; 6 m/s (the former fixed speed) if none is known |
| Mass | Sum of `mass_tonnes`; 10 t for a vehicle without mass |
| Traction force | `min(tractive effort, power / v)`, summed over powered vehicles; the tractive effort uses the [pricing estimate](vehicle-pricing.md) when not authored |
| Acceleration | Force / mass, capped at 1.0 m/s²; 0.3 m/s² for a motor without power or effort data; zero for an unpowered consist |
| Service braking | 0.5 m/s²: lowering the target, and stopping ahead |
| Brake control | 1.0 m/s² |

Running resistance and gradients are not modelled yet.

### Movement authority

`get_movement_authority()` is the distance the train may still travel: the depot
rollout limit or the end of its known route (a buffer, an unset fork or a gauge
change). The speed never exceeds `sqrt(2 · 0.5 m/s² · authority)`, so trains brake
smoothly to a stop there instead of halting instantly. The route is planned at least
the stopping distance plus 20 m ahead. Signals will add their own limit to the authority.

If the authority suddenly shrinks (a switch thrown ahead), the train brakes at the
brake-control rate; if that is not enough, the hard stop at the route end still applies.

## Junctions

A physical switch is one `NewRailForkData` (the junction). Each track endpoint at it
is a `RailNodeForkData` leg, which references its junction directly through
`junction`. The switch setting lives only on the junction. Positions group legs
into junctions while loading; nothing at runtime looks a junction up by position.

- `get_exit_track_nums(from)`: the root leads to every branch; a branch leads only back to the root.
- `set_connected_track(num)`: select a branch directly, for route setting.

The legacy per-leg `setTo` value in map JSON is still not read; junctions choose their
initial setting as before.

## Rail network graph

`RailNetworkGraph` (`game/gamescripts/services/routing/`) has one vertex per track
and direction of travel (`vertex_id(track_num, direction)`). Edges follow the junction
rules above and skip incompatible gauges, so branch-to-branch moves need a reversal and
are not edges. Entering a vertex costs its track's curve length; `find_path()` uses A*.
The graph describes topology only and ignores current switch settings.

`Managers.rails.get_network_graph()` builds it on first use and rebuilds after a
track is added or the network is edited.

## Tests

```sh
godot --headless --path . res://tests/train_movement_test.tscn -- --no-mcp
godot --headless --path . res://tests/train_path_test.tscn -- --no-mcp
godot --headless --path . res://tests/rail_network_graph_test.tscn -- --no-mcp
```
