# Interchanges and physical stops

Every map defines its stations in `world/<map>/jsondata/interchanges.json`.
An interchange owns the shared name and town metadata. Its `stops` array contains
physical rail and road access points, with no separate child names.

```json
[
  {
    "num": 7,
    "name": "Friedland Bahnhof",
    "townNum": 3,
    "townName": "Friedland",
    "stops": [
      {
        "num": 12,
        "domain": "RAIL",
        "trackNum": 4,
        "nodeIndex": 0,
        "type": "STATION_PASS"
      },
      {
        "num": 13,
        "domain": "ROAD",
        "roadNum": 42,
        "nodeIndex": 3,
        "roadStopDirection": "ROAD_NODES_INCREASE"
      }
    ]
  }
]
```

## Identity and schema

- Interchanges require `num`, a nonempty `name`, `townNum`, and a `stops` array.
  `townName` is optional; when omitted, town binding supplies the map town's name.
  Empty interchanges are valid, but have no physical catchment yet.
- Every stop requires `num`, `domain` (`RAIL` or `ROAD`), and `nodeIndex`.
  Rail stops require `trackNum`. Road stops require `roadNum` and `roadStopDirection`.
- All IDs and node indices are nonnegative integers. Node index zero is valid.
  Stop numbers must be unique across **both modes and every interchange on the
  map**. Interchange numbers have a separate namespace. A rail node may hold one
  physical stop; duplicate rail anchors are rejected.
- `roadStopDirection` is `ROAD_NODES_INCREASE`, `ROAD_NODES_DECREASE`, or
  `BOTH_DIRECTIONS`. It specifies which direction a vehicle can approach from.
  In right-hand traffic, increasing node order places the shelter to the right
  of the road when facing increasing node indices. Decreasing order places it
  to the left. Swap the directional values when reversing a road's node order
  to keep its shelters on the same physical side.
- Stops may additionally specify `type` and `hideBuilding`. The latter defaults
  to false. Name, town and interchange membership belong to the parent; supplying
  `name`, `townNum`, `townName` or `interchangeNum` in a child record is rejected.
- Rail stop `type` is loaded into `RailStationData.station_type`. Existing maps
  use `STATION_PASS` and `STATION_GOODS`; omission defaults to `STATION_PASS`.
  Type belongs to the physical stop, so one interchange can contain different
  stop types. Road stops share the inherited `station_type` field and optional
  JSON `type`, but their type vocabulary is not defined yet; omission leaves it
  empty.

`InterchangeData.stops` and `AbstractStation.interchange` provide membership in
both directions. `station_name`, `town_num`, and `town_name` read through to the
shared parent, which also owns the inventory. `Managers.interchanges.stops_by_num` is the common stop lookup;
`Managers.stations` retains the rail-specific lookup and `Managers.road_stops`
provides the road-specific one.

## Startup order

### Building catchments

Residences and industries connect once to an interchange using the union of
its physical stops' 200-metre 3D catchments. The interchange with the nearest
reachable stop wins; equal-distance ties use manual IDs. The connection retains
all reachable stops within that interchange, ordered by distance. It does not
make distant stops in the same interchange directly accessible to that building.

Connections are held in `InterchangeData.connections`; reassignment removes old
membership and does not duplicate buildings. Road-only interchanges are supported.
The interchange owns one 60-unit inventory. Its rail and road stops and linked
industries access the same stock. Each stop retains its physical location for
transfer reach and its ID for route waypoints. Passengers target the interchange
and can finish their trip at any of its stops. Standalone stops retain
their local inventory. See [industry production and stock](industry-production.md).

`WorldServicesCoordinator` registers every service before wiring callbacks.
Its explicit `load_map_data()` sequence is:

1. Parse and validate the complete interchange catalog; create **all parents**.
   Publish `InterchangesLoader.interchanges_loaded` while no stops exist yet.
