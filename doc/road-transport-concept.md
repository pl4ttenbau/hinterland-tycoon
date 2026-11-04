# Road transport: route setting and next steps

## Implemented: route-plan editing

Enter a road vehicle, open the circular menu with **right-click**, and choose
**Auto-routing** to open its route editor. The first tab adds,
removes and reorders route points. The second tab edits the selected point's
ordered **Load** and **Unload** instructions, with one or more selected goods.

Selectable point kinds are **named road marker**, **physical road stop**, and
**road depot**. Raw road nodes are no longer offered; existing node-based plans
remain valid. Stops, markers and depots use separate IDs. References resolve
against current data when saving; depots resolve to their START/END road anchor.

On foot, stand on a road and choose **Place road marker** from the circular menu. A small dialog captures that road
position and offers a default name such as **Marker 1**. Its side defaults to
where the player stands. Choose **Both** in the side selector for a two-sided marker. Name and side can be
changed before confirming. Placement uses the physical road beneath the player,
not the nearest road or a bridge overhead. Markers are session data for now.

Each marker stores a road ID, curve offset, name and Left/Right/Both side. Both
creates two roadside signs but one target. Right accepts an increasing-order
approach, Left a decreasing-order approach, and Both either. The physical driver
still uses the road centreline; traffic lane offsets remain separate work.

Transfer instructions currently require a stop, because ordinary nodes and depots
have no station inventory. Passenger instructions require one or more **specific
physical destination stops**, never an interchange ID. Different passenger goods
(such as passenger, tourist and soldier) retain this same destination filter.
Vehicle cargo-category compatibility is checked when adding/saving instructions.

The editor works on a deep copy. **Save plan** validates all anchors, road-segment
connectivity and action selectors before assigning the plan to the vehicle.
**Cancel** retains the previous plan. Saving only stores a plan on this session's
vehicle. **Start plan** begins execution; leave the vehicle to give control to the
automatic driver. Transfers remain inactive. ResourceSaver round trips
are supported, but game-save integration is not implemented.

## Pathfinding

`RoadPathfinder` uses road endpoints as its permanent graph. Ordinary shape nodes
stay in road curves, so normal road-to-road travel searches whole road segments.
Explicit legacy interior crossing anchors are retained defensively if present.
Stop/marker/current-position anchors attach only for a query; the first and last
partial segments use curve arc distances. Temporary anchors are removed afterward.
Authored crossings join matching XYZ anchors within 0.1 metres. Visual overlaps
and height-separated roads never create connections by themselves. Unreachable
segments prevent saving; infrastructure subtype restrictions still apply.

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
  takeover preserves progress; leaving the vehicle resumes the same segment.

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
