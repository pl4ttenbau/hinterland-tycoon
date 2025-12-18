class_name RailVehicleData extends GameObject

@export var veh_type: VehicleTypeData

@export var direction: VehicleMotor.Direction

@export var last_node: RailNodeData

func _init():
	super(Enums.EntityTypes.VEHICLE)
