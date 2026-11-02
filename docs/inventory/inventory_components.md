# Inventory components and manual transfers

Add an `InventoryContainer` node directly below an entity to give it inventory. The entity does not need to inherit `InventoryEntity3D`: road vehicles use the same component while retaining `VehicleBody3D` physics. Existing player, train and stop scenes keep their authored resources and capacities.

The component exports a `GoodsInventory`, an optional display name, an accepted-category list and a capacity override. An empty category list accepts all categories. An override of `-1` keeps the resource's capacity; `0` explicitly means no room. New components without an assigned resource create their own inventory with the existing default capacity. Road vehicles configure capacity and accepted category from the vehicle catalog. Train capacity continues to use the existing train inventory resource.

## Responsibilities

- `GoodsInventory`: aggregate stock and passenger batches keyed by physical destination stop ID. Existing aggregate consumers, such as station signs, still see the total counts. `change_stack` is a low-level mutation method; it deliberately does not enforce destination capacity or interaction distance.
- `InventoryContainer`: entity composition, capacity and accepted categories.
- `InventoryEndpoint`: weak references to a live component and its world access position. Vehicle passengers access their own bag at the occupied vehicle, rather than at the suspended walking body's old position.
- `InventorySelectionService`: discovers the player, occupied vehicle, nearby road/rail stops, vehicles and industries; deduplicates by inventory resource identity.
- `InventoryTransferService`: validates both inventories, resource category, available stock, capacity, finite positive quantity, whole passenger counts and the 20 m access distance. Both inventories change before either emits its change signal.
- `InventoryTransferPanel`: reusable entity picker, capacity indicator, search and stock table.
- `InventoryCategoryTabs`: reusable full-width passenger/cargo switch.
- `InventoryTransferDialog`: layout, quantity controls and transfer commands. Widgets never mutate stock themselves.

## Passenger destinations

Passenger rows are grouped by resource type and **physical stop ID**, so two platforms or roadside stops in the same interchange remain distinct destinations. Transfers preserve that ID. The exported destination groups are subsets of existing aggregate passenger totals and survive resource save/load.

Existing aggregate-only passengers appear as `Unassigned`; destinations are not inferred retroactively. New spawning always resolves a valid physical destination or discards the attempt. Legacy removals without a destination can only consume unassigned passengers, preventing accidental removal from a different target group.

`PassengerTripPlanner` rebuilds a compact population-weighted list of live residences each attempt. Each building's weight is the sum of its two catalog population counts. It chooses an origin and a different destination by those weights, keeping disconnected residences in the draw. If either chosen building has no live connected stop, or both resolve to the same physical stop, the attempt is discarded without retrying. It uses the connector's first live reachable stop, in access-distance order; transport-network reachability is not checked yet.

`PassengerSpawnRequest` carries the resolved origin/destination residence IDs and physical stops between planning and spawning. `StationGoodsSpawner` creates exactly one passenger directly in the origin stop inventory, tagged with the destination stop ID. It checks the origin's category and free capacity; destination occupancy does not suppress travel demand. No temporary passenger Node is created. The existing global three-second timer is unchanged, and no timed despawning is introduced.

## UI and verification

The existing load/unload action opens the new dialog. Cargo and passengers have separate searchable tables; select a row, enter a quantity or press Max, then use a direction button. Disabled moves explain category/capacity/range restrictions. Refresh nearby re-discovers endpoints. Closing restores the exact prior input and walking state.

Run `godot --headless --path . --script res://tests/inventory_transfer_test.gd` for component, transaction, passenger and GAZ dialog integration checks. The test runner exits nonzero for failures or aborted tests. `tests/inventory_transfer_preview.tscn` renders both tabs to `/tmp/inventory-{cargo,passengers}.png` and closes automatically.

Run `godot --headless --path . --script res://tests/passenger_spawning_test.gd` for exact seeded weight selection, connection rejection, physical-stop targeting and timer-driven spawning checks.

Automatic route actions still pause at load/unload. They do not execute inventory transfers yet. Map save-game integration remains separate work.
