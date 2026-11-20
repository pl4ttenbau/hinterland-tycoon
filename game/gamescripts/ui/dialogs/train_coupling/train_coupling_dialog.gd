## The only gameplay interface for coupling or splitting a consist.
## Coordinates the consist list, both neighbor panels and the confirm bar;
## TrainCoupling does the planning and the actual join or split.
##
## Nothing changes the trains until the player confirms. Pressing Couple or
## Uncouple only starts a preview, and at most one preview exists at a time:
## - a join: _pending_join is the connection to the train in range;
## - a split: _ahead and _behind are the two vehicles either side of the cut.
## The confirm bar shows while a preview exists. Every refresh re-checks the
## preview, because the trains can move or change while the dialog is open.
class_name TrainCouplingDialog extends ModalGameDialog

const SCENE_PATH := "res://scenes/ui/dialogs/train_coupling/train_coupling_dialog.tscn"

## The vehicle picked in the consist list. Split buttons work relative to it, and
## its train is the one being coupled or split.
var _selected: Vehicle3D
## Confirm bar text for the current preview, before any problem is appended.
var _preview_summary: String
## Join preview: the connection the player chose. null when not joining.
var _pending_join: TrainCoupling.Connection
## Split preview: the last vehicle of the front part and the first of the rear
## part. Both null when not splitting.
var _ahead: Vehicle3D
var _behind: Vehicle3D

@onready var _train_status: Label = %TrainStatus
@onready var _consist: CouplingConsistList = %Consist
@onready var _front: CouplingNeighborPanel = %FrontPanel
@onready var _rear: CouplingNeighborPanel = %RearPanel
@onready var _split_above: Button = %SplitAboveButton
@onready var _split_below: Button = %SplitBelowButton
@onready var _confirm_bar: CouplingConfirmBar = %ConfirmBar

static func create(vehicle: Vehicle3D) -> TrainCouplingDialog:
	var dialog := (load(SCENE_PATH) as PackedScene).instantiate() as TrainCouplingDialog
	dialog._selected = vehicle
	return dialog

func _ready() -> void:
	# 1. Wiring: panels request previews, the confirm bar commits or cancels them.
	_connect_signals()
	# 2. Content: the selected consist and whatever is in range at both ends.
	_refresh()
	# 3. Focus.
	_consist.focus_list()

func _connect_signals() -> void:
	_consist.vehicle_selected.connect(_on_vehicle_selected)
	_front.couple_requested.connect(_preview_join)
	_rear.couple_requested.connect(_preview_join)
	_split_above.pressed.connect(_preview_split.bind(true))
	_split_below.pressed.connect(_preview_split.bind(false))
	_confirm_bar.confirmed.connect(_commit)
	_confirm_bar.cancelled.connect(_cancel_preview)
	# Nearby trains move, so the panels refresh on a timer.
	%RefreshTimer.timeout.connect(_refresh)

## Redraws everything from the live trains: consist, both neighbours, split
## buttons and the preview. Also driven by the scene's RefreshTimer, since
## nearby trains move. Closes the dialog once coupling is no longer possible,
## e.g. the train left or the selected vehicle was removed.
func _refresh() -> void:
	if _closing:
		return
	if not is_instance_valid(_selected) or not TrainCoupling.available(_selected.train3d):
		close_all()
		return
	var train: Train3D = _selected.train3d
	var parked: bool = train.movement.is_parked()
	_train_status.text = "Train %d  ·  %s" % [train.num, "Stopped" if parked else "Bring the train to a stop"]
	# Draw the split marker before _behind while a split of this train is previewed.
	var cut: int = _behind.num_in_train if is_instance_valid(_behind) and _behind.train3d == train else -1
	_consist.show_consist(train, _selected, cut)
	_front.show_plan(TrainCoupling.plan_join(train, true))
	_rear.show_plan(TrainCoupling.plan_join(train, false))
	# Splitting needs a stopped train and a vehicle on the chosen side.
	var selected_index: int = _selected.num_in_train
	_split_above.disabled = selected_index == 0 or not parked
	_split_below.disabled = selected_index == train.count() - 1 or not parked
	_confirm_bar.visible = _pending_join != null or is_instance_valid(_ahead)
	if _confirm_bar.visible:
		_confirm_bar.show_preview(_preview_summary, _preview_problem(train))

## Why the current preview cannot be confirmed right now, or "". A join is
## re-planned against the live trains and refreshes its summary while it fits.
func _preview_problem(train: Train3D) -> String:
	if _pending_join == null:
		return TrainCoupling.split_error(train, _ahead, _behind)
	var plan: TrainCoupling.JoinPlan = TrainCoupling.plan_join(train, _pending_join.at_front, _pending_join)
	if plan.error.is_empty():
		_preview_summary = _join_summary(plan)
	return plan.error

## Another vehicle selected: any preview was relative to the old one, so drop it.
func _on_vehicle_selected(vehicle: Vehicle3D) -> void:
	_selected = vehicle
	_cancel_preview()

## Ends any preview without touching the trains.
func _cancel_preview() -> void:
	_pending_join = null
	_ahead = null
	_behind = null
	clear_status()
	_refresh()

## Previews splitting directly above (in front of) or below (behind) the
## selected vehicle. cut is the index of the first vehicle of the rear part.
func _preview_split(above: bool) -> void:
	var train: Train3D = _selected.train3d
	var cut: int = _selected.num_in_train + (0 if above else 1)
	if cut <= 0 or cut >= train.count():
		return
	_pending_join = null
	_ahead = train.vehicles[cut - 1]
	_behind = train.vehicles[cut]
	_preview_summary = "%s\n%s + %s" % [TrainCouplingText.pair(_ahead, _behind),
		TrainCouplingText.count(cut), TrainCouplingText.count(train.count() - cut)]
	_confirm_bar.set_action("Confirm split")
	clear_status()
	_refresh()

## Previews joining the train in range at the front or the rear. A plan that
## does not fit is not previewed; the neighbour panel already explains why.
func _preview_join(at_front: bool) -> void:
	var train: Train3D = _selected.train3d
	var panel: CouplingNeighborPanel = _front if at_front else _rear
	if panel.connection == null:
		return
	var plan: TrainCoupling.JoinPlan = TrainCoupling.plan_join(train, at_front, panel.connection)
	if not plan.error.is_empty():
		_refresh()
		return
	_pending_join = plan.connection
	_ahead = null
	_behind = null
	_preview_summary = _join_summary(plan)
	_confirm_bar.set_action("Confirm coupling")
	clear_status()
	_refresh()

func _join_summary(plan: TrainCoupling.JoinPlan) -> String:
	var connection: TrainCoupling.Connection = plan.connection
	return "%s · %s\nOne consist · %s" % ["Front" if connection.at_front else "Rear",
		TrainCouplingText.pair(connection.own_end, connection.facing_end), TrainCouplingText.count(plan.ordered.size())]

## Applies the preview. TrainCoupling re-checks it and reports a problem if
## the situation changed since the last refresh.
func _commit() -> void:
	if _closing or not is_instance_valid(_selected):
		return
	var train: Train3D = _selected.train3d
	var problem: String = TrainCoupling.join(train, _pending_join) if _pending_join != null \
		else TrainCoupling.split(train, _ahead, _behind)
	_cancel_preview()
	if not problem.is_empty():
		show_status(problem, StatusTone.ERROR)
