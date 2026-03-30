class_name TrainVehicleList extends Resource

signal updated()

@export var rows: Array[TrainVehicleDto] = []

@export var depot_num = 1

func append(train_veh: TrainVehicleDto):
	self.rows.append(train_veh)
	self.updated.emit()

func move_up(index: int):
	pass
	self.updated.emit()
	
func move_down(index: int):
	pass
	self.updated.emit()
	
func remove(index: int):
	self.updated.emit()
