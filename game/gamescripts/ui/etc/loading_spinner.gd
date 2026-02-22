class_name LoadingSpinner extends CenterContainer

signal shown()

@export var spinner_image: TextureRect:
	get(): return %LoadingSpinnerImage

func _ready() -> void:
	Loggie.info("LoadingSpinner shown")
	self._emit_signal()

func _process(delta: float) -> void:
	if self.spinner_image && self.visible:
		self.spinner_image.rotation += self._get_rotation_factor(delta)

#region Helper-Methods
func _emit_signal():
	self.shown.emit()

func _get_rotation_factor(delta: float) -> float:
	return delta *2
#endregion
