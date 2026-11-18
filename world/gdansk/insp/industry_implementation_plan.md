# Gdańsk industry comparison and placement plan

Status: **first placement pass completed**, 7 November 2026. Twenty placeholders now live in `mapscenes/industries_gdansk.tscn`, instanced under WorldGdansk. Recipes, goods, runtime code and terrain remain unchanged. See [placement notes](industry_placement_notes.md) and `../source/industry_placement.json` for actual coordinates and limitations.

User decisions: include the refinery despite its historical 1975 opening; place the industries under Gdańsk's WorldIndustries container. Where agricultural products are unknown, split sites equally: **four FARM and four RANCH**. These assignments are gameplay choices, not verified historical production. Milk is a worthwhile future addition, also relevant to MPSB, but **do not implement milk now**.

Historical evidence and dates: [industry research](industries_research.md).

## Current project state

- `world/gdansk/mapscenes/world_gdansk.tscn` now instances a dedicated `industries_gdansk.tscn` as `Industries`, using `WorldIndustries`, with **20 direct industry placeholder children**.
- The live catalog is `game/gamescripts/resources/structures/industry/industry_recipe_catalog.gd`: **26 types**. The goods catalog is `game/gamescripts/services/typeloaders/goods_types_loader.gd`. The empty `game/jsondata/industry_structures.json` is not the recipe source.
- Existing Franzburger and Sachalin worlds use direct `IndustryPlaceholder` children of `Industries`, each with a unique industry number, a `type_key`, a display name and a transform. The runtime spawner and editor supply checker both inspect direct children.
- Existing meshes are shared generic representations. Recipe compatibility does not imply a historically matching factory model.

## Comparison against existing recipes

Recipe quantities below are the catalog's transformation amounts, not a promise of hourly output or balanced map-wide production.

| Historical candidate | Existing type / actual recipe | Decision for later placement |
| --- | --- | --- |
| Nowy Staw sugarworks | `SUGAR_MILL`: 6 beets → 3 sugar | Strong fit. Place at the historical works. Molasses and pulp remain unrepresented. |
| Stare Pole sugarworks | `SUGAR_MILL`: 6 beets → 3 sugar | Strong fit. Second sugar destination. |
| State farms around Koszwały, Krzywe Koło, Grabowe Pole, Nowa Cerkiew, Orłowo, Cyganka and Nowotna | `FARM`: produces 4 grains + 2 beets without inputs | Eight agricultural sites placed using historical PGR building clusters and modern location references: four use FARM, four RANCH, per user instruction where production is unknown. The current farm recipe cannot specialize in just one crop. |
| Livestock farming | `RANCH`: produces 3 meat without inputs | Four of the eight agricultural sites use this abstraction. This is a gameplay allocation, not evidence of cattle specialization. It produces meat, **not** milk. |
| Nowy Staw brickworks | `BRICKWORKS`: 5 gravel → 2 bricks | Usable game abstraction. Gravel substitutes for clay; coal is not consumed. Verify 1960 operation and location before placement. |
| Stegna fishing cooperative / landing facilities | `FISHERY`: 2 lumber + 1 grains → 5 fish | Existing type fits the output. Inputs are game abstractions. Verify a landing/collection site rather than inventing a cannery or siding. |
| Gdańsk refinery | `OIL_REFINERY`: 6 oil → 4 chemicals | **Include, as requested.** Its output is chemicals, not a separate fuel good. Needs a represented oil supply. Keep the historical 1975 date in research, while allowing it in this scenario. |
| Tczew gasworks | `COAL_PLANT`: consumes 4 coal, no outputs | Possible coal-demand proxy. Does not reproduce town gas, coke or tar. Display/name and generic power-plant interpretation need to be accepted as an approximation. |
| Tczew gearbox works / gas-meter factory | `WORKSHOP`: 3 ingots + 2 coal → 1 weapons + 1 machines | Partial fit only: machines are useful, but both factories would also produce weapons with the unchanged recipe. Do not describe this as an exact match. |
| Nowy Dwór workshops; Tczew railway facilities; Przeróbka repair works; Sztutowo machine service | `SMITHY`: 2 ingots + 1 coal + 2 lumber → 2 tools + 1 rail_tracks; alternatively `WORKSHOP` above | Generic metal/railway-service proxies. Prefer a small selection instead of duplicating every historical workshop. `SMITHY` avoids weapons but still manufactures tools/tracks rather than repairing vehicles. |
| Górki Zachodnie shipyard; possible smaller Przegalina/Tczew yards | `SMITHY` or `WORKSHOP` | Partial fit, as above. Franzburger already represents Volkswerft with `SMITHY`. No ships or repair-service good exists in the current cargo catalog. |
| Nowy Staw maltings | No malt good or maltings type. `BREWERY` takes 6 grains + 2 sugar → 3 alcohol | Reserve for later or leave as scenery. Calling it a brewery changes its product and demand; it is not a clean mapping. |
| Nowy Staw dairy; Nowy Dwór district dairy/Maluta; Rybina dairy lead | No milk good, dairy products or dairy recipe | **Reserve for future milk implementation.** Do not substitute meat or fish for milk. Exact historic sites still need locating. |
| Łaszka milk collection; farm milk loading | No milk good or collection/depot mechanism dedicated to it | Reserve for the same future chain. A collection point should transfer/aggregate milk, not create milk without a farm source. |
| Tczew yeast/starch works | No molasses, yeast or starch goods/recipes | Leave the detailed chain for later. `BAKERY` would produce bread rather than yeast and would obscure the actual industry. |
| Chłodniewo drainage pumping station | No matching industry/service type | Landscape/infrastructure landmark; not a coal plant proxy. |
| Wiślinka phosphogypsum site, from 1972 | No phosphogypsum good or matching disposal consumer | Later scenery or future waste destination. `FERTILIZER_FACTORY` is not a substitute for a waste dump. |

