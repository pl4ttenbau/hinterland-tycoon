# Road vehicle movement and automatic U-turns

`RoadVehicle3D` remains the single movement controller. Player driving and ordinary automatic road following use the same `VehicleBody3D` wheel physics, steering limit, suspension, engine and brakes. The player's turning radius is unchanged.

The automatic driver samples the route ahead for bends and uses their curvature to limit corner speed. It works backwards from each bend to find where braking should begin, using half the configured `braking_deceleration` as its approach estimate. `cornering_lateral_acceleration` sets how fast the driver aims to take curves, and longer wheelbases start steering farther ahead. The vehicle follows the bend using wheel physics.

## Automatic endpoint manoeuvre

When the next driving segment reverses the vehicle's current direction, `RoadUTurnPlanner` prepares an approach to the road end in its present direction. The vehicle drives there using normal physics and brakes to a stop. A reversal inside a longer path is likewise split at its road endpoint. No authored road nodes, markers or extra route visits are created.

The controller then follows a short teardrop `Curve3D` directly. This is an intentional gameplay exception to realistic wheel steering: a small automatic turning radius lets a vehicle turn around without a large turning circle or a multi-point manoeuvre. The path briefly extends around the road endpoint, returns to the road at approximately its entry offset, and exits facing the other direction.

During this curve only, the body uses kinematic freeze. Collision layers and shapes stay enabled; explicit shape overlaps and motion sweeps check the complete chassis at the next orientation. An obstruction holds the pose and curve progress with a visible blocked status. Clearing the obstruction lets the manoeuvre continue. This does not implement traffic priority or obstacle avoidance.

The helper `RoadVehicleUTurn` owns only temporary geometry and progress. The existing movement controller owns freeze state, collision checking, pose advancement and driver handoff. At completion it restores the previous freeze configuration and supplies the curve's exit velocity to the physics body. The executor replans the remaining driving segment from the actual exit pose, preserving the pending visit and its actions.

## Tunables and interruption

- `automatic_uturn_radius`: default **1.25 m**, independent of manual `steering_limit`.
- `automatic_uturn_speed`: default **1.5 m/s**.
- A turn begins after the approach brakes to at most **0.2 m/s**.

Manual takeover cancels the remaining turn curve at its current pose and restores normal vehicle physics with its current tangent velocity. The player is free to steer normally. On releasing control, the executor replans from that pose; it does not snap back to the abandoned curve. Stopping the plan cancels the manoeuvre and restores physics without retaining curve velocity. Removing the source road cancels safely and reports the missing road.

This is a local, deliberately assisted turnaround rather than a physically simulated steering manoeuvre. Its small envelope can extend past the authored road surface; it preserves the approach height while following its curve. It checks collisions, but does not search the terrain for an alternative turning area. Ordinary bends continue to use the existing physical driver.

U-turns currently belong to itinerary execution. The legacy `set_route()` whole-road preview API continues to supply an ordinary physics-followed curve.

## Verification

Run:

```sh
godot --headless --fixed-fps 60 --path . --script res://tests/road_uturn_test.gd
```

The suite checks endpoint selection, internal path reversals, entry/exit continuity, both road ends, manual takeover, blocked/resumed movement, physics restoration and an A → B → A passenger service with exactly two pickups and two completed trips. Existing vehicle, routing and route-transfer suites cover ordinary driving and inventory behaviour.

## Code ownership and movement phases

There is no second movement controller, path-following scene, or automatic-only copy of the vehicle. `RoadVehicle3D._physics_process()` selects one owner of movement each tick:

| Phase | Movement owner | Vehicle physics | Visit advancement |
| --- | --- | --- | --- |
| Player driving | `_drive_player()` | Normal wheel physics | Suspended |
| Normal automatic segment | `_drive_route()` | Normal wheel physics | On physical arrival |
| Approach to a reversal | `_drive_route()` | Normal wheel physics | Pending visit unchanged |
| Automatic turnaround | `_drive_automatic_uturn()` | Kinematic freeze plus explicit collision queries | Suspended |
| Fixed-path segment (switch on) | `_drive_route_fixed()` | Kinematic freeze plus explicit collision queries | On scripted arrival |
| Stop servicing | `RoadPlanExecutor` and transfer service | Stationary normal body, or held stationary in fixed-path mode | After ordered actions succeed |

The controller checks for an active turn both before and after the executor ticks. That second check matters: arriving at an endpoint can start a turn during the executor's tick. Ordinary steering must not also move the body in that frame. While a turn is active, the executor does not advance visits or execute load/unload actions.

`RoadUTurnPlanner.prepare()` returns a small `Approach` DTO containing the live `Path3D`, endpoint offset, and ordinary approach segments. It owns no vehicle state. For an initial reversal it chooses the endpoint in the vehicle's current heading; for an internal path reversal it retains only the segments leading up to that endpoint. It does not insert artificial junctions or modify the road graph.

`RoadPlanExecutor` keeps that DTO and a started flag as a temporary navigation substep. The selected route point, frozen plan and pending actions remain unchanged. It drives the approach, waits for braking to finish, and calls `begin_automatic_uturn()`. Once movement reports that the curve is inactive, the executor resolves the pending visit again from the vehicle's actual pose. This same fresh resolution handles a manual interruption; it deliberately does not pretend the abandoned curve was completed.

## Curve geometry and why it is separate

`RoadVehicleUTurn` builds two cubic Bézier segments joined with a shared tangent. The entry tangent follows the vehicle's current forward axis, the middle handles guide it around the road end, and the exit tangent faces back along the road. The finish position is projected back onto the road near the entry offset. This creates a narrow teardrop with a reversal in heading, rather than an instantaneous mirror or rotation.

