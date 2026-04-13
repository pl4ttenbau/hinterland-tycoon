class_name IndustryProductionTimer extends Timer

const PRODUCTION_TIMER_SECONDS = 5.0

func _init() -> void:
	self.wait_time = PRODUCTION_TIMER_SECONDS
	self.one_shot = false

func _ready() -> void:
	self.start(PRODUCTION_TIMER_SECONDS)
