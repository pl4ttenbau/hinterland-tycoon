# Road transport: future routing and actions

This is a concept, not an implemented API. The existing driving prototype remains
responsible for moving a physical vehicle along supplied geometry or accepting
free player input. Its `RoadVehicleRoute` is temporary driving geometry/progress;
it does not yet represent the service routes described here.

## Separate responsibilities

- **Route/itinerary class:** owns an ordered sequence of transport actions. This is
  the player's persistent plan for a bus, truck or other road vehicle.
- **Road network and pathfinder:** find a connected path from any road node to any
  other reachable road node. The result describes directed road segments, including
  partial roads when the origin or destination is an intermediate node.
- **Action executor:** runs the next action, requests a path for a driving action,
  waits for arrival or goods transfer, and then advances to the following action.
- **Vehicle driving controller:** follows the supplied path using steering and
  pedals. Player takeover suspends automatic execution; returning control needs a
  valid road position before the current driving action can resume.

These names describe responsibilities; exact class names and serialization are
still to be chosen. Pathfinding and inventory transfer should remain independent
of the rendered vehicle/depot model and of the dialog that edits a route.

## Addressing and pathfinding

A road node is addressed by its road ID and node index. Consecutive nodes on the
same road supply edges; authored road connections supply edges between roads.
Visual mesh intersections alone must not imply connectivity, particularly where
roads cross at different heights. An unreachable destination should produce an
explicit failure instead of selecting an arbitrary branch.

Bus stops already identify a road/node through `RoadStationData.road_num` and
`node_index`, with side and direction metadata. The planner must respect those
constraints when approaching a stop. Loading stations and depot exits also need
road access anchors so they can serve as origins or destinations. Routing must
support every road node, rather than only road endpoints or whole-road sequences.

## Ordered actions

The initial concepts are:

- **Drive to:** a road node or a stop/loading-station destination resolved to its
  road access anchor. Pathfinding supplies the intermediate road nodes.
- **Load goods:** load one or more specifically selected goods at the current
  station, respecting available stock and vehicle capacity.
- **Unload goods:** unload one or more specifically selected goods from the
  vehicle into the current station's inventory.

For example, a truck plan can be: drive to loading station A → load selected goods
→ drive to station B → unload selected goods. A bus can similarly travel between
bus stops, with passenger transfer policy to be decided separately.

Goods actions need a selection of specific goods rather than only a broad vehicle
cargo category. Quantities, completion/wait conditions, insufficient stock or
capacity, and repeat/loop behavior remain design decisions. No goods actions or
automatic inventory transfers are implemented in this pass.

## Dialog and car depot

A new route dialog will let the player choose destinations, add/reorder driving
and transfer actions, and select one or more goods for each transfer action. It
will show invalid or unreachable destinations using the planner's result.

A road-vehicle depot now provides a basic spawning workflow: choose a vehicle type
in its selector and spawn it parked 10 metres along its connected road, facing away
from the depot. START/END road anchors determine the direction. This uses the
existing SpawnAction with a road-specific signal and dialog. Itinerary assignment
remains a future extension independent of the depot's model.

The route dialog, node-to-node pathfinder and action executor remain future work.
Depot spawning does not execute the conceptual goods actions or assign a service
itinerary automatically.
