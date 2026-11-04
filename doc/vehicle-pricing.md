# Initial vehicle prices

Prices are fictional game DM. This first step displays purchase prices in the
vehicle picker; it does not yet introduce a wallet, payments, upkeep or income.

Each entry in `game/jsondata/rail_vehicle_types.json` and
`game/jsondata/road_vehicle_types.json` now has a `purchase_price` field. The
initial 17 rail and 3 road prices were generated with the balance resources below.
A stored price is a positive integer in whole game DM and takes precedence over
the formula, allowing individual balancing. Unknown prices use `null`. Missing
or null prices fall back to the formula if sufficient specifications exist.
Changing the formula does not overwrite stored prices; regenerate them explicitly
when applying a new balance. Initial locomotive values include the mass-based
strength estimate described below.

The shared balance resource is `game/jsondata/rail_vehicle_pricing.tres`. Edit it
in the Inspector to tune all rail prices without editing individual vehicles.
`RailVehicleTypeData.get_purchase_price()` returns the stored price or calculates
a fallback from current stats, returning integer DM or `null` if both the stored
price and required specifications are unknown.

Initial formulas, before rounding up to the next 100 DM:

```text
speed multiplier = 0.75 + maximum speed (km/h) / 160
locomotive price = (20,000 + 250 × power (kW) + 1,000 × strength (kN)) × speed multiplier
wagon price      = (2,000 + 300 × transport capacity) × speed multiplier
```

Powered railcars also add `300 × transport capacity` inside the locomotive
subtotal. Capacity uses the catalog's existing game units; each passenger or
cargo unit has the same initial coefficient, regardless of category. These are
balancing values, not historical prices or comparable physical cargo weights.

Strength means starting tractive effort. Catalog entries can supply a positive
`tractive_effort_kn` number, or omit it / use `null` when unknown. The mapper
preserves this distinction and rejects invalid values. Until it is authored,
the temporary estimate is `empty mass (tonnes) × 9.81 × 0.25`, in kN. This assumes
all empty mass contributes to adhesion; real driven-axle weights are not yet
modelled. Estimated prices show `~DM` and an explanatory tooltip in the picker.
Existing catalog masses need review before treating these prices as balanced.

For example, a locomotive with 400 kW, 100 kN and a 50 km/h top speed costs
DM 233,800. A 50-unit wagon rated for 60 km/h costs DM 19,200. Faster, stronger
and more capable stock costs more; small changes may share a rounded price.

Missing speed, locomotive power, both strength and mass, or wagon capacity yields
an unknown price rather than zero.

## Road vehicles

Powered road vehicles use `game/jsondata/road_vehicle_pricing.tres`, independently
of the rail balance. Their `get_purchase_price()` follows the same integer DM /
`null` convention. The road depot dialog displays the selected vehicle's price.

```text
road price = (3,000 + 100 × power (kW) + 500 × transport capacity) × (0.75 + speed (km/h) / 160)
```

Round up to 100 DM. Capacity uses existing game units, with the same initial
coefficient for passengers and freight. Physical payload tonnes and empty mass
are not charged separately. Unknown speed, power or capacity stays unpriced;
an explicit zero capacity still pays for the chassis and motor. Trailers are
not priced yet. This does not introduce payments or historical pricing.

Current catalog: Škoda 645 DM 12,300; GAZ-AA DM 9,700; Trabant 601 DM 9,600.

Run the formula, catalog and picker checks with:

```sh
godot --headless --path . --script res://tests/rail_vehicle_pricing_test.gd -- --no-mcp
godot --headless --path . --script res://tests/road_vehicle_pricing_test.gd -- --no-mcp
```
