class_name BuildPreview extends ModalGameDialog

signal site_changed(position: Vector3)

var terrain: Terrain3D
var construction: ConstructionManager
var model: Node3D
var validate_site: Callable
var _anchor: Node3D
var _site_detail: Label


func _ready() -> void:
	dialog_key = "BuildPreview"
	_suspend_world_input()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var footer := VBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -72
	footer.offset_bottom = -12
	_site_detail = _add_footer_label(footer, "")
	_add_footer_label(footer, "Move over terrain · Enter to select site · Esc to cancel")

	# Move the anchor while keeping the model's authored offset and scale.
	_anchor = Node3D.new()
	_anchor.hide()
	add_child(_anchor)
	_tint_model()
	_anchor.add_child(model)


func _process(_delta: float) -> void:
	if not is_instance_valid(terrain) or not is_instance_valid(construction):
		close_all()
		return
	_update_preview(get_viewport().get_mouse_position())


func _update_preview(cursor: Vector2) -> void:
	var hit: Vector3 = construction.terrain_hit(terrain, get_viewport().get_camera_3d(), cursor)
	if not hit.is_finite():
		_anchor.hide()
		_site_detail.hide()
		return
	var moved: bool = not _anchor.visible or not _anchor.global_position.is_equal_approx(hit)
	_anchor.global_position = hit
	_anchor.show()
	_site_detail.show()
	if moved:
		site_changed.emit(hit)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_enter"):
		get_viewport().set_input_as_handled()
		if not _anchor.visible or _closing:
			return
		var site: Vector3 = _anchor.global_position
		var problem: String = validate_site.call(site) if validate_site.is_valid() else ""
		if not problem.is_empty():
			set_site_detail(problem)
			return
		diag_result = site
		close_all()
	else:
		super._input(event)


func set_site_detail(message: String) -> void:
	_site_detail.text = message


func _add_footer_label(footer: VBoxContainer, caption: String) -> Label:
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(label)
	return label


func _tint_model() -> void:
	# Apply the tint to the preview instances. Other users of the model keep their materials.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#39c962")
	var geometry: Array[Node] = model.find_children("*", "GeometryInstance3D", true, false)
	if model is GeometryInstance3D:
		geometry.append(model)
	for part: GeometryInstance3D in geometry:
		part.material_override = material
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
