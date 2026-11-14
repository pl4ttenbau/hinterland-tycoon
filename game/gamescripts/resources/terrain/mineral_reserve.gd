## Remaining units of one resource in one deposit cell.
class_name MineralReserve extends Resource

@export_storage var remaining: float


static func total(cells: Array[MineralReserve]) -> float:
	var amount: float = 0.0
	for cell: MineralReserve in cells:
		amount += cell.remaining
	return amount


## Draw the same fraction from every cell so the whole mining area depletes.
static func draw_down(cells: Array[MineralReserve], amount: float, available: float) -> void:
	var remaining_fraction: float = maxf(0.0, 1.0 - amount / available)
	for cell: MineralReserve in cells:
		cell.remaining *= remaining_fraction
