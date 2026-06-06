const DOCK_TITLE: String = "Signal Checker"
const ERROR_COLOR: Color = Color(1, 0.45, 0.45)

const SETTING_SCAN_PARAMETER: String = "signal_checker/scan_options/scan_for_function_parameters"
const SETTING_SCAN_PARAMETER_DEFAULT: bool = true

# Toggled by the dock's Debug checkbox.
static var debug: bool = false

static func debug_log(msg: String) -> void:
	if debug:
		print("[SignalChecker] " + msg)

static func read_scan_parameter() -> bool:
	return bool(ProjectSettings.get_setting(SETTING_SCAN_PARAMETER, SETTING_SCAN_PARAMETER_DEFAULT))
