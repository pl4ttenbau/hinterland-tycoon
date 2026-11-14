## The local player's company and its totals for the current game.
class_name CompanyData extends Resource

const STARTING_CASH: float = 1_000_000.0
const STOP_COST: int = 5_000
const TRACK_SEGMENT_COST: int = 500
const PASSENGER_REWARD: int = 100
const CARGO_UNIT_REWARD: int = 250

@export_storage var cash: float = STARTING_CASH
@export_storage var cargo_delivered: float = 0.0
@export_storage var passengers_delivered: int = 0
@export_storage var transport_income: float = 0.0
@export_storage var spending: int = 0


static func current() -> CompanyData:
	var player := GlobalState.player
	return player.company if is_instance_valid(player) else null


static func format_cash(amount: float) -> String:
	var parts: PackedStringArray = String.num(amount, 2).pad_decimals(2).split(".")
	var whole: String = parts[0]
	for index: int in range(whole.length() - 3, 0, -3):
		whole = whole.insert(index, ",")
	return "DM %s.%s" % [whole, parts[1]]


func spending_error(cost: int) -> String:
	if cash < cost:
		return "Insufficient funds. This costs %s." % format_cash(cost)
	return ""


func spend(cost: int) -> bool:
	if cost < 0 or not spending_error(cost).is_empty():
		return false
	cash -= cost
	spending += cost
	emit_changed()
	return true


func record_delivery(cargo: float, passengers: int) -> void:
	if cargo <= 0.0 and passengers <= 0:
		return
	cargo_delivered += cargo
	passengers_delivered += passengers
	var reward: float = cargo * CARGO_UNIT_REWARD + passengers * PASSENGER_REWARD
	cash += reward
	transport_income += reward
	emit_changed()
