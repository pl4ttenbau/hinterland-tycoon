# Create a dialog from the default scene

1. In Godot's FileSystem dock, right-click [default_dialog.tscn](../scenes/ui/dialogs/default_dialog.tscn) and choose **New Inherited Scene**. Rename the root and save the scene under `scenes/ui/dialogs/`.
2. Set the root's **Dialog Key** to a name unique to your dialog. Set **Title Text** for the in-game heading and edit the inherited **Headline** label to preview that title in the editor.
3. Add your controls under **Content**. It stacks its children vertically. Set **Panel → Layout → Custom Minimum Size → X** if you need a wider panel. The panel centers itself and grows with the visible content.
4. **CancelButton** already closes the dialog, and Escape uses the same close behavior. Change the button's **Text** to *Cancel* for a form. For a confirmation action, make **OkButton** visible, set **Success Btn Text** and the button's preview text, and connect its `pressed` signal. Put any additional actions under **Buttons**. For validation feedback, set the text of **Status** and show it.

## Confirmation and results

Replace the script on the inherited root with one that extends `GameDialog`, or use `ModalGameDialog` to suspend player controls and show the cursor while the dialog is open. A confirm handler can set `diag_result` and call `close_all()` once it has validated the input.

```gdscript
extends ModalGameDialog

func _on_ok_button_pressed() -> void:
	diag_result = true
	close_all()
```

Instantiate the scene from your action handler, connect its `closed(result)` signal if you need the result, and add it to the game tree. The default result when the player cancels is `null`.

See [RoadRouteDialog](../scenes/ui/dialogs/road_route/road_route_dialog.tscn) for a working example with tabs and extra footer buttons. For tabbed dialogs with wrapping text, leave **Use Hidden Tabs for Min Size** off so the active tab determines the panel height.