Geometry is sampled in world metres, including transformed road paths. The bake interval is 0.05 m. The body's approach height is carried through the curve, with the road's local endpoint tangent supplying its direction. Sampling derives the forward axis from neighbouring curve points; the first 0.5 m blends from the exact entry basis so suspension roll/pitch does not change instantly. The curve is a temporary world-space snapshot and is discarded after the manoeuvre.

Keeping construction and sampling separate from `RoadVehicle3D` makes the assisted exception explicit and testable. The helper cannot change physics, transfer passengers, consume route points or take player input.

## Physics handoff, obstacles and cancellation

Before starting, the movement controller checks that the player is not driving, the car has slowed down, the source path is valid, and the body is actually near its endpoint. It records both `freeze` and `freeze_mode`, clears force/steering requests and velocities, then enables kinematic freeze. The original steering limit is never changed.

Each step is proposed before being committed. For every enabled chassis collision shape, the controller checks overlap at the next rotated pose and sweeps the translation using the vehicle's existing collision mask, excluding its own RID. Explicit space queries are used because a frozen body's ordinary contact reporting is not a substitute for validating scripted movement.

If blocked, neither pose nor progress advances. The remembered tangent velocity is cleared too, so taking manual control while blocked does not give a stationary car a sudden push. The same curve is retried on later physics ticks; the vehicle does not turn through the obstruction or choose another route around it.

At a successful exit, the last curve displacement supplies the restored body's velocity. Only normal wheel physics runs afterward. Manual takeover follows the same restoration path at the current pose, cancelling the remaining curve. A plan stop restores the body with zero turn velocity. The restoration method is idempotent: calling it when no turn is active does nothing, which lets ordinary stop and driver-handoff paths use it safely.

Deleting or detaching the source `Path3D` invalidates the active curve. The controller stops the plan, clears the manoeuvre and restores the original body configuration. It does not keep moving on stale geometry. A failed or interrupted manoeuvre never marks the pending route visit as serviced.

## Current boundaries

This is a temporary gameplay solution for automatic endpoint reversals. It is not lane switching, a realistic steering-radius simulation, a terrain search, or traffic management. The assisted curve may use space beyond the road mesh; world geometry can block it. There is no timed automatic recovery from a blocked manoeuvre. Roads modified in place do not reshape an already active world-space turn curve; the next driving segment is resolved after the turn.

## Fixed-path following (global switch)

`RoadVehicle3D.follow_road_path` is a static switch, off by default. When on, automatic driving stops steering with wheel physics and places every road vehicle exactly on its route curve. It applies to itinerary execution and to the legacy `set_route()` API alike. Player driving is unaffected. Changing it takes effect on the next physics tick; switching it off hands any held vehicle back to wheel physics with its current velocity.

The speed is a scalar along the curve. Its target comes from the same `_desired_route_speed()` planner as the physical driver, so bend braking (`cornering_lateral_acceleration`) and the terminal stop margin are unchanged; it accelerates at `path_acceleration` (default **1.5 m/s²**) and brakes at `braking_deceleration`. `route.progress` is advanced directly instead of being projected from the body's position.

Following starts only from a body whose wheels rest on the road (or one already held after a U-turn) within `route_recovery_distance` of the curve; otherwise the physical driver recovers first. The body's height above the centreline at that moment is kept for the whole segment, and the heading comes from a ±0.5 m chord so slopes pitch the body. The first `PATH_BLEND_METRES` (3 m) ease from the actual takeover pose, so starting slightly off the centreline does not snap. A new route curve (a replanned segment) restarts this blend.

### Shared scripted motion

U-turns and fixed-path segments share one kinematic hold: `_hold_scripted()` records `freeze`/`freeze_mode` once and freezes kinematically; `_release_scripted(keep_velocity)` restores them. Holding is idempotent, so with the switch on a vehicle passes from a fixed-path approach into a U-turn and back onto the next segment without ever dropping onto its suspension. Both movers commit poses through `_move_scripted()`, which uses the same overlap-and-sweep check described above; a blocked step holds pose and progress and zeroes the reported velocity. The check runs `SCRIPTED_GROUND_CLEARANCE` (0.1 m) above the body: authored chassis boxes reach down to the road surface that the wheels hold them above, so an unraised check reports the supporting road as an obstruction. Obstacles lower than that clearance are ignored.

While held, `current_velocity()` returns the scripted velocity (a frozen body's `linear_velocity` is not authoritative), and `signed_speed_mps()` uses it. The executor and transfer service use `current_velocity()` for their "is the vehicle stationary" checks.

On arrival the body stays held and stationary. The executor parks it for stop servicing and endpoint-turn approaches with `clear_route(true)`, which keeps the hold. Plan stops and completion call `clear_route()`, which releases to wheel physics with zero velocity. Manual takeover releases with the scripted tangent velocity.

### Trade-offs

A held vehicle has no suspension, roll or pitch response beyond the road's slope. Obstacles are never pushed: the vehicle waits until the sweep is clear. The kept height assumes the road surface follows its curve; where it does not, the body floats or sinks. Each held vehicle runs one overlap query and one sweep per collision shape per physics tick.

## Verification of fixed-path following

`road_vehicle_suite.gd` (`test_fixed_path`) checks that the body stays within 5 cm of the centreline through the tight house bend, stops once at the route end held and stationary, and that manual takeover restores wheel physics with the scripted speed. `road_uturn_suite.gd` (`test_fixed_path_both_ends`) repeats the two-endpoint itinerary with the switch on and checks the body stays held from each turn into the next segment.

Normal driving with the switch off, suspension, off-route checks and manual vehicle handling remain the existing physics-driven implementation.
