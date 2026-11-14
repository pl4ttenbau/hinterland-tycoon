## Ordered draft shared by the composition dialog and the depot spawn action.
class_name TrainVehicleListDto extends Resource

signal updated()

@export var rows: Array[TrainVehicleDto] = []


func append(train_veh: TrainVehicleDto) -> void:
	train_veh.index = rows.size()
	rows.append(train_veh)
	updated.emit()


func move_up(index: int) -> void:
	_swap(index, index - 1)


func move_down(index: int) -> void:
	_swap(index, index + 1)


func remove(index: int) -> void:
	if index < 0 or index >= rows.size():
		return
	rows.remove_at(index)
	for row_index in range(index, rows.size()):
		rows[row_index].index = row_index
	updated.emit()


func _swap(index: int, neighbor: int) -> void:
	if index < 0 or index >= rows.size() or neighbor < 0 or neighbor >= rows.size():
		return
	var row := rows[index]
	rows[index] = rows[neighbor]
	rows[neighbor] = row
	rows[index].index = index
	row.index = neighbor
	updated.emit()
