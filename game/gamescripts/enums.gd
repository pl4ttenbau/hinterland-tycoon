## Shared game and editor enums; the Enums autoload exposes these definitions.
class_name GameEnums extends Node

enum Location {
	NORTHERN_GERMANY,
	SOUTHERN_GERMANY,
	POLAND,
	SOVIET_UNION
}

enum EntityTypes {
	PLAYER,
	VEHICLE,
	TRAIN,
	RAIL,
	RAIL_DEPOT,
	ROAD,
	ROAD_DEPOT,
	NODE_STATION,
	STATION,
	TOWN,
	RESIDENCIAL,
	INDUSTRY,
	FORK,
	GOOD,
	DECO_STATIC,
	DECO_SPLINE,
	INTERCHANGE,
	MARKER # Append new entity kinds to preserve existing serialized enum values.
}

enum InfrDomain {
	RAIL,
	ROAD,
	WATER,
	AIR,
	STATIONARY
}

enum EnumStartOrEnd {
	START = 0,
	END = 1
}

enum TownSize {
	POI,
	SETTLEMENT,
	VILLAGE,
	VILAGE_TOWN,
	TOWN,
	CITY
}

enum PathDirection {
	TRACK_NODES_INCREASE, 
	TRACK_NODES_DECREASE,
	STOP
}

## Physical side when facing along increasing road node indices.
enum RoadSide {
	LEFT,
	RIGHT,
	BOTH
}

## Directions of travel served by a road stop.
enum RoadStopDirection {
	ROAD_NODES_INCREASE,
	ROAD_NODES_DECREASE,
	BOTH_DIRECTIONS
}

enum UiMode {
	WALKING,
	BUILD_INFR,
	BUILD_STRUCTURE,
	DRIVING
}

## IDs for the editor toolbar's enum-keyed Button lookup.
## Tool behavior stays in the plugin until tools become individual classes.
enum EnumEditorTool { NONE, BUILD_TOWN, CREATE_ROAD, CREATE_RAIL, SELECT_OBJECT, CREATE_INTERCHANGE, ADD_STOP }
