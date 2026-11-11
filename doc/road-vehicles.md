# Initial road vehicle definitions

`game/jsondata/road_vehicle_types.json` contains the oldtimer car using a Škoda
645 limousine reference profile, GAZ-AA truck, and green Trabant 601 Universal.
`RoadVehicleTypesLoader` loads them as `RoadVehicleTypeData` alongside rail types
during `GameTypes.ensure_initialized()`. The catalog supplies the ROAD domain;
`usable_infr.subtype` can optionally restrict a definition to one infrastructure type.
Train selection continues to use `RailVehicleTypeData` only.

The initial length, width and height are bounding dimensions of the existing OBJ
meshes at unit scale, not historical specifications. The oldtimer's longitudinal
axis is Z; the GAZ truck's is X. The physical vehicle's visual wrapper accounts for this
different orientation. `RoadVehicle3D` wraps these catalog scenes in a physical
vehicle at runtime; see the driving prototype below.

The oldtimer's original OBJ/MTL and texture files contain no manufacturer or
model identification. Following visual comparison and the user's choice, its
working profile is now `Škoda 645 Limousine (c. 1930)`. The stable key remains
`oldtimer_car`, and the mesh and its bounding dimensions are unchanged. This is
an adopted reference profile; the asset's exact manufacturer, year and coachwork
are still unconfirmed. See the [comparison photograph](https://auta5p.eu/katalog/skoda/skoda_645_02.php)
and [Škoda's own wheel history](https://www.skoda-storyboard.com/en/skoda-world/wheels-decades-of-transformation/).

The profile uses 90 km/h maximum speed and 33 kW (45 PS), as reported by
[Škoda's official model history](https://www.skoda.at/markenwelt/skoda-geschichte/skoda-zeitachse)
and [manufacturer press kit](https://www.skoda-storyboard.com/en/press-kits/classic-days-2026-press-kit/skoda-645-1929-1934/).
The game capacity is 6 `PASSENGER`, as chosen by the user to follow the six-seat
limousine described in [Škoda's 2010 press release](https://www.skoda-media.de/press/detail/762/).
As with the Trabant's four-seat profile, driver accounting remains a later
service-simulation decision.

The working unladen mass is 1.54 tonnes, reported for the photographed limousine
by [Auta5P](https://auta5p.eu/katalog/skoda/skoda_645_02.php). It has not been
confirmed against a factory specification for this mesh's exact coachwork.
The same photo catalog gives 100 km/h, whereas Škoda itself gives 90 km/h; the
game follows the manufacturer's 90 km/h figure. A reliable payload rating or
gross vehicle mass was not established, so `payload_tonnes` remains null rather
than being inferred from the number of seats. Historical body dimensions also
vary by variant; the catalog continues to describe the actual mesh dimensions.

Unknown speed, cargo/passenger capacity, mass and motor power remain JSON `null` and runtime
`null`. Road speed, when supplied, must be a positive integer in km/h. Dimensions
use metres, mass uses tonnes, and power uses kW. A supplied capacity uses the existing
`{"cat": "PASSENGER", "amount": 4}` format. Null capacity means unspecified,
while amount zero means explicitly no capacity.

Wheelbase, minimum turning radius, acceleration and braking deceleration are not
model definition fields. The prototype estimates wheel placement from model
dimensions and uses empty mass and motor power with shared handling assumptions.
Model-specific wheel positions and suspension tuning remain necessary.

The GAZ-AA now has a 70 km/h maximum speed, 1.81-tonne unladen mass,
1.5-tonne physical payload, and 30.89 kW engine output (42 metric hp converted
using 0.73549875 kW/hp and rounded to two decimal places). Speed, mass and payload
are supported by the [Victory Museum's GAZ-AA entry](https://victorymuseum.ru/encyclopedia/technic/avtomobilnaya-tekhnika/gruzovoy-avtomobil-gaz-aa-sssr/).
The museum page is internally inconsistent about power: its table says 40 hp
while its description says 42 hp. This catalog uses 42 hp, also reported in
[A. A. Gordin's historical research article](https://history.milportal.ru/voennaya-produkciya/?print=print).
These are base-truck specifications; the existing box-body mesh's exact variant
is unidentified. Mesh bounding dimensions remain unchanged.

`payload_tonnes` is a nullable, nonnegative physical mass limit. It is kept
separate from `capacity.amount`, whose existing game units are not defined as
kilograms. The GAZ-AA's game capacity is 4 units of `FREIGHT`, using the same
`capacity: {"cat": "FREIGHT", "amount": 4}` structure as train types. Shared
categories are `PASSENGER`, `MAIL`, `FREIGHT`, `LIQUID`, and `AGGREGATE`.

The green Trabant mesh represents the three-door Universal estate, including a
rear hatch and roof rack. Its vehicle model scene instances the existing green
mesh at 1.2 scale, matching the decoration scene without changing that scene.
The catalog's bounding dimensions (3.582603 × 1.569755 × 1.572999 m) include this
scale and the roof rack. The mesh's longitudinal axis is X, like the GAZ truck.
Operating values represent the 26 PS version: 100 km/h, 19.1 kW, 0.65-tonne
unladen mass and 0.39-tonne payload. The game capacity is 4 `PASSENGER`, matching
the four-seat layout; the later service simulation can decide how drivers are
accounted for. Sources: the [1975 manufacturer brochure](https://www.trabant-original.de/toupl/uploads/1975_p601lu_de.pdf)
and [Museumsstiftung's Trabant 601 Kombi record](https://onlinesammlung.museumsstiftung.de/detail/collection/0063358e-a590-41ab-a44d-5dc10f715dab).

`RoadStationData` inherits `AbstractStation`, independently of building
`RoadConnection` resources. Road and rail stops belong to named `InterchangeData`
parents and share their name/town metadata. A physical road stop has a manual
stop number, road number, zero-based node index, and direction of travel.
`BOTH_DIRECTIONS` creates two shelter models for one logical stop and inventory.

Every map now uses `jsondata/interchanges.json`, containing mixed rail/road
`stops` arrays. The coordinator loads all interchange parents, both infrastructure
networks, and then both stop domains before spawning their views. See the
[interchange and stop contract](road-stops.md) for the schema, migration details
and startup sequence. Vehicle routing, passenger catchments, destination-aware
inventories and intermodal transfers remain separate work.

## Driving prototype

The route-plan editor, node-to-node pathfinder and planned execution stages are
described in [road transport routing](road-transport-concept.md). Press **R** while
driving a road vehicle to edit its plan. Saving validates the plan without starting
automatic driving or executing goods transfers.
Use **Start plan**, then leave the car, to execute its visits once automatically.
Execution parks at the final visit or pauses at a visit containing transfer
instructions; load/unload does not run yet. U-turns require manual steering.

### Depot spawning

Click a road depot to open its vehicle selector, choose one of the road catalog
models and press **Spawn vehicle**. The existing `SpawnAction` handles both rail
and road requests, with separate signals/dialogs so depot IDs can overlap safely.

Cars spawn parked **10 world metres along the connected road from the depot's
endpoint**, facing away from the depot. A START depot faces increasing road order;
an END depot faces decreasing order. The distance follows bends and parent scale,
rather than a straight offset. Suspension settles the initial body onto the road.
No automatic driving path is assigned. Click the spawned car to drive it.

Roads shorter than 10 metres and occupied spawn points are rejected with a message
in the dialog. Successful spawning and cancellation restore the previous walking
controls and mouse mode. The same operation is available through
`Managers.vehicles.spawn_road_vehicle_at_depot(type_key, depot)`.

The selector loads an optional `preview.png` alongside each catalog model scene:

| Vehicle | Preview path |
| --- | --- |
| Škoda oldtimer | `assets/meshes/vehicles/road/oldtimer_car/preview.png` |
| GAZ-AA | `assets/meshes/vehicles/road/gaz_aa_truck/preview.png` |
| Trabant | `assets/meshes/vehicles/road/trabant_601/preview.png` |

Missing pictures leave a placeholder; names and selection remain available.

### Driving and collision

Roads enable PathMesh3D's `COLLISION_MODE_TRIMESH` before their mesh child enters
the tree. Rail infrastructure enables collision only for visible bedding; rails
and sleepers remain visual so their edges do not obstruct walking. Collision is generated
from the warped geometry, with the mesh/path transforms already applied, and
rebuilds on curve edits. `hideFill` removes both the bedding visual and its
collision. These bodies use the default physics layer 1; the walking player's
existing mask 7 already includes it. Render layers are independent of physics
layers. The player uses `CharacterBody3D.move_and_slide()`, not direct terrain
height placement.

Run `tests/road_vehicle_preview.tscn` with F6 for a road, raised rail bed, walking
player and automatically driven Trabant. **E** takes control or leaves; **R**
opens route setting while driving, or restarts when on foot. Drive with **W/S**
or **Up/Down**, steer with **A/D** or **Left/Right**,
and brake with **Space**. On foot, use the arrow keys and mouse. Escape releases
the mouse. Close the running scene when finished.

`RoadVehicle3D` uses `VehicleBody3D` and four `VehicleWheel3D` children. The catalog
model becomes a visual child, with its old static collider and train-specific root
script removed. It has a low, explicit centre of mass, a chassis collider and a
chase camera. Forward is Godot's vehicle convention, +Z. Existing model wheels
remain part of the static visual mesh; individual wheel animation is not yet
available. Dimensions and handling are approximations, not a validated simulator.
See [Godot's VehicleBody3D documentation](https://docs.godotengine.org/en/stable/classes/class_vehiclebody3d.html).

Spawn in a loaded map through the existing service:

```gdscript
var road_numbers: Array[int] = [101, 102]
var vehicle: RoadVehicle3D = Managers.vehicles.spawn_road_vehicle(
	"trabant_601_green", road_numbers
)
```

The IDs are an ordered, continuous route. `backwards=true` reverses the first
road; subsequent roads orient to the preceding endpoint. Disconnected sequences
are rejected without replacing an existing route. Route samples use world metres,
including parent transforms and scale. This is route execution; choosing paths
through the road network is a separate layer.

Without a player, the route supplies speed and steering requests to the same
physical vehicle. It slows for bends and brakes before the final endpoint.
`route_finished` emits once when stopped. Vehicles without a valid route brake.
Clicking a road vehicle in the game calls `VehiclePlacer.enter_road_vehicle()`;
the existing radial **Enter** action leaves it. Taking control preserves position
and momentum and lets the player drive freely. The walking body is suspended and
its original collision settings restored on exit or deletion of an occupied car.
On release the route driver resumes near its saved progress. A vehicle more than
six metres off-route, or facing away from its next target, brakes instead of
teleporting. Drive back near the route and face along it before leaving.

This first pass does not choose routes, serve stops, account for loaded cargo
mass, or avoid other traffic. It follows the centreline, so lane offsets and
junction rules are still needed for two-way traffic. Full mesh collision adds
physics geometry; large-map performance still needs profiling. PathMesh3D must
successfully render a segment before it can collide: its existing minimum tile
length limitation still applies to very short curves.
