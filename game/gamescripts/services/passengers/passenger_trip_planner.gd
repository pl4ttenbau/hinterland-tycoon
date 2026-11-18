## Population-weighted trip selection. Planning never creates stock, changes
## residence connections or searches for a vehicle route; those are separate jobs.
class_name PassengerTripPlanner extends RefCounted

## A compact weighted-list entry avoids repeating a residence once per inhabitant.
class ResidenceChoice extends RefCounted:
	var residence: ResidenceBuildingData
	var inhabitants: int

	func _init(data: ResidenceBuildingData, population: int) -> void:
		residence = data
		inhabitants = population

var random := RandomNumberGenerator.new()
var _choices: Array[ResidenceChoice] = []
var _total_inhabitants: int = 0

func _init() -> void:
	random.randomize()

## Refresh each spawn attempt: edits, removals and population changes take effect
## immediately. Deliberately keep disconnected houses in the weighted draw.
func refresh(residences: Array[Residence3D]) -> void:
	_choices.clear()
	_total_inhabitants = 0
	for view: Residence3D in residences:
		if not is_instance_valid(view) or not view.is_inside_tree():
			continue
		var data: ResidenceBuildingData = view.res_bld_obj
		var population: int = _population(data)
		if population > 0:
			_choices.append(ResidenceChoice.new(data, population))
			_total_inhabitants += population

func _population(data: ResidenceBuildingData) -> int:
	if data == null or data.res_bld_type == null:
		return 0
	var population: int = 0
	# Both catalog population groups are inhabitants, with equal travel weight.
	for count: int in data.res_bld_type.pops:
		population += maxi(0, count)
	return population

## One ticket per inhabitant. Excluding the origin prevents trips to one's own
## building without retry loops or changing the relative weights of other houses.
func choose_residence(exclude: ResidenceBuildingData = null) -> ResidenceBuildingData:
	var total: int = _total_inhabitants
	for choice: ResidenceChoice in _choices:
		if choice.residence == exclude:
			total -= choice.inhabitants
	if total <= 0:
		return null
	var ticket: int = random.randi_range(0, total - 1)
	for choice: ResidenceChoice in _choices:
		if choice.residence == exclude:
			continue
		if ticket < choice.inhabitants:
			return choice.residence
		ticket -= choice.inhabitants
	return null

## Resolve exactly one origin and one destination. A missing connection discards
## this attempt; picking again until success would silently bias disconnected areas.
func plan() -> PassengerSpawnRequest:
	var origin: ResidenceBuildingData = choose_residence()
	var origin_stop: AbstractStation = _connected_stop(origin)
	if origin_stop == null:
		return null
	var destination: ResidenceBuildingData = choose_residence(origin)
	var destination_stop: AbstractStation = _connected_stop(destination)
	if destination_stop == null or destination_stop.interchange.num == origin_stop.interchange.num:
		return null
	return PassengerSpawnRequest.new(origin, destination, origin_stop, destination_stop.interchange)

## Resolve the closest live physical access point before planning the trip.
func _connected_stop(data: ResidenceBuildingData) -> AbstractStation:
	if data == null:
		return null
	for stop: AbstractStation in data.reachable_stops:
		if stop == null or stop.num < 0 or stop.interchange == null or stop.interchange.num < 0:
			continue
		var view: InventoryEntity3D = stop.get_inventory_view()
		if is_instance_valid(view) and view.is_inside_tree() and view.get_inventory() != null:
			return stop
	return null
