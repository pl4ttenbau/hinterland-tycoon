extends Node

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
	ROAD,
	DEPOT,
	NODE_STATION,
	STATION,
	TOWN,
	RESIDENCIAL,
	INDUSTRY,
	FORK,
	GOOD,
	DECO_STATIC,
	DECO_SPLINE,
	INTERCHANGE # Append new entity kinds to preserve existing serialized enum values.
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

enum UiMode {
	WALKING,
	BUILD_INFR,
	BUILD_STRUCTURE,
	DRIVING
}
