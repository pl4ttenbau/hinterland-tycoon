extends CanvasLayer

# Contansts

enum DIRECTIONS {FRONT, EAST, WEST}

################

# Variables

@onready var Directions : Array[Node2D] = [$Front, $East, $West]

var Audiostreams : Dictionary = {
	DIRECTIONS.FRONT : [],
	DIRECTIONS.EAST : [],
	DIRECTIONS.WEST : [],
}

var _playing_sounds : Dictionary = {
	DIRECTIONS.FRONT : [],
	DIRECTIONS.EAST : [],
	DIRECTIONS.WEST : [],
}

###################


# Plays the given sound from the given direction
func play(stream : AudioStream, sound_path : String, audio_bus : String, sound : String, direction : String, from_position : float = 1.0, volume : float = -81, pitch : float = -1) -> void:
	var dir = DIRECTIONS[direction.to_upper()]
	var sound_index = -1
	var audiostream : AudioStreamPlayer2D
	
	
	if _playing_sounds[dir].has(sound):
		sound_index = _find_sound(sound, dir)
		audiostream = Audiostreams[dir][sound_index]
		if audiostream.bus != audio_bus:
			audiostream.bus = audio_bus
	else:
		sound_index = _add_sound(sound, sound_path, audio_bus, dir)
		audiostream = Audiostreams[dir][sound_index]
		audiostream.stream = stream
	audiostream.volume_db = volume
	audiostream.pitch_scale = pitch
	
	audiostream.play(from_position)
	
	if audiostream.get_script() != null:
		audiostream.set_sound_name(sound)
	
	if not _playing_sounds[dir].has(sound):
		_playing_sounds[dir].append(sound)


# Stops a sound from a given direction
func stop(sound : String, direction : String) -> void:
	var dir = DIRECTIONS[direction.to_upper()]
	var sound_index = 0
	if sound != "" and sound != null:
		if is_playing(sound, direction):
			sound_index = _find_sound(sound, dir)
			if sound_index >= 0:
				Audiostreams[dir][sound_index].stop()
				_erase_sound(sound, dir)
				_playing_sounds.erase(sound)


# Returns true if the given sound is paused from the given direction
func is_paused(sound : String, direction : String) -> bool:
	var dir = DIRECTIONS[direction.to_upper()]
	var sound_index = _find_sound(sound, dir)
	var paused : bool = false
	if sound_index >= 0:
		paused = Audiostreams[dir][sound_index].get_stream_paused()
	return paused


# Returns true if the selected sound is playing
func is_playing(sound : String, direction : String) -> bool:
	var dir = DIRECTIONS[direction.to_upper()]
	var playing : bool = false
	if sound != "" and sound != null:
		var sound_index = _find_sound(sound, dir)
		playing = sound_index >= 0
		playing = playing && Audiostreams[dir][sound_index].is_playing()
	return playing


func set_paused(sound : String, direction : String, paused : bool) -> void:
	var dir = DIRECTIONS[direction.to_upper()]
	var sound_index = _find_sound(sound, dir)
	if sound_index >= 0:
		Audiostreams[dir][sound_index].set_stream_paused(paused)


# Adds a new sound
func _add_sound(sound : String, sound_path : String, audio_bus : String, direction : DIRECTIONS) -> int:
	var sound_index
	var new_audiostream = AudioStreamPlayer2D.new()
	var sound_script = load(get_script().get_path().get_base_dir() + "/Sounds2D.gd")
	var bus : String
	
	bus = audio_bus
	
	new_audiostream.set_script(sound_script)
	add_child(new_audiostream)
	new_audiostream.connect_signals(self)
	new_audiostream.set_bus(bus)
	new_audiostream.sound_direction = direction
	sound_index = new_audiostream.get_index()
	Audiostreams[direction].append(new_audiostream)
	new_audiostream.global_position = Directions[direction].global_position
	sound_index = Audiostreams[direction].find(sound)

	return sound_index


# Returns the index of the given sound if it's playing
# Returns -1 if it doesn't exist
func find_sound(sound : String, direction : String) -> int:
	var dir = DIRECTIONS[direction]
	return _find_sound(sound, dir)


# Returns the index of the given sound if it's playing
# Returns -1 if it doesn't exist
func _find_sound(sound : String, direction : DIRECTIONS) -> int:
	var sound_index = -1
	if sound != null and sound != "":
		sound_index = _playing_sounds[direction].find(sound)
	return sound_index


# Erases a given playing sound
func _erase_sound(sound : String, direction : DIRECTIONS) -> void:
	var sound_index : int = _find_sound(sound, direction)
	
	if sound_index >= 0:
		Audiostreams[direction][sound_index].queue_free()
		Audiostreams[direction].remove_at(sound_index)
		_playing_sounds[direction].remove_at(sound_index)


func _on_sound_finished(sound_name : String, direction : DIRECTIONS) -> void:
	call_deferred("_erase_sound", sound_name, direction)