## Supply and demand that placement must resolve

1. **Oil:** the refinery requires oil. Sachalin already uses `OIL_WELL` as a dock proxy, named “Chomsk Liquid Docks.” A similar oil-receiving proxy could keep the Gdańsk refinery supplied without inventing a local oilfield. It must be labelled as a gameplay import abstraction; location and visual treatment remain to be chosen. Do not imply a historical narrow-gauge crude-oil service.
2. **Coal and ingots:** workshop proxies and the gasworks consume imported industrial materials. No local coal mine or smelter has been established by this research. Do not add fictitious local mines simply to clear warnings. Represent imports explicitly in a later design, or record these as intentional unresolved imports. An unchanged `COAL_MINE` or `SMELTER` used as a depot would also need an explicit proxy decision.
3. **Gravel:** brickworks need gravel under the existing recipe. Locate a defensible extraction site or choose an import abstraction. A gravel-producing `QUARRY` also produces stone, and its generic mineshaft model is a visual compromise.
4. **Lumber:** the fishery and `SMITHY` consume lumber. A `FOREST` can produce it if a suitable managed woodland site is supported; otherwise treat it as imported. A `SAWMILL` makes boards, **not** the lumber these recipes require.
5. **Markets:** sugar, grain and fish need consumers or an export role. Existing `BAKERY` uses grains and sugar; `RESTAURANT` uses alcohol, bread and fish; stores consume food, and `BIG_STORE` also consumes coal and machines. These are optional gameplay destinations, not newly verified named factories. Alcohol and meat supply must also be addressed if those consumers are selected. The current catalog has no malt, milk, molasses, yeast, dairy products, fuel, gas, coke or tar.
6. **Refinery output:** chemicals need an outlet. `FERTILIZER_FACTORY` can use chemicals plus beets, but no suitable named factory inside this crop has yet been verified. Its presence should not be invented merely to consume chemicals. An export mechanism/proxy remains a design issue.

The editor's **Check Industry Supply** checks producer existence only. It does not model transport, imports, rates, output markets or whether the entire network can operate. Passing it is not proof of a balanced economy.

## Placement workflow and remaining work

1. Confirm exact historical factory/farm footprints against the scans and available location evidence; check crop boundaries. Retain GPS, source and confidence for every chosen site. Town-centre coordinates are insufficient for factory placement.
2. First place the clear matches: **two sugarworks, several farms, one brickworks, a fishery and the refinery**. Keep unresolved import/output dependencies visible in the plan.
3. Select a few metalworking/railway/shipyard proxies only after deciding whether their unchanged outputs are acceptable. Add town markets and supply/import proxies as a separate balancing pass.
4. Use direct `IndustryPlaceholder` children of the existing `Industries` node, following the other worlds. An instanced industries subscene could have `WorldIndustries` as its root if desired, but must preserve the node name, world reference and direct-child layout. Do not put a further grouping node between the container and placeholders.
5. Convert verified GPS with the same map bounds, raster offset and terrain transform used by the working world cursor. Sample actual terrain height and check water/shore placement. Assign unique industry numbers and meaningful display names; save original GPS and proxy notes in a placement manifest.
6. Validate keys/IDs, direct-child discovery, terrain placement and the supply report; inspect runtime spawning and visual overlaps. Classify intentional imports separately from genuine omissions. Do not alter shared recipes just to make one map pass.

The first scene placement is now complete. Milk/dairy implementation, new recipes, input/output balancing, transport connections and any detailed landscaping remain **future work**.
