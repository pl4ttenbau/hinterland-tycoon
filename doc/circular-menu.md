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
| Connect tracks | On foot, with rail services loaded |
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
