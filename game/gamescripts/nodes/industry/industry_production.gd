@icon("res://assets/icons/icon_gears_white.png")
class_name IndustryProduction extends Node

enum BatchResult { COMPLETED, MISSING_INPUTS, STORAGE_FULL, UNAVAILABLE, INVALID_RECIPE, DEPOSIT_EXHAUSTED }

const CAPACITY_EPSILON: float = 0.00001

@export var industry3d: Industry3D

func _ready() -> void:
	if industry3d == null:
		industry3d = get_parent() as Industry3D
	var production_timer := IndustryProductionTimer.new()
	production_timer.timeout.connect(run_cycle)
	add_child(production_timer)

## Resolve stock at the start of each cycle so station links are picked up even
## when the industry entered the scene before the map connected its stops.
func run_cycle() -> BatchResult:
	if not is_instance_valid(industry3d) or industry3d.industry == null:
		return BatchResult.UNAVAILABLE
	var industry: IndustryData = industry3d.industry
	var inventory: GoodsInventory = industry3d.get_inventory()
	if industry.mine_reserves.is_empty():
		return run_batch(industry.ind_type, inventory)
	var manager: ProspectingManager = Managers.prospecting
	if not is_instance_valid(manager):
		return BatchResult.UNAVAILABLE
	return run_batch(industry.ind_type, inventory, industry.mine_reserves, manager.depletion_factor)

## A batch succeeds as a whole. Inputs free space for this batch's outputs, and
## a recipe with only inputs is a consumer that simply removes those goods.
static func run_batch(recipe: IndustryType, inventory: GoodsInventory,
		reserves: Array[MineralReserve] = [], depletion_factor: float = 1.0) -> BatchResult:
	if recipe == null or inventory == null or inventory.storage == null:
		return BatchResult.UNAVAILABLE

	var inputs: Dictionary[StringName, float] = {}
	var outputs: Dictionary[StringName, float] = {}
	if not _collect_amounts(recipe.requires, inputs) or not _collect_amounts(recipe.produces, outputs):
		return BatchResult.INVALID_RECIPE
	if inputs.is_empty() and outputs.is_empty():
		return BatchResult.INVALID_RECIPE

	var available: float = 0.0
	var reserve_cost: float = 0.0
	if not reserves.is_empty():
		if not inputs.is_empty() or outputs.size() != 1 or not is_finite(depletion_factor) or depletion_factor <= 0.0:
			return BatchResult.INVALID_RECIPE
		available = MineralReserve.total(reserves)
		if available <= 0.0:
			return BatchResult.DEPOSIT_EXHAUSTED
		# Let the final batch ship the fraction that remains in the deposit.
		var resource: StringName = outputs.keys()[0]
		reserve_cost = minf(outputs[resource] * depletion_factor, available)
		outputs[resource] = reserve_cost / depletion_factor

	for key: StringName in inputs:
		# Tagged passenger groups belong to trips. Industry recipes use unassigned stock.
		if inventory.stack_amount(key) < inputs[key]:
			return BatchResult.MISSING_INPUTS

	var change_in_used_space: float = _total_amount(outputs) - _total_amount(inputs)
	var final_used_space: float = inventory.storage.current_storage + change_in_used_space
	if not is_finite(final_used_space) or not is_finite(inventory.amount_max):
		return BatchResult.INVALID_RECIPE
	# Previously overfilled inventories can still run batches that drain stock.
	if change_in_used_space > 0.0 and (inventory.amount_max <= 0.0 \
			or final_used_space > inventory.amount_max + CAPACITY_EPSILON):
		return BatchResult.STORAGE_FULL

	var delivered: float = _apply_batch(inventory, inputs, outputs)
	# Commit reserves before notifying inventory listeners. Any following batch
	# sees both the delivered cargo and the updated shared cells.
	if reserve_cost > 0.0:
		MineralReserve.draw_down(reserves, reserve_cost, available)
	var company := CompanyData.current()
	if company != null:
		company.record_delivery(delivered, 0)
	inventory.goods_change.emit()
	return BatchResult.COMPLETED

## Combine repeated lines before checking stock or capacity.
static func _collect_amounts(rows: Array[TransformedGood], amounts: Dictionary[StringName, float]) -> bool:
	for row: TransformedGood in rows:
		if row == null or not is_finite(row.res_modifier) or row.res_modifier <= 0.0:
			return false
		var key := StringName(row.res_key)
		var good: BaseGoodsType = GameTypes.resource_types.get(key)
		if good == null or (good.is_passenger() and row.res_modifier != floorf(row.res_modifier)):
			return false
		var total: float = amounts.get(key, 0.0) + row.res_modifier
		if not is_finite(total):
			return false
		amounts[key] = total
	return true

static func _total_amount(amounts: Dictionary[StringName, float]) -> float:
	var total: float = 0.0
	for amount: float in amounts.values():
		total += amount
	return total

## The preflight validates every key and the full input requirement before any
## mutation. Settle delivered inputs even when the recipe produces the same good.
static func _apply_batch(inventory: GoodsInventory, inputs: Dictionary[StringName, float],
		outputs: Dictionary[StringName, float]) -> float:
	var delivered: float = 0.0
	for key: StringName in inputs:
		delivered += minf(inputs[key], inventory.delivered_cargo.get(key, 0.0))
		inventory.change_stack(key, -1, -inputs[key], false)
	for key: StringName in outputs:
		inventory.change_stack(key, -1, outputs[key], false)
	return delivered
