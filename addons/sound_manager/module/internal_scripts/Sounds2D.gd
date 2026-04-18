extends AudioStreamPlayer2D

####################################################################
#SOUNDS SCRIPT FOR THE SOUND MANAGER MODULE FOR GODOT 4
#			© Xecestel
####################################################################
#
# This Source Code Form is subject to the terms of the MIT License.
# If a copy of the license was not distributed with this
# file, You can obtain one at https://mit-license.org/.
#
#####################################

# Variables

#var sound_type : String
var sound_name : String
var sound_direction : int

###########

# Signals

signal finished_playing(sound_name : String, sound_direction : int)

##########


func _ready():
	set_properties();


func connect_signals(connect_to : Node) -> void:
	finished.connect(_on_self_finished)
	finished_playing.connect(connect_to._on_sound_finished)


func set_properties(volume : float = 0.0, pitch : float = 1.0) -> void:
	volume_db = volume
	pitch_scale = pitch
	attenuation = 0.159
	panning_strength = 3


func set_sound_name(sound_name : String) -> void:
	self.sound_name = sound_name


#func set_sound_type(type : String) -> void:
	#self.sound_type = type


#func get_sound_type() -> String:
	#return self.sound_type


func get_sound_name() -> String:
	return sound_name


func _on_self_finished() -> void:
	emit_signal("finished_playing", sound_name, sound_direction)
