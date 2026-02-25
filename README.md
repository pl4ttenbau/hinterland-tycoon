# Hinterland Tycoon

A narrow gauge (and a little road) simulator game that stands somewhere in the dusty garage, not being minded by anyone.

Written in the Godot Engine

![Preview June 2025](https://github.com/pl4ttenbau/hinterland-tycoon/blob/main/doc/img/preview_track_and_village.png?raw=true)

![Preview August 2025](https://github.com/pl4ttenbau/hinterland-tycoon/blob/main/doc/img/preview_wernigerode.png?raw=true)

### TODO

#### Maps

* [x] narrower fields
* [ ] "Kopfweide" trees
* [ ] settlements shields
* [ ] no straw bales -> piles instead

#### Editor & Ease Of Use

* [ ] place player marker on map
* [ ] create HinterlandEditor tab in bottom bar

#### Infrastructure

* [ ] make "connect" working
  * [x] mark nearest track node with pin or circle
	* [x] find closest infr node method
  * [ ] extend from said selected node

#### Connectivity

* [ ] refactor vehicle root class so it can accomodate roads vehicles -> AbstractVehicle
  * [ ] make registry for road vehicles too
* [ ] make ways for player to enter and exit vehicle
  * [ ] with click at it
	* [ ] new VehicleClickHandler manager

### Special Thanks 

* Reiner Prokein - reinerstilesets.de
* emzetgie for his excellent polish houses models
* the one and only Pitagoras991 for his Wismar Railbus meshes
* Konrad for his village life enhancements

### Used Addons

* Terrain3D
* PathMesh
* Basic FPS Player
* Loggie
