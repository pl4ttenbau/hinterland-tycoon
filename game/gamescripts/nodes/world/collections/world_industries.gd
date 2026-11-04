@tool
@icon("res://assets/icons/icon_industry_white.png")
class_name WorldIndustries extends Node

const RECIPE_CATALOG = preload("res://game/gamescripts/resources/structures/industry/industry_recipe_catalog.gd")

@export var world_scene: WorldMapScene

@export_tool_button("Check Industry Supply")
var check_industry_supply: Callable = refresh_supply_warnings

var _supply_refresh_pending: bool = false

#region Editor refresh
func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		return
	if not child_order_changed.is_connected(refresh_supply_warnings):
		child_order_changed.connect(refresh_supply_warnings)
	refresh_supply_warnings()

## Coalesce scene loading and Inspector changes into one refresh after the tree
## has settled. The same entry point serves the button, child edits and undo/redo.
func refresh_supply_warnings() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree() or _supply_refresh_pending:
		return
	_supply_refresh_pending = true
	_refresh_supply_warnings_deferred.call_deferred()

func _refresh_supply_warnings_deferred() -> void:
	_supply_refresh_pending = false
	if is_inside_tree():
		update_configuration_warnings()
#endregion

#region Supply inspection
## Only goods consumed by placed industries need producers. Catalog entries that
## are not used on this map do not create requirements of their own.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	var catalog: Array[IndustryType] = RECIPE_CATALOG.make_types()
	var placed_industries: Dictionary[IndustryPlaceholder, IndustryType] = _collect_placed_industries(catalog, warnings)
	var produced_goods: Dictionary[String, bool] = _collect_produced_goods(placed_industries)
	var consumers_by_good: Dictionary[String, PackedStringArray] = _collect_consumers_by_good(placed_industries)

	# Stable ordering keeps warnings easy to compare while editing the map.
	var required_goods: Array[String] = consumers_by_good.keys()
	required_goods.sort()
	for good_key: String in required_goods:
		if not produced_goods.has(good_key):
			warnings.append(_format_missing_producer_warning(good_key, consumers_by_good[good_key], catalog))
	return warnings

## Match IndustrySpawner: only direct placeholder children become industries.
## Invalid keys are reported separately so a typo cannot silently hide demand.
func _collect_placed_industries(catalog: Array[IndustryType], warnings: PackedStringArray) -> Dictionary[IndustryPlaceholder, IndustryType]:
	var types_by_key: Dictionary[String, IndustryType] = {}
	for definition: IndustryType in catalog:
		types_by_key[definition.key] = definition

	var placed_industries: Dictionary[IndustryPlaceholder, IndustryType] = {}
	for child: Node in get_children():
		if not child is IndustryPlaceholder:
			continue
		var industry: IndustryPlaceholder = child
		var definition: IndustryType = types_by_key.get(industry.type_key)
		if definition == null:
			warnings.append('Industry "%s" has unknown type "%s".' % [_industry_label(industry), industry.type_key])
			continue
		placed_industries[industry] = definition
	return placed_industries

## This checks existence, not whether a producer can currently operate or deliver.
## Its own missing inputs will be checked as separate consumption requirements.
func _collect_produced_goods(placed_industries: Dictionary[IndustryPlaceholder, IndustryType]) -> Dictionary[String, bool]:
	var produced_goods: Dictionary[String, bool] = {}
	for definition: IndustryType in placed_industries.values():
		for output: TransformedGood in definition.produces:
			if output.res_modifier > 0:
				produced_goods[output.res_key] = true
	return produced_goods

## Group demand by good so several consumers share one warning listing their names.
func _collect_consumers_by_good(placed_industries: Dictionary[IndustryPlaceholder, IndustryType]) -> Dictionary[String, PackedStringArray]:
	var consumers_by_good: Dictionary[String, PackedStringArray] = {}
	for industry: IndustryPlaceholder in placed_industries:
		var definition: IndustryType = placed_industries[industry]
		var label: String = _industry_label(industry)
		for input: TransformedGood in definition.requires:
			if input.res_modifier <= 0:
				continue
			var names: PackedStringArray = consumers_by_good.get(input.res_key, PackedStringArray())
			if not names.has(label):
				names.append(label)
			consumers_by_good[input.res_key] = names
	return consumers_by_good

## Any one matching recipe is enough; alternative producers are suggestions,
## not additional requirements for the map.
func _find_producer_choices(good_key: String, catalog: Array[IndustryType]) -> PackedStringArray:
	var choices: PackedStringArray = []
	for definition: IndustryType in catalog:
		for output: TransformedGood in definition.produces:
			if output.res_key == good_key and output.res_modifier > 0:
				choices.append("%s (%s)" % [definition.name, definition.key])
				break
	choices.sort()
	return choices

func _format_missing_producer_warning(good_key: String, consumer_names: PackedStringArray, catalog: Array[IndustryType]) -> String:
	consumer_names.sort()
	var choices: PackedStringArray = _find_producer_choices(good_key, catalog)
	var suggestion: String = "No industry recipe produces this good."
	if not choices.is_empty():
		suggestion = "Add at least one of: %s." % ", ".join(choices)
	return "Missing producer for %s. Required by: %s. %s" % [good_key, ", ".join(consumer_names), suggestion]

func _industry_label(industry: IndustryPlaceholder) -> String:
	return industry.ind_name if not industry.ind_name.is_empty() else str(industry.name)
#endregion
