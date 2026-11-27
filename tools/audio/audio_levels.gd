extends SceneTree
## Prints the loudness of audio files over time, so cuts and volumes can be set without an audio editor.
##
## Usage (headless, from the project folder):
##   godot --headless --path . --script res://tools/audio/audio_levels.gd -- [res://a.ogg res://b.wav …]
## Without paths it measures the vehicle horns, including the synthesized car horn.
##
## For each file: one line per WINDOW seconds with peak and RMS in dBFS and a small bar, then the overall
## peak/RMS and a suggested cut: from the first window within CUT_RANGE_DB of the loudest window to the
## last one. That is a starting point to check by ear, not a decision.

const WINDOW: float = 0.1
## Windows quieter than this much below the loudest window are "not the horn".
const CUT_RANGE_DB: float = 12.0
const SILENCE_DB: float = -90.0

const DEFAULT_PATHS: Array[String] = [
	"res://assets/sounds/vehicles/horns/wws_p8_steam_whistle.ogg",
	"res://assets/sounds/vehicles/horns/db628_makrofon.ogg",
]

func _initialize() -> void:
	var paths: Array[String] = []
	paths.assign(OS.get_cmdline_user_args())
	var with_car_horn: bool = paths.is_empty()
	if paths.is_empty():
		paths = DEFAULT_PATHS
	for path: String in paths:
		var stream := load(path) as AudioStream
		if stream == null:
			printerr("Cannot load %s" % path)
			continue
		_measure(path, stream)
	if with_car_horn:
		# Loaded here, not referenced as VehicleHorn: a class reference makes Godot compile the horn and
		# its dependencies together with this script, before the autoloads (Loggie, SignalBus, …) exist
		# under --script, which spams "Identifier not found" errors although the run then works.
		var horn_script: GDScript = load("res://game/gamescripts/nodes/vehicle/vehicle_horn.gd")
		_measure("VehicleHorn.car_horn_stream() (synthesized)", horn_script.car_horn_stream())
	quit()

func _measure(label: String, stream: AudioStream) -> void:
	var playback: AudioStreamPlayback = stream.instantiate_playback()
	if playback == null or not playback.has_method("mix_audio"):
		printerr("%s: this Godot version cannot mix audio from a script" % label)
		return
	# Loop flags would make the meter run forever; measure exactly one pass.
	var length: float = stream.get_length()
	var rate: float = AudioServer.get_mix_rate()
	var window_frames: int = maxi(1, int(WINDOW * rate))
	playback.start(0.0)
	var peaks: Array[float] = []
	var rmss: Array[float] = []
	var total_peak: float = 0.0
	var total_square: float = 0.0
	var total_frames: int = 0
	var frames_left: int = int(length * rate)
	while frames_left > 0:
		var count: int = mini(window_frames, frames_left)
		var frames: PackedVector2Array = playback.mix_audio(1.0, count)
		frames_left -= count
		var peak: float = 0.0
		var square: float = 0.0
		for frame: Vector2 in frames:
			var value: float = maxf(absf(frame.x), absf(frame.y))
			peak = maxf(peak, value)
			square += (frame.x * frame.x + frame.y * frame.y) * 0.5
		peaks.append(peak)
		rmss.append(sqrt(square / maxi(frames.size(), 1)))
		total_peak = maxf(total_peak, peak)
		total_square += square
		total_frames += frames.size()
	playback.stop()

	print("\n== %s  (%.2f s, %s)" % [label, length, stream.get_class()])
	print("   time    peak dB   rms dB")
	var loudest: float = SILENCE_DB
	for rms: float in rmss:
		loudest = maxf(loudest, _db(rms))
	var first: int = -1
	var last: int = -1
	for index: int in range(peaks.size()):
		var rms_db: float = _db(rmss[index])
		if rms_db >= loudest - CUT_RANGE_DB:
			if first < 0:
				first = index
			last = index
		var bar: String = "#".repeat(clampi(int((rms_db + 60.0) / 2.0), 0, 30))
		print("  %5.2f  %8.1f %8.1f  %s" % [index * WINDOW, _db(peaks[index]), rms_db, bar])
	print("   overall: peak %.1f dBFS, rms %.1f dBFS" % [_db(total_peak), _db(sqrt(total_square / maxi(total_frames, 1)))])
	if first >= 0:
		print("   suggested cut: start %.2f s, length %.2f s (windows within %.0f dB of the loudest)" \
			% [first * WINDOW, (last - first + 1) * WINDOW, CUT_RANGE_DB])

func _db(value: float) -> float:
	return linear_to_db(value) if value > 0.0 else SILENCE_DB
