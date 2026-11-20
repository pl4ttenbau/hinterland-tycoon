class_name NewRailBuilder extends Node

const BEDDING_OFFSET := Vector3(0, 0.2, 0)
const Quote = preload("res://game/gamescripts/resources/infr/rail_construction_quote.gd")
const CONFIRM_SCENE := preload("res://scenes/ui/dialogs/build/rail_construction_dialog.tscn")

var _mode: UiModeBuildInfr
var _approach: RailNodeData
var _draft: RailTrackData
var _preview: RailTrack3D
var _confirmation: RailConstructionDialog
var _committing: bool = false


func _on_ui_mode_changed(ui_mode: Enums.UiMode) -> void:
	var next_mode: UiModeBuildInfr = UiState.build_infr_mode if ui_mode == Enums.UiMode.BUILD_INFR else null
	if _mode != next_mode:
		_discard_preview()
		_mode = next_mode


func _on_terrain_click(pos: Vector3) -> void:
	if _mode == null or _mode.at_fork == null or UiState.current_diag != null or not pos.is_finite():
		return
	var bedding_pos: Vector3 = pos + BEDDING_OFFSET
	var start: Vector3 = _mode.at_fork.pos if _draft == null else _draft.get_end_node().position
	if start.is_equal_approx(bedding_pos):
		return
	if _draft == null:
		_approach = _get_approach(_mode.at_fork)
		if _approach == null:
			return
		_start_preview(bedding_pos)
	else:
		_append_point(bedding_pos)


func _start_preview(end: Vector3) -> void:
	var approach_track: RailTrackData = _approach.parent_track
	_draft = RailTrackData.new()
	_draft.start_pos = _mode.at_fork.pos
	_draft.infr_type_key = approach_track.infr_type_key
	_draft.start_tangent = approach_track.get_tangent_into_endpoint(_approach)
	_draft.add_node(RailNodeData.of(0, _draft.start_pos, _draft), false)
	_append_point(end)

	var scene: PackedScene = load(RailTrack3D.get_scene_path(_draft))
	_preview = scene.instantiate()
	_preview.is_construction_preview = true
	_preview.track = _draft
	_preview.name = "RailConstructionPreview"
	BuildPreview.tint_model(_preview)
	add_child(_preview)


func _append_point(pos: Vector3) -> void:
	var node := RailNodeData.of(_draft.nodes.size(), pos, _draft)
	_draft.add_node(node, true)


func _input(event: InputEvent) -> void:
	if _mode == null or UiState.is_world_input_blocked():
		return
	if event.is_action_pressed(&"ui_enter") and _draft != null:
		get_viewport().set_input_as_handled()
		review_plan()
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish_build_mode()


func review_plan() -> void:
	if _draft == null or _confirmation != null or UiState.current_diag != null:
		return
	var cost: int = (_draft.nodes.size() - 1) * CompanyData.TRACK_SEGMENT_COST
	var dialog: RailConstructionDialog = CONFIRM_SCENE.instantiate()
	dialog.quote = Quote.new(_draft.curve.get_baked_length(), _draft.get_gauge_mm(), cost)
	dialog.on_submit = _accept_plan.bind(dialog)
	dialog.closed.connect(_on_confirmation_closed.bind(dialog))
	_confirmation = dialog
	add_child(dialog)


## The review dialog's submit handler. Returns why the track cannot be built,
## or "" after building it, charging the company and closing the dialog.
func _accept_plan(dialog: RailConstructionDialog) -> String:
	if _committing or _confirmation != dialog or _draft == null or _mode == null:
		return "This rail plan is no longer active."
	var fork: RailJunctionData = _mode.at_fork
	var approach: RailNodeData = _get_approach(fork)
	if approach == null or approach != _approach or approach.parent_track.infr_type_key != _draft.infr_type_key:
		return "The rail connection changed. Start a new plan from the junction."

	_committing = true
	var company := CompanyData.current()
	if company != null and not company.spend(dialog.quote.price):
		_committing = false
		return company.spending_error(dialog.quote.price)

	# Transfer the very same smoothed curve from the preview to the registered track.
	var track: RailTrackData = _draft
	_draft = null
	_register_track(track, fork)
	dialog.close_all()
	_finish_build_mode()
	_committing = false
	return ""


func _register_track(track: RailTrackData, fork: RailJunctionData) -> void:
	var rails: RailsLoader = Managers.rails
	track.num = rails.track_storage._max_num + 1
	track.track_name = "New Track %d" % track.num
	var connection := RailJunctionArm.new()
	connection.railNode = track.nodes[0]
	track.nodes[0].fork = connection
	track.add_fork(connection)

	rails.fork_storage.add(connection)
	# The track_added listener attaches the endpoint to the selected fork.
	rails.track_storage.add(track)
	var view: RailTrack3D = rails.spawn_rail_track(track)
	fork.refresh_setting()

	var world: WorldMapScene = Managers.map_spawner.terrain_container
	var bed: PathMesh3D = view.get_bed_mesh()
	if is_instance_valid(world) and bed != null and bed.mesh != null:
		var bounds: AABB = bed.mesh.get_aabb()
		world.clear_rail_vegetation(track.curve, maxf(absf(bounds.position.x), absf(bounds.end.x)))
	Loggie.info("Created connected track: %s" % track.track_name)


func _get_approach(fork: RailJunctionData) -> RailNodeData:
	if fork == null or Managers.forks.get_fork_at_pos(fork.pos) != fork or fork.connected_tracks.is_empty():
		return null
	var approach_num: int = fork.get_static_track_num()
	for connection: RailJunctionArm in fork.node_forks:
		var node: RailNodeData = connection.railNode
		if connection.track.num == approach_num and (node.is_first() or node.is_last()):
			return node
	return null


func _on_confirmation_closed(_result: Variant, dialog: RailConstructionDialog) -> void:
	if _confirmation == dialog:
		_confirmation = null


func _discard_preview() -> void:
	if is_instance_valid(_confirmation):
		_confirmation.close_all()
	if is_instance_valid(_preview):
		_preview.free()
	_preview = null
	# The draft nodes refer back to their track, so release them on cancellation.
	if _draft != null:
		_draft.nodes.clear()
	_draft = null
	_approach = null


func _finish_build_mode() -> void:
	UiState.build_infr_mode = null
	UiState.ui_mode = Enums.UiMode.WALKING
	SignalBus.ui_mode_switched.emit(Enums.UiMode.WALKING)


func _exit_tree() -> void:
	if _draft != null:
		_draft.nodes.clear()
	_draft = null
	if _mode != null and UiState.build_infr_mode == _mode:
		UiState.build_infr_mode = null
		UiState.ui_mode = Enums.UiMode.WALKING
	_mode = null
