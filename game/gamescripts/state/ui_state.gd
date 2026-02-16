@icon("uid://r84qkk5fcxhq")
extends Node

# == MAIN MENU ==
@export var in_main_menu: bool = true

@export var main_menu_root: StartmenuRoot = null

@export var main_menu_scene: StartmenuSubscene

# == IN GAME ==
@export var movement_blocked: bool = false

@export var current_diag: GameDialog

@export var building_mode_on: bool = false
