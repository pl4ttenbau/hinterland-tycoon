## Outcome of one route action. Successful zero moves mean no matching stock or
## no free space; an error means the route must stop for the player to resolve it.
class_name RoadRouteTransferResult extends RefCounted

var moved: float = 0
var completed_passengers: float = 0
var error: String = ""
