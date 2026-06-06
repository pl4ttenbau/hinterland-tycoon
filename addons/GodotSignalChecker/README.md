# Godot Signal Checker

Checks scenes for broken signals / events connected via the the Godot signal tab.  

## Features

* Scans your scenes for missing signals
* Supports GDscript and C#
* Disable parameter scans
* Purely written in GDscript for maximal compatibility


## The Problem

Godot complains about broken signals connected from code, but **editor-connected signals fail silently**, when you rename or delete the receiver method.  
You usually find out the hard way, a button click that does nothing, or worse, a bug report from a player.

This should be a temporary solution until the GitHub issue [godot-proposals#8982](https://github.com/godotengine/godot-proposals/issues/8982) solves the problem in-engine.


## Setup

Either use the Godot assed library to install it or manually copy the `addons/GodotSignalChecker` into your addons folder and enable it in `Project` -> `Project Settings` -> `Plugins`.


## Use

When opening the project or enabling the plugin an initial scan will be performed.  
Other than that there is currently no auto-reload system, switch to the "Signal Checker" tab at the bottom and press the `Scan` button.


## OTHER

For more information see the GitHub page: [https://github.com/SpielmannSpiel/GodotSignalChecker](https://store.godotengine.org/asset/spielmannspiel/godot-signal-checker/)

Godot Asset Library (new): [https://store.godotengine.org/asset/spielmannspiel/godot-signal-checker/](https://store.godotengine.org/asset/spielmannspiel/godot-signal-checker/)  
Godot Asset Library (old): [https://godotengine.org/asset-library/asset/5122](https://store.godotengine.org/asset/spielmannspiel/godot-signal-checker/)  
by bison - SpielmannSpiel [https://spielmannspiel.com](https://store.godotengine.org/asset/spielmannspiel/godot-signal-checker/)  
