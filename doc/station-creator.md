# In-game station creator

On foot, stand on a road or visible rail bedding, open the right-click action
menu and choose **Create stop**. The creator captures the position before opening
its waypoint-style modal. It detects the supporting road or track with a short
downward ray, rather than selecting a nearby parallel road or a bridge overhead.

The stop anchors to the curve at the player's position, including between authored
nodes. Road shelters sit beside the road as usual; rail platforms follow the local
track direction. Placement does not insert nodes or change authored geometry.

## Two dialogs

The creator searches physical rail and road stops within **50 metres inclusive**
of the captured player position, using world-space 3D distance.

- With nearby stops, **Add stop to station** shows the existing interchange name
  and town. If several interchanges qualify, a selector defaults to the one with
  the nearest physical stop. Equal-distance ties use the interchange number.
  Multiple stops in one interchange produce only one entry.
- Without nearby stops, **Create station** asks for a name and town. The nearest
  town is selected initially. Confirmation creates the interchange and its first
  stop together; cancellation publishes neither.

Road stops offer Increasing node order, Decreasing node order, or Both directions.
The default follows the side of the road where the player stands. Both directions
creates two shelters for one physical stop. Rail stops offer Passenger or Goods.
Added stops inherit their interchange's name, town, and shared inventory.

Confirmation revalidates infrastructure and interchange proximity. A stop on the
same infrastructure less than 2 m away blocks duplicate placement. Invalid input
stays in the dialog with an explanation. Cancel and Escape restore the previous
mouse, movement and player process settings.

## Runtime integration

The creator is a session-owned child of `InterchangesLoader`. Both stop loaders
register and spawn new stops through their normal resources and scene types.
Town membership and residence/industry catchments refresh immediately. Inventories
remain per physical stop, with no automatic interchange transfers.

`AbstractStation.curve_offset >= 0` marks a curve-anchored gameplay stop; `-1`
retains the existing authored node anchor. Road route targets resolve runtime
stops to `RoadRouteAnchor` with the selected arrival direction. Runtime rail
adapters retain a nearby node reference without replacing its `station` link.

Creation only changes session state. The managers do not write authored map JSON;
cross-session persistence belongs to a future game-save integration.

## Checks

```sh
godot --headless --path . --fixed-fps 60 --script res://tests/station_creator_test.gd -- --no-mcp
```

Checks cover real road/rail collision picking, exact curve placement, registration,
views and inventories, cross-mode joining, 50 m boundaries, multiple nearby
stations, routing anchors, catchment refresh, validation, both dialogs, action
dispatch, vehicle exclusion, cancellation and session cleanup.

Run without `--headless` and append `--station-preview` after `--` to render the
two dialogs to `/tmp/station-creator-create.png` and `/tmp/station-creator-add.png`.
