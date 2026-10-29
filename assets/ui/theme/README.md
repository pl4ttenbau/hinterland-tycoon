# Hinterland green enamel theme

`hinterland_theme.tres` is the project default under **Project Settings → GUI → Theme → Custom**. Existing and newly created Controls inherit it automatically, including controls created in scripts. Edit this resource in Godot's Theme editor to change the shared appearance.

Flat green enamel panels with corner fasteners, dark bakelite button caps, fine metal collars, recessed instruments, cream nameplates, and amber focus/selection accents suggest a maintained narrow gauge locomotive cab. Scalable SVG textures in `textures/` provide directional lighting, fine surface variation, and raised edges. Panel and rectangular button textures use nine-slice borders; circular caps stretch to the control bounds. Disabled, hovered, pressed, and keyboard focus states have distinct treatments. Standard Godot icons and fonts remain available through theme fallback.

Run `res://scenes/ui/theme_preview.tscn` to inspect controls and interaction states together.

Set **Theme Type Variation** on a Control to use:

- `RoundButton` (Button): circular with equal width and height; use a 64 × 64 minimum size and a short label or icon. Wider content produces a pill.
- `ManagementButton` (Button): compact, shallow controls for menus and lists.
- `PrimaryButton` (Button): management button geometry with a brighter edge for the primary action.
- `DangerButton` (Button): compact oxide red stop/destructive action.
- `ListRowPanel` (PanelContainer): quiet shallow tray for dense lists.
- `InstrumentPanel` (PanelContainer): dark recessed instrument surface.
- `HeadingLabel` (Label): cream 30 px TGL Engschrift heading.
- `HeadlineLabel` (Label): inherits `HeadingLabel` and adds a 2 px rule in cream text colour at 60% opacity, with 8 px of space beneath the text. The rule spans the label width. Drag `res://scenes/ui/components/headline_label.tscn` into a scene, or set this variation on an existing Label.
- `NameplateLabel` (Label): cream 22 px TGL Engschrift lettering on a dark plate.
- `CabStatusLabel` (Label): readable 14 px state text beside indicator lamps.
- `MutedLabel` (Label): secondary lettering.
- `AccentLabel` (Label): amber monetary/status lettering.

Coverage includes buttons, menus, checks/toggles, panels, fields, lists/trees, tabs, sliders, scrollbars, progress bars, separators, tooltips, and container spacing. Controls without explicit entries use Godot's built-in theme fallback. Scene theme overrides and explicitly assigned themes take precedence, including the existing world sign theme.

The game UI uses the project default across menus, HUD, dialogs, inventory, and vehicle lists. List rows use `ListRowPanel`, cab brake/reverse controls use `RoundButton`, and vehicle removal uses `DangerButton`. The custom radial menu reads matching green/amber colours from this theme. World signage retains its physical sign styling.

Material depth follows function: sheet metal has restrained highlights, switch caps have a raised collar, and instruments have an inner lip. The brake/direction cluster couples depressed button faces with labelled amber/green lamps. The traction slider has a grip and a matching plate; check toggles use rocker icons. Recent optical text alignment and dropdown arrow padding remain in place.
