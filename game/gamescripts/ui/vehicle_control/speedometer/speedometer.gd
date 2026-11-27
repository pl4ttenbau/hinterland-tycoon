## Needle speedometer for the train the player is driving, on a fixed km/h scale.
##
## The scale is static on purpose: a full needle always means MAX_SPEED_KMH, whatever the consist can do,
## so readings compare between trains (the old version showed a fraction of each consist's top speed).
## The dial face is a Soviet brake manometer reading 0–12; read ×10 it is a 0–120 km/h scale.
##
## Self-contained scene (scenes/ui/ingame/vehicle_control/speedometer.tscn): it shows and hides itself as the
## player enters and leaves trains and reads the physical speed every frame. Polling instead of a signal,
## because the speed changes on almost every physics tick while moving anyway.
class_name SpeedometerControl extends Control

## Speed at full needle deflection: the "12" mark on the dial.
const MAX_SPEED_KMH: float = 120.0

## Needle angles in degrees at 0 and at MAX_SPEED_KMH, matching the dial's printed arc.
## Exported so the needle can be lined up with the artwork in the editor.
@export_range(-180.0, 180.0) var zero_angle_degrees: float = -35.0
@export_range(-180.0, 180.0) var max_angle_degrees: float = 35.0

## Train the player is driving; null while on foot.
var train: Train3D

@onready var _needle: Line2D = %SpeedLine

func _ready() -> void:
	SignalBus.player_entered_train.connect(self._on_train_entered)
	SignalBus.player_exited_train.connect(self._on_train_exited)
	self._show_speed_kmh(0.0)

func _process(_delta: float) -> void:
	if not is_instance_valid(self.train) or not is_instance_valid(self.train.movement):
		return
	self._show_speed_kmh(RailPhysics.mps_to_kmh(absf(self.train.movement.speed_mps)))

## Turn the needle for the given speed. Speeds beyond the scale pin the needle at the end stop,
## like a real instrument, instead of wrapping around.
func _show_speed_kmh(speed_kmh: float) -> void:
	var fraction: float = clampf(speed_kmh / MAX_SPEED_KMH, 0.0, 1.0)
	self._needle.rotation_degrees = lerpf(self.zero_angle_degrees, self.max_angle_degrees, fraction)
	## Exact reading on hover, since the dial has only every 20 km/h printed.
	self.tooltip_text = "%d km/h" % roundi(speed_kmh)

func _on_train_entered(entered: Train3D) -> void:
	self.train = entered

func _on_train_exited() -> void:
	self.train = null
	self._show_speed_kmh(0.0)
