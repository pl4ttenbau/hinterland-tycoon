# Industry production and stock

An industry linked to an interchange consumes and produces goods in the interchange's inventory. Deliver to any of its road or rail stops to supply the industry. The output is available at every stop in that interchange. The industry also exposes the same stock in the manual transfer dialog. An unconnected industry uses its own inventory.

Each interchange starts with a capacity of 60 units shared by all its stops and linked industries. Physical stops retain their positions and IDs for transfer reach and route actions. Click a rail platform or a road shelter to see the city above the station name, followed by stops, connected industries, connected home count, and live inventory. Passenger destinations use the interchange and show its city and station name. Click an industry to see its inventory location, recipe quantities, and current stock.

`IndustryProduction.run_cycle()` runs one batch on the existing five-second timer. Each batch checks all inputs and the space left after they are consumed. A successful batch consumes the inputs, adds the outputs, and signals the inventory once. When inputs are missing or a batch would exceed capacity, the stock stays as it was. A batch that drains stock can still run if older stock already exceeds capacity.

Raw producers such as coal mines have no inputs. Consumers such as coal plants remove their inputs every successful cycle. Recipes can use fractional cargo quantities, while passenger quantities use whole numbers. Recipes only use unassigned passengers, which keeps passengers with a destination available for their trips.

`IndustryRecipeCatalog` supplies both the simulation and the map editor's missing-producer check. Milk is registered as liquid cargo under the key `milk`. Dairy production and consumption can be authored in that catalog.

## Mine depletion

Player-built mines draw their selected resource from deposit cells with centres
within **100 m** of the site. Each cell covers **16 × 16 m** and starts with
**800 reserve units at 100% richness**, scaled by the geology at its centre.
A successful batch drains the same fraction of each cell's remaining reserve.
Mines that overlap share those cells for the same resource. Mines about 200 m
apart can work separate ground. Rebuilding reuses any worked-out cells.

Tune **Depletion Factor** on the **Prospecting** node in the World Services scene.
It defaults to **1.0**, so each cargo unit uses one reserve unit. Doubling the
factor halves the amount a deposit can deliver. At full richness across the
whole area, one mine has roughly **34 hours** of uninterrupted production at
the current five-second batch cadence. Time spent waiting for storage to clear
doesn't use reserves. The final batch ships whatever is left, and the industry
dialog shows remaining reserves or **Deposit worked out**.

The session holds reserves in memory by cell coordinate and resource key.
Mineral PNGs and survey readings still describe initial geology. When save/load
is added, the cell balances must include exhausted cells, and loaded mines must
reattach to those shared records. Authored industries keep their catalog recipes.

A future **Deepen Mine** upgrade can extend a deposit's productive life for
money. Repeated upgrades should increase the cost and modify the existing
deposit records so all mines using those cells see the added reserves.

Run the focused headless checks from the project root.

```sh
godot --headless --path . --script res://tests/industry_production_test.gd -- --no-mcp
godot --headless --path . res://tests/interchanges_test.tscn -- --no-mcp
```

The production suite checks inputs, capacity, notifications, mine depletion,
passenger stock, and fractional milk. The radial action suite checks shared
mining areas and production into a real road stop. The interchange suite
delivers lumber at a road stop, runs a linked sawmill, checks the output from
a rail stop, and opens the station dialog from both physical models.
