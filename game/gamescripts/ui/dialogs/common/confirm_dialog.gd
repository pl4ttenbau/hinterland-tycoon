## A dialog whose OK button submits, in the spirit of an Angular MatDialog with a
## form: OK runs submit(). An error is shown in the status line and keeps the
## dialog open so the player can fix it; "" closes the dialog. To close with a
## result, call close_with(result) inside submit() and return "".
##
## The work can live in two places:
## - a subclass overrides submit() (e.g. the station creator builds the stop);
## - the code that opens the dialog sets on_submit (e.g. MinePlacement builds the
##   chosen mine). It returns an error or "", and may close the dialog itself.
class_name ConfirmDialog extends ModalGameDialog

## Optional handler used by the default submit(). Subclasses may pass it
## arguments, e.g. the choice the player made.
var on_submit: Callable


## OK is wired here, like Cancel in GameDialog, so subclasses keep their own
## _ready(). The guard covers re-entry after a reparent.
func _enter_tree() -> void:
	super()
	if Engine.is_editor_hint():
		return
	var ok := get_node_or_null("%OkButton") as Button
	if ok != null and not ok.pressed.is_connected(confirm):
		ok.pressed.connect(confirm)


## Submits unless the dialog is already closing or OK is disabled. Connect other
## submit gestures here too, e.g. Enter in a text field.
func confirm() -> void:
	if _closing:
		return
	var ok := get_node_or_null("%OkButton") as Button
	if ok != null and ok.disabled:
		return
	var error: String = submit()
	if not error.is_empty():
		show_status(error, StatusTone.ERROR)
		return
	# submit() or its handler may already have closed the dialog with a result.
	if not _closing:
		close_all()


## Override: do the dialog's work and return an error, or "" on success.
func submit() -> String:
	return on_submit.call() if on_submit.is_valid() else ""
