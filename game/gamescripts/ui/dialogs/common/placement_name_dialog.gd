## Base for "name it and pick one option" placement forms (road marker, rail
## signal). The placement is captured before opening; subclasses supply the
## default name and do the placing in submit().
class_name PlacementNameDialog extends ConfirmDialog

@onready var _name: LineEdit = %NameEdit
@onready var _choice: OptionButton = %Choice

func _ready() -> void:
	# 1. Wiring: Enter in the name field confirms like the Place (OK) button,
	#    which ConfirmDialog wires itself.
	_name.text_submitted.connect(confirm.unbind(1))
	# 2. Content and focus: a suggested name, selected so typing replaces it.
	_name.text = default_name()
	_name.grab_focus()
	_name.select_all()

## Override: the name suggested when the form opens.
func default_name() -> String:
	return ""