2. Load rail and road geometry. Rail-node parsing no longer constructs stops.
3. Validate every stop's infrastructure ID and node index against those networks.
   A bad reference aborts before either stop loader publishes a partial network.
4. Load rail stops and road stops, registering each with its existing parent.
   Publish `InterchangesLoader.stops_linked` when both domains are linked.
5. Spawn the map. Once towns are registered, bind interchange/stop town references
   and then create the physical rail and bus stop scenes.

Invalid catalog or anchor data prevents terrain spawning and emits the
coordinator's `map_loading_failed` signal. Loading a second map into an already
populated service scene is rejected; a new session owns new service instances.

The rail loader retains `NodeStationLinkData` as the adapter for existing signs,
catchment areas and rail inventory consumers. Its `num` is the authored stop ID,
matching the associated `RailStationData.num`. Stops are no longer authored inside
`tracks.json`; their explicit track/node anchors live in the interchange catalog.

## Road views

### Stop billboards and editor previews

Rail and road stops share the existing blue `StationSign3D` / `StationSignPanel`
billboard. Each physical stop shows its interchange's name. In the game, the
sign displays the interchange's live passenger and cargo totals. Click a rail
platform or road shelter to open the station information dialog. Hiding a station
building leaves its sign visible. Road stops serving both directions have one sign.

To preview stops while authoring a map, open `editorobjects_<map>.tscn` separately,
select the `WorldEditorObjects` root, and click **Load Stop Labels JSON**. This
reads `interchanges.json` and resolves its `trackNum`/`roadNum` plus `nodeIndex`
against `tracks.json` / `roads.json`. It creates only billboard labels under
`EditorStops`, 15 metres above each anchor, without platforms, shelters or
simulation station data. Labels have no editor distance cutoff.

Reloading replaces the generated labels, supports undo/redo, and preserves the
previous preview if validation fails. Ctrl+S saves the labels into EditorObjects,
making them visible in the containing world scene too. They refresh explicitly
from JSON, just like infrastructure lines. Runtime removes saved label previews
and creates its own station views, preventing duplicate signs.

Runtime rail stations spawn under `GameSession/WorldServices/Infr/Stations`,
with platform/node views under their station. Bus stops spawn under
`GameSession/WorldServices/Infr/RoadStops`. Interchanges remain data resources.

`BusStop3D` extends `InventoryEntity3D`, uses the 3D station icon and follows its
`RoadStationData.position`. The reusable scene is
`res://scenes/subscenes/infr/station/bus_stop_3d.tscn`. Stops attached to an
interchange expose its stock through their inventory component.

`RoadStopsLoader` positions stops at their authored road nodes and samples the
road curve's horizontal tangent to arrange the shelters. Each shelter's long edge
is parallel to the road and its open side faces inward, including both shelters
of a stop serving both directions. Its adjustable
`roadside_offset_metres` defaults to 4 m because road widths are not currently
part of the authored infrastructure definition. The offset may need adjusting
for individual road widths.

`BOTH_DIRECTIONS` creates two visual shelters for **one** physical stop ID. Either shelter
opens the same station dialog and accesses the same interchange inventory.

## Existing map migration

The previous per-map station catalogs were consolidated into `interchanges.json`:

| Map | Interchanges | Rail stops | Road stops |
| --- | ---: | ---: | ---: |
| franzburger | 1 | 0 | 1 |
| harzmountains | 22 | 19 | 0 |
| mpsb | 23 | 24 | 0 |
| sachalin | 13 | 13 | 0 |

Former rail station IDs became interchange IDs. The first physical rail stop
retains its former parent number; additional platform/node stops received unused
manual numbers above the old range. Those numbers are now authored in JSON and
remain stable on subsequent loads. Unused legacy groups were retained as empty
interchanges. Existing type/building flags were carried onto the physical stops.
Franzburger's authored Hafen stop retains its name, town metadata, road 34/node 3
anchor and continues to serve both directions. Track geometry, handles, fork metadata and node
indices were preserved while removing inline station definitions.
