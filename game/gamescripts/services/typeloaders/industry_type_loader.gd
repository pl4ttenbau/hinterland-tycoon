class_name IndustryTypeLoader extends AbstractGameTypeLoader

const RECIPES = preload("res://game/gamescripts/resources/structures/industry/industry_recipe_catalog.gd")

func load_types() -> Error:
	var definitions: Array[IndustryType] = make_types()
	var error: Error = validate_keys(definitions)
	if error != OK:
		return error
	GameTypes.industry_types = definitions
	self.loading_finished.emit()
	return OK
	
func make_types() -> Array[IndustryType]:
	return RECIPES.make_types()
