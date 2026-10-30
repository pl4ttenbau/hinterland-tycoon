# MPSB 12 main chimney exhaust

Integrated on 2026-10-30 for Godot 4.7.2 Mobile.

`assets/meshes/vehicles/rail/mpsb_12/model_mpsb_12.tscn` now instances
`addons/steam_exhaust/steam_exhaust.tscn` at `Steam/ChimneyExhaust`.
The game-specific bridge is
`game/gamescripts/nodes/vehicle/movement/mpsb_12_chimney_exhaust.gd`.
The original `Steam` controller still drives only the two cylinder emitters.
Other locomotives are unchanged.

## Behavior

- The chimney mouth was measured from the existing glTF mesh. The outlet is at
  `(-0.002134, 2.925, -2.461572)` in locomotive-local space, just above its lip.
- Actual world displacement is sampled at physics frequency, after the parent
  train moves. This avoids render-rate velocity spikes and handles reversing.
- Exhaust beats derive from world speed, four beats per wheel revolution, and
  a 0.7 m driving-wheel diameter. The diameter is a visual model-scale estimate;
  no separate wheel animation exists here to provide an exact phase.
- The current motor exposes target/current speed and a brake, rather than boiler
  or regulator pressure. The bridge estimates effort: acceleration 0.9, cruise
  0.45, braking/coasting 0.05, stopped 0.0. A small idle plume remains when stopped.
- Wind is an exposed world-space vector on the exhaust instance.
- The effect preserves particle visibility layer **64**, uses 256 allocated GPU
  slots, simulates at 30 Hz with interpolation, and fades out at 120 m.
- Large motion jumps clear the trail. For floating-origin changes, explicitly
  call `reset_trail()` if needed.

For appearance, edit the `ChimneyExhaust` instance: opacity, size, wind, lifetime,
and light/shadow tints. Static shape changes require **Apply shape / restart
preview**, or a scene restart. For lower actual particle allocation use Low
quality and apply/rebuild. This uses tinted, baked-light sprites, not local-light
volumetric simulation.

## Verification

```bash
godot --headless --path . --scene res://tests/mpsb_12_exhaust_test.tscn -- --no-mcp
godot --headless --path . --scene res://tests/train_path_test.tscn -- --no-mcp
```

The integration suite passed **14 checks**. The existing train-path suite
reported **0 failures**. Geometry, mesh transforms, collision, camera, and both
cylinder-emitter node blocks were compared with the saved pre-edit scene and
remain byte-for-byte unchanged.

Open `tests/mpsb_12_exhaust_preview.tscn` and press F6 for a preview with the
production model and real motor bridge. Space toggles motion; Escape closes it.
It does not load a map or save. Stationary and moving views were rendered and
visually inspected using the actual Mobile renderer.

The project currently also prints an unrelated startup error for the
`EditorSignals` autoload (`uid://c5hs1epbs1eua`), which has no matching source UID.
It appears in the existing train-path test too. The exhaust introduces no script
or shader errors, but these runs are not clean full-game startup validation.
No changes were made to `project.godot` or unrelated plugin files.

The whole-project reference checker reported existing plugin/reference issues;
none of its errors or warnings point at the exhaust or modified MPSB scene.
Full results, logs, and a file manifest are saved in
`/home/cornelinux/Dokumente/Assets/3D/Generation/MPSB12SteamIntegration`.

The original scene backup was removed at the user’s request after visual
acceptance on 2026-10-30. The integrated MPSB 12 scene remains in place.
