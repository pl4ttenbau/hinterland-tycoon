## The scene shares the road stops' mouse-only collision layer.
class_name SurveyMarker3D extends ClickableCollider

var marker_num: int
var readings: Dictionary[String, float]


func get_click_ref() -> ClickRef:
	return ClickRef.new(Enums.EntityTypes.MARKER, marker_num)
