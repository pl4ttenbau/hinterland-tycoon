# Ostaszewo road painting trial — 2026-11-08

Painted RoadGround (verified current texture slot 11) at width **5 game units**, with a hard edge, around Ostaszewo only. The main village street, east and southwest connections, and short junction arms form a sparse framework. Side streets, house plots and additional gaps are left for manual layout at the compressed world scale.

The manually traced reference is **N-34-62-B Ostaszewo, edition 1970–74**, used as an approximate guide for the 1968 scenario. Individual road opening dates were not established. The preview shows selected routes in orange and the existing Towns marker in blue; the reference scan itself was not edited.

`road_trace.json` records the fitted geographic coordinates, game coordinates and hard-brush mask. `paint_validation.json` records 4,334 painted terrain samples in six regions, reloaded and verified after saving. All height and colour maps, all control samples outside the stroke mask, and the other 251 region files were unchanged. No backup was created, as requested.

Modern S7 embankments were neither used as road evidence nor altered. The nearby Koszwały–Nowy Dwór Gdański expressway opened on 31 October 2018: https://www.gov.pl/web/gddkia/s7-koszwaly--nowy-dwor-gdanski

The generation script lives at `/home/cornelinux/Dokumente/ChatGPT/MapMaking/historical_maps/gdansk/build_ostaszewo_roads.py`. Use `PYTHONNOUSERSITE=1 /usr/bin/python3` for that GIS script to keep the system GDAL/NumPy versions compatible. The Godot helper defaults to inspection; saving requires its explicit `--apply` argument. It does not add road meshes or town nodes.
