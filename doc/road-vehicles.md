# Initial road vehicle definitions

`game/jsondata/road_vehicle_types.json` contains the oldtimer car using a Škoda
645 limousine reference profile, GAZ-AA truck, and green Trabant 601 Universal.
`RoadVehicleTypesLoader` loads them as `RoadVehicleTypeData` alongside rail types
during `GameTypes.ensure_initialized()`. The catalog supplies the ROAD domain;
`usable_infr.subtype` can optionally restrict a definition to one infrastructure type.
Train selection continues to use `RailVehicleTypeData` only.

The initial length, width and height are bounding dimensions of the existing OBJ
meshes at unit scale, not historical specifications. The oldtimer's longitudinal
axis is Z; the GAZ truck's is X. Its future visual wrapper must account for this
different orientation. Model paths currently identify the existing scenes; these
definitions do not instantiate or make them drivable.

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
model definition fields. Future movement can use motor power and loaded mass as
inputs to an acceleration model, with shared assumptions for traction and
resistance. Braking and junction motion remain movement-system decisions.

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
stop number, road number, zero-based node index, and road side. `BOTH` creates
two shelter models for one logical stop and inventory.

Every map now uses `jsondata/interchanges.json`, containing mixed rail/road
`stops` arrays. The coordinator loads all interchange parents, both infrastructure
networks, and then both stop domains before spawning their views. See the
[interchange and stop contract](road-stops.md) for the schema, migration details
and startup sequence. Vehicle routing, passenger catchments, destination-aware
inventories and intermodal transfers remain separate work.
