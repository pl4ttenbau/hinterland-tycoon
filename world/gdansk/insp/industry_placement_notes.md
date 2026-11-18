# Gdańsk industry placement — first pass

Placed 7 November 2026 in **WorldGdansk / Industries**. The root is an instance of `../mapscenes/industries_gdansk.tscn`; its markers are direct children of `WorldIndustries`, matching runtime discovery. The world reference remains connected to WorldGdansk.

| Type | Count | Sites |
| --- | ---: | --- |
| SUGAR_MILL | 2 | Nowy Staw, Stare Pole |
| BRICKWORKS | 1 | Nowy Staw |
| OIL_REFINERY | 1 | Gdańsk refinery, included despite its historical 1975 start |
| FISHERY | 1 | Stegna fishing landing hinterland |
| WORKSHOP | 2 | Tczew gearbox works and gas-meter factory |
| SMITHY | 4 | Nowy Dwór narrow-gauge workshops, Zajączkowo railway workshops, Przeróbka ZNTK, Górki river shipyard |
| COAL_PLANT | 1 | Tczew gasworks as a coal-demand proxy |
| FARM | 4 | Koszwały, Grabowe Pole, Orłowo I, Cyganka |
| RANCH | 4 | Krzywe Koło, Nowa Cerkiew, Orłowo II, Nowotna |
| **Total** | **20** | |

The equal farm/ranch split follows the user's instruction where actual production is unknown. These are not claims that individual PGRs specialized in crops or livestock. RANCH currently produces meat; milk has not been added.

## Position evidence

The [placement manifest](../source/industry_placement.json) retains original reference GPS, actual placement GPS, world positions, sources, location confidence, local terrain adjustments and recipe compromises for every marker. Source snapshots are `../source/originals/osm_industry_sites.json` and `osm_industry_detail.json`, © OpenStreetMap contributors, ODbL 1.0: <https://www.openstreetmap.org/copyright>.

Several farm locations were read from labelled PGR building clusters on the historical scans. Their approximate neatline coordinates were converted from Pulkovo 1942 to WGS84 using GDAL/PROJ. Allow roughly **200 m horizontal uncertainty** for those readings; the scans themselves are later than 1960. Modern farmyard/factory locations likewise do not independently establish 1960 footprints.

Stare Pole uses a National Heritage Institute coordinate, Górki uses the shipyard's published coordinate, and several other sites use contemporary factory/yard references checked against the historical research. The Nowy Staw brickworks location remains an approximate industrial-quarter placement, not a surveyed kiln footprint.

Terrain heights were sampled from the **current imported Terrain3D regions**, using the same bounds, 3599 sample intervals, raster offset and vertex spacing as the world cursor. Some markers were moved a short distance within their local quarter to avoid water or reduce slope. Their actual coordinates differ from their retained reference GPS. Centre heights are on the terrain, and sampled footprint points are above the existing water plane. **Terrain was not flattened**; the Stegna landing and Tczew gasworks sit on slopes and need later visual landscaping if the generic buildings do not fit well.

## Production limitations and deferred work

- Existing recipes are unchanged. WORKSHOP produces weapons as well as machines; SMITHY produces tools and track. These are proxies, not historical weapons-production or shipbuilding recipes.
- The supply checker reports five unresolved imported inputs: **coal, gravel, ingots, lumber and oil**. No fictional local mines, smelter or oilfield were added just to remove warnings.
- Output markets/exports and transport connections are not yet balanced or laid out. The refinery currently produces chemicals rather than a distinct fuel cargo.
- Dairies, milk collection, maltings, yeast/starch production, drainage infrastructure and the phosphogypsum site remain reserved for later representation.
- The original world scene is backed up in `../source/versions/before_industry_placement.zip`.

Research: [historical industries](industries_research.md). Recipe comparison and remaining workflow: [implementation plan](industry_implementation_plan.md).

## Verification

Headless Godot loaded and instantiated the full world PackedScene, resolved the Industries world reference, and checked all 20 direct markers, type keys, unique IDs and transforms. All four shared runtime model scenes loaded and instantiated. Terrain-region files and the shared recipe catalog were verified unchanged. The full-project reference checker reports the same 15 pre-existing errors as before, with **no new errors and no Gdańsk reference errors**. No graphical editor or in-game visual inspection was performed. Results: [validation record](../source/industry_placement_validation.json).
