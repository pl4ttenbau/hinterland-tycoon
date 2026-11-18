class_name IndustryTypeLoader extends AbstractGameTypeLoader

func load_types() -> Error:
	var catalog := IndustryRecipeCatalog.new()
	var error: Error = catalog.read()
	if error == OK:
		error = catalog.validate_goods(GameTypes.resource_types)
	if error != OK:
		push_error(catalog.problem)
		return error

	GameTypes.industry_buildings = catalog.buildings
	GameTypes.industry_types = catalog.industries
	loading_finished.emit()
	return OK
