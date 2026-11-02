# Road transport: route setting and next steps

## Implemented: route-plan editing

Enter a road vehicle and press **R** to open its route editor. The first tab adds,
removes and reorders route points. The second tab edits the selected point's
ordered **Load** and **Unload** instructions, with one or more selected goods.

Point kinds are **road node**, **physical road stop**, and **road depot**. Nodes
use road ID/node index; stops and depots use their own IDs. References resolve
against current data when saving. Node zero and intermediate nodes are valid.
Depots resolve to their authored START/END road anchor.

Transfer instructions currently require a stop, because ordinary nodes and depots
have no station inventory. Passenger instructions require one or more **specific
physical destination stops**, never an interchange ID. Different passenger goods
(such as passenger, tourist and soldier) retain this same destination filter.
Vehicle cargo-category compatibility is checked when adding/saving instructions.

The editor works on a deep copy. **Save plan** validates all anchors, road-leg
connectivity and action selectors before assigning the plan to the vehicle.
**Cancel** retains the previous plan. Saving only stores a plan on this session's
vehicle. **Start plan** begins execution; leave the vehicle to give control to the
automatic driver. Transfers remain inactive. ResourceSaver round trips
are supported, but game-save integration is not implemented.

## Pathfinding

`RoadPathfinder` builds a bidirectional graph of every road node. Consecutive
nodes connect with curve arc-length costs. Authored road crossings connect matching
XYZ nodes within 0.1 metres. Visual intersections and height-separated roads do
not create connections on their own. Partial-road paths, reverse travel and
intermediate junctions are supported. A vehicle's infrastructure subtype restricts
which roads enter its graph. Unreachable legs prevent saving.

The graph checks connectivity, not traffic lanes or safe arrival poses. The executor stops before node/stop anchors and uses a 10-metre stand-off for
depot arrivals. Traffic-side/stop approach rules and automatic U-turns still need
work. If the target lies behind the car, turn manually before resuming.

## Separation of responsibilities

- `RoadRoutePlan` owns ordered `RoadRoutePoint` visits and their `RoadRouteAction`
  instructions. It does not hold physical driving progress.
- `RoadPathfinder` chooses connected road-node paths between visit anchors.
- The existing `RoadVehicleRoute` holds currently executed driving geometry and
  progress; it remains separate from the editable plan.
- `RoadPlanExecutor` connects the current road offset to the graph, generates
  partial-road driving geometry and advances visits after stopping. It pauses at
  any point with transfer instructions, without executing or skipping them. Manual
  takeover preserves progress; leaving the vehicle resumes the same leg.

Example: stop A — load passengers destined for stop B — stop B — unload those
passengers. Truck routes use the same visit/action structure with selected goods.

## Next stages

1. Refine junction steering, traffic-side approaches and U-turn handling. Current
   execution uses the existing physical driver and brakes when recovery is unsafe.
2. Add destination-aware passenger batches. Current inventories/spawning still
   store passenger totals; target metadata must survive boarding and alighting.
3. Execute validated load/unload instructions with capacity/stock checks and
   atomic inventory changes. Quantities, waiting/completion rules and route looping
   remain design decisions.
4. Passenger spawning frequency, waiting limits and expiry remain separate work.
   The discussed values are suggestions, not enabled behavior.

Road depots already spawn the selected vehicle parked 10 metres along the road,
facing away from the depot. Route editing does not change that workflow.
