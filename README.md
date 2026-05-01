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
* [ ] Export from InfrRailLine3D back to JSON-Track or -road

#### Infrastructure

* [x] make "connect" working
  * [x] mark nearest track node with pin or circle
	* [x] find closest infr node method
  * [x] extend from said selected node
  * extend from demo status

#### Connectivity

* [ ] refactor vehicle root class so it can accomodate roads vehicles -> AbstractVehicle
  * [ ] make registry for road vehicles too
* [x] make ways for player to enter and exit vehicle
  * [x] with click at it
	* [ ] new VehicleClickHandler manager
* [x] allow inventory spawnning between train & station
  *  [ ] duck typing for inventory-havers?
  * [ ] train-wide goods capacity
  * [x] signal when train enters & leaves station
	* [ ] auto-spawning timer in train?
* [ ] PossibleIndustryConnection class for where you could deliver between
* [ ] think of a new inventory for rails or any targeted goods

#### New Maps

* [x] Sachalin 50ies
* [ ] Gdanksk 70ies

### Special Thanks 

* the one and only [Pitagoras991](https://steamcommunity.com/profiles/76561198141027079/myworkshopfiles/) for:
	* Wismar Railbus Asset
	* Umbauwagen Asset
	* Laenderwagen Asset
	* UV mapping and mental support :P
* Reiner Prokein - reinerstilesets.de
* [emzetgie](https://steamcommunity.com/profiles/76561198965772146/myworkshopfiles/?appid=784150) for his excellent polish houses models
* Konrad for his village life enhancements

### Used Addons

* Terrain3D
* PathMesh
* Basic FPS Player
* Loggie
