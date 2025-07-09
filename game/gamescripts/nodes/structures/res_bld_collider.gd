class_name ResBldCollider extends ClickableCollider

func get_click_ref() -> ClickRef:
	return ClickRef.new(Enums.EntityTypes.RESIDENCIAL, -1)
