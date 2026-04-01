class_name TrainVehicleListDto extends Resource

signal updated()

@export var rows: Array[TrainVehicleDto] = []

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
