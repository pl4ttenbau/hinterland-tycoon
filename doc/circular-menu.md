# Circular action menu

Right-click opens the menu. Hold and release over a segment to choose it, or
release quickly and click a segment. Escape cancels, including during opening.
The game pauses walking/driving input while the menu owns it, then restores the
previous mouse and movement settings before launching an action or dialog.

| Action | Availability |
| --- | --- |
| Enter train / Leave vehicle | A train is available / player occupies a vehicle |
| Auto-routing | Player occupies a road vehicle |
| Place road marker | On foot, with the session's roads loaded |
| Create stop | On foot, with the session's station services loaded |
| Connect tracks | On foot, with rail services loaded |
| Prospect | During gameplay. Step out of the vehicle to take a reading. |
| Build | During gameplay with terrain loaded |
| Inventory | During gameplay |
| Company information | During gameplay; empty themed dialog |
| Game menu | During gameplay; empty themed dialog |

Auto-routing opens the existing itinerary editor. Marker placement opens the
existing naming/side dialog at the player's current road position. Choose Both
there for a two-sided marker. These replace the R and M gameplay shortcuts.
The dispatcher rechecks road-vehicle occupancy and marker placement conditions.
Company and Game Menu now open empty themed modal shells with Close/Escape.
Place remains omitted until there is a working placement action.
Vehicle spawning remains tied to depot selection rather than an arbitrary location.

Create stop captures the player's position on a road or track. A physical stop
within 50 m opens the add-to-station dialog; otherwise it opens the new-station
dialog. See [Station creator](station-creator.md).

Prospect opens a dialog for the player's current position. Select Prospect in
the dialog to take a reading and place a survey sign. Select a sign to reopen its
saved reading. The signs last for the current session, and readings near an
existing sign reuse that sign. Positive readings below 10% display as Trace.
The session's ProspectingManager owns the signs and supports fresh geology
queries at a world X/Z point.

Build opens the Industry, Station and Misc tabs. Select Mine under Industry to
move an opaque green model over the terrain and see nearby survey results.
Press Enter to choose a resource at the selected point, then select Build mine.
The mine produces that resource through the normal industry inventory, with
output scaled by local richness. Escape cancels the current placement attempt.
The session's ConstructionManager checks terrain and uses the collision shape
assigned to Constructable3D to test the proposed footprint.
An industry or station scene with no direct Constructable3D child shows a
configuration warning in the Godot editor.

The action icons in `assets/ui/icons/actions/` use a shared 32 px grid and cream
2 px strokes. Every exposed action has its own icon; entry and exit differ too.

## Owned control

`game/gamescripts/ui/radial_menu/control/` is a game-owned copy of Pascal
Schuppli's MIT-licensed RadialMenu control. Its LICENSE is retained. The editor
addon in `addons/RadialMenu` remains available and unchanged. The owned control
keeps the existing RadialMenu theme namespace and adds dynamic-item geometry
updates, anchored opening/closing, and a short fan/fade animation: 140 ms open,
112 ms close. Set `show_animation` off on the scene's RadialMenu for immediate
opening and closing.

## Checks

```sh
godot --headless --path . --script res://tests/radial_actions_test.gd -- --no-mcp
godot --headless --path . --fixed-fps 60 --script res://tests/road_routing_test.gd -- --no-mcp
```

Checks cover action visibility, one-shot dispatch, unavailable action rejection,
icons, item-count changes, input restoration, release selection, cancellation,
animation completion, centring, and the existing route/marker workflows.
