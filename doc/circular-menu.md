# Circular action menu

Right-click opens the menu. Hold and release over a segment to choose it, or
release quickly and click a segment. Escape cancels, including during opening.
The game pauses walking/driving input while the menu owns it, then restores the
gameplay mouse and movement settings before launching an action or dialog.

| Action | Availability |
| --- | --- |
| Enter train / Leave vehicle | A train is available / player occupies a vehicle |
| Auto-routing | Player occupies a road vehicle |
| Remove rail signal | On foot, next to a rail signal |
| Coupling | Player occupies a train that can couple or split |
| Prospect | During gameplay. Step out of the vehicle to take a reading. |
| Build | During gameplay; opens the Build picker |
| Inventory | During gameplay |
| Company information | During gameplay; empty themed dialog |
| Game menu | During gameplay; empty themed dialog |

Auto-routing opens the existing itinerary editor; it replaces the R shortcut.
The dispatcher rechecks road-vehicle occupancy when the action runs.
Company and Game Menu open themed dialogs that close with Close or Escape.
Vehicle spawning remains tied to depot selection rather than an arbitrary location.

Everything that places something on the map lives in the Build picker, not in
this menu. Build is the one placement action here.

Create stop (Build, Station tab) captures the player's position on a road or
track. A physical stop within 50 m opens the add-to-station dialog; otherwise it opens the new-station
dialog. See [Station creator](station-creator.md).

Prospect opens a dialog for the player's current position. Select Prospect in
the dialog to take a reading and place a survey sign. Select a sign to reopen its
saved reading. The signs last for the current session, and readings near an
existing sign reuse that sign. Positive readings below 10% display as Trace.
The session's ProspectingManager owns the signs and supports fresh geology
queries at a world X/Z point.

Build opens a picker with Industry, Station, Rail and Road tabs, and a preview
panel for the hovered option (an empty square until preview images exist).
Station holds Create stop, Rail holds Connect tracks and Place rail signal, Road
holds Place road marker (a two-sided marker: choose Both in its dialog). Tools
that cannot be used where the player stands are hidden, and a tab with nothing
usable shows "Nothing to build here." Select Mine under Industry to
move an opaque green model over the terrain and see nearby survey results.
Press Enter to choose a resource at the selected point, then select Build mine.
The mine produces that resource through the normal industry inventory, with
output scaled by local richness. Escape cancels the current placement attempt.
The session's ConstructionManager checks terrain and uses the collision shape
assigned to `Constructable` to test the proposed footprint.
An industry or station scene with no direct `Constructable` child shows a
configuration warning in the Godot editor.

The action icons in `assets/ui/icons/actions/` use a shared 32 px grid and cream
2 px strokes. Every exposed action has its own icon; entry and exit differ too.

## Code paths

- `RadialActionMenu` builds the visible action list each time the menu opens.
  The radial control handles drawing, hover, and selection. On selection, the
  wrapper releases its input block and defers `action_requested` until the
  current input event has finished.
- `GameSession` connects that signal to `ActionHandler`. The handler checks
  the current context again and dispatches to an action node or the feature
  that opens the dialog.
- `GameDialog` registers on tree entry and emits its result once when closing.
  The top dialog receives Escape. `ModalGameDialog` holds the input block until
  tree exit, including when a scene is unloaded. Dialogs inherit
  `scenes/ui/dialogs/default_dialog.tscn`: a headline, a `%Content` slot, a
  `%Status` line (`show_status()` with a hint, error, success or accent tone)
  and a button row. `%OkButton` is the optional primary action; `%CancelButton`
  closes without a result and is wired by `GameDialog` itself.
  `close_with(result)` closes with a result. A `ConfirmDialog` wires OK to
  `submit()`, either overridden or handed in as `on_submit` by the code that
  opens it: an error stays in the status line, "" closes. To open the next
  stage of a flow such as mine placement, take the result from `closed` and
  wait for `tree_exited` before adding the next dialog.

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
