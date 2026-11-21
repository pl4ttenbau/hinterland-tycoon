# Gdańsk / Żuławy — area A

The requested world key and folder name is `gdansk`.

## Terrain files

- `heightmap_gdansk.exr`: 3600 × 3600, RGB Float32. Each channel contains the same linear elevation in metres. No alpha, normalization, colour correction, gamma, or vertical exaggeration.
- `terrain_master_m.tif`: georeferenced Float32 master containing the same elevations as the EXR.
- `land_dem_resampled_m.tif`: measured land elevations before the +20 m offset and water adjustments.
- `water_mask.tif`: mapped water footprint, 1 = water, 0 = dry land. Same pixel grid as the EXR.
- `terrain_preview.png`: shaded overview for inspection only, never for terrain import.
- `manifest.json`: exact CRS, bounds, sample convention, source attribution, modifications, and suggested import settings.
- `validation.json`: measured output checks and representative coordinate samples.

## Bounds and pixel placement

WGS84 outer sample centres: west 18.6600°, east 19.2130°, north 54.3700°, south 54.0465°. `../jsondata/mapinfo.json` uses the existing world's `[latitude, longitude]` corner convention. Row 0 is north and column 0 is west; there is no vertical flip.

The grid uses a local equidistant cylindrical CRS centred on the selected area. Its small X/Y spacing difference is documented in the manifest. The GeoTIFF pixel-area footprint extends half a sample beyond the listed outer sample centres. The EXR is a vertex grid: 3600 samples span 3599 intervals.

## Elevations and waterways

Water surfaces belong at **20 m**. Mapped sea, river, canal and pond beds lie **2–15 m below that surface**, at elevations 5–18 m. Sea-floor shape is informed by EMODnet and clipped to the agreed range; inland beds are designed from mapped channel widths, not claimed to be measured bathymetry. Beds have local normalized Gaussian smoothing (2-pixel sigma). The first wet samples are 2 m deep, with a smooth 70 m transition towards the deeper bed. The first dry samples are at 20.1 m, easing back to measured ground over 80 m; the outer affected limit is about 94.2 m from mapped water samples. Dry land beyond that strip retains source elevation plus exactly 20 m. The 2 m minimum wet depth necessarily leaves a residual 2.1 m wet/dry step; no 0–2 m shallow apron has been introduced.

Real below-sea-level polders remain below the 20 m water level. Use shaped water meshes limited to the water footprint. A single map-wide water plane would incorrectly flood those dry fields. This task creates source terrain, not water meshes or a playable world scene.

The water and land data describe contemporary geography. Modern embankments, roads and altered waterways may need later edits for the 1960 scenario. Narrow channels without explicit widths use 24 m for rivers and 12 m for canals; rasterization can broaden a narrow channel by up to about one sample at a bank.

## Import

Import EXR elevations with **height scale 1, height offset 0**. Do not reuse an older world's normalized-image conversion such as ×100 +10. Terrain3D supports real metre elevations in RGB EXR. A suggested uniform vertex spacing of 10 m spans 35,990 m; the manifest explicitly records its tiny difference from the GIS span. Smaller game-world spacing would be geographic compression and should be chosen explicitly.

The terrain has since been imported and the Gdańsk world scene created. `defaultYear` is now **1968**, following the agreed setting for the four added Gdańsk neighbourhoods. Their locations and validation are recorded in `gdansk_town_additions.json` and `gdansk_town_additions_validation.json`.

## Sources and reproduction

- GUGiK / PZGIK Polish bare-earth NMT, WCS coverage `DTM_PL-KRON86-NH_TIFF`: native 1 m terrain, downloaded at 10 m, EPSG:2180, PL-KRON86-NH elevations. WCS capabilities declare no fees or access constraints. https://www.geoportal.gov.pl/pl/dane/numeryczny-model-terenu-nmt/
- EMODnet Bathymetry Consortium (2024), EMODnet Digital Bathymetry (DTM 2024), CC BY 4.0. Created by EMODnet, owned by the European Union. https://doi.org/10.12770/cf51df64-56f9-4a99-b1aa-36b8d7b743a1 . Source depths refer to LAT, not the land datum; the source only shapes bounded designed game depths, without claiming a datum conversion.
- © OpenStreetMap contributors, ODbL 1.0, coastline and water geometry. https://www.openstreetmap.org/copyright

Unmodified downloaded tiles, service metadata and OSM extracts are retained in `originals`. A full-area Polish WCS request returned incomplete data without declaring NoData; that rejected raster is not used. Small tiles avoid that service limitation.

To resume the tiled download, then rebuild, using the installed system GIS Python:

```sh
PYTHONNOUSERSITE=1 /usr/bin/python3 download_nmt.py
PYTHONNOUSERSITE=1 /usr/bin/python3 build_heightmap.py
```

`PYTHONNOUSERSITE=1` selects the system NumPy compatible with the installed GDAL bindings. Rebuilding is local once the original tiles and geometry are present.

## Additional bank smoothing

The previous EXR, master, metadata, script and preview are preserved in `versions/before_extra_bank_smoothing`. The main EXR filename is unchanged, so reimport it to use the smoother version. GPS bounds and the 3600 × 3600 grid are unchanged.

## Existing imported scene

The renamed world scene is `res://world/gdansk/mapscenes/world_gdansk.tscn`. The existing terrain import is preserved at sample origin `[-1800, -1800]`, vertex spacing 1, and import height scale 0.8. `mapinfo.json` now matches that origin so GPS placement works. These are the current scene settings, separate from the unscaled metre elevations in the source EXR.
