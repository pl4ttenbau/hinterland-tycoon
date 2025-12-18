class_name RailVehicleData extends GameObject

@export var veh_type: RailVehicleType

@export var direction: VehicleMotor.Direction

@export var last_node: RailNodeData

func _init():
	super(Enums.EntityTypes.VEHICLE)
