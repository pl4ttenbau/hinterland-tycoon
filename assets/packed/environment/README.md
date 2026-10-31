Shared daylight
===============

All four maps and the default terrain instance `day_environment.tscn`.
It uses AgX, exposure 1.2, sky energy 1.5, ambient energy 1.2, and a slightly warm
sun at energy 1.15 with filtered shadows (angular distance zero), bias 0.15,
opacity 0.9, and two blended shadow splits fading from 60 to 120 m, ordinary distance haze,
and restrained glow. SDFGI, SSIL, volumetric fog and SSAO stay disabled. SSAO
was tested in a fixed MPSB view and was the largest additional GPU cost; its
mild radius/intensity settings remain available for a future higher quality mode.
Project settings retain Low, half-resolution SSAO with a distance fade if enabled.

Final color adjustments use contrast 1.03 and saturation 1.04, with exposure
remaining at 1.2.

Fog is disabled in the saved scene for clear map editing. The WorldEnvironment's
`game_world_environment.gd` script enables it on a private Environment copy when
the game runs, preserving the saved fog density and color.

The MPSB camera-distance dark band is still under investigation. The latest
shadow settings are a conservative mitigation, not a confirmed complete fix.

`LocalReflections` creates at most four outdoor probes at runtime, prioritizing
depot yards, then stations, and skipping sites within 60 m of an existing probe.
Each covers 80 x 30 x 80 m, captures from 4 m above the site, and blends over 8 m.
The shared reflection atlas uses 128-pixel faces with eight available slots.
Capture LOD is reduced and captured shadows are disabled to limit startup work.
No continuously updating or camera-following probes are used.

Captures exclude Water and Vehicles; spawned train geometry is normalized onto
the existing Vehicles render layer, including legacy models authored on Deco.
Vehicles still receive probe reflections. Sky reflections cover the rest of the
map. Diffuse ambient lighting continues to come from the shared sky everywhere.

Loading/construction signals request a debounced refresh after 0.75 seconds.
Captures are staggered by eight frames. The periodic world-update tick does not
refresh them. For future construction paths that emit no existing spawn signal,
call `DayEnvironment/LocalReflections.request_refresh()` after the geometry is ready.
Probe settings and the budget can be overridden on the LocalReflections instance;
set `max_probes` to zero to use sky reflections alone.

The automatic probes are outdoors. A future accessible interior should use a
separate room-sized probe with Interior and Box Projection enabled.

Regression check (from the project root):

```sh
godot --headless --path . --log-file /tmp/world-environment-tests.log res://tests/world_environment_test.tscn -- --no-mcp
```

The check covers shared map dependencies, daylight settings, vehicle capture
exclusion, probe limits/spacing, translated environments, loading debounce,
construction refreshes, and absence of recaptures on periodic world ticks.
