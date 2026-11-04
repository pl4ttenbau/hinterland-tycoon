@tool
## Camera projection and ray values shared while testing one viewport selection click.
class_name EditorPickQuery extends RefCounted

var camera: Camera3D
var mouse: Vector2
var inverse: Transform3D
var origin: Vector3
var direction: Vector3
var max_depth: float = INF

static func from_camera(view: Camera3D, screen_position: Vector2, depth_limit: float = INF) -> EditorPickQuery:
	var query := EditorPickQuery.new()
	query.camera = view
	query.mouse = screen_position
	query.inverse = view.global_transform.affine_inverse()
	query.origin = view.project_ray_origin(screen_position)
	query.direction = view.project_ray_normal(screen_position)
	query.max_depth = depth_limit
	return query
