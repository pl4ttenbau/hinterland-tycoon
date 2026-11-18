## A sparse runtime coverage mask in world X/Z, using the vegetation emitter grid.
@tool
extends RefCounted

const CELL_SIZE: float = 16.0
const PIXELS: int = 32
const METRES_PER_PIXEL: float = CELL_SIZE / PIXELS

var _cells: Dictionary[Vector2i, Image] = {}


func get_cell(cell: Vector2i) -> Image:
	return _cells.get(cell)


func clear_along(points: PackedVector3Array, half_width: float, settings: GrassAreaDefinition,
		height_at: Callable) -> Array[Vector2i]:
	var changed: Dictionary[Vector2i, bool] = {}
	var radius: float = half_width + settings.infrastructure_clearance
	var feather: float = settings.edge_feather
	for i: int in range(1, points.size()):
		var midpoint: Vector3 = (points[i - 1] + points[i]) * 0.5
		var ground_height: float = height_at.call(midpoint)
		if not is_finite(ground_height) or absf(midpoint.y - ground_height) > settings.maximum_surface_height_difference:
			continue
		var start := Vector2(points[i - 1].x, points[i - 1].z)
		var end := Vector2(points[i].x, points[i].z)
		var bounds: Rect2 = Rect2(start, Vector2.ZERO).expand(end).grow(radius + feather)
		var first := Vector2i((bounds.position / CELL_SIZE).floor())
		var last := Vector2i((bounds.end / CELL_SIZE).floor())
		for z: int in range(first.y, last.y + 1):
			for x: int in range(first.x, last.x + 1):
				var cell := Vector2i(x, z)
				if _stamp_cell(cell, bounds, start, end, radius, feather):
					changed[cell] = true
	return changed.keys()


func _stamp_cell(cell: Vector2i, bounds: Rect2, start: Vector2, end: Vector2,
		radius: float, feather: float) -> bool:
	var origin: Vector2 = Vector2(cell) * CELL_SIZE
	var first := Vector2i(((bounds.position - origin) / METRES_PER_PIXEL).floor()).max(Vector2i.ZERO)
	var last := Vector2i(((bounds.end - origin) / METRES_PER_PIXEL).ceil()).min(Vector2i(PIXELS, PIXELS))
	var image: Image = get_cell(cell)
	var changed := false
	for y: int in range(first.y, last.y):
		for x: int in range(first.x, last.x):
			var pos: Vector2 = origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * METRES_PER_PIXEL
			var distance: float = pos.distance_to(Geometry2D.get_closest_point_to_segment(pos, start, end))
			if distance >= radius + feather:
				continue
			var allowance: float = clampf((distance - radius) / feather, 0.0, 1.0) if feather > 0.0 else 0.0
			if image == null:
				image = Image.create_empty(PIXELS, PIXELS, false, Image.FORMAT_R8)
				image.fill(Color.WHITE)
				_cells[cell] = image
			if allowance < image.get_pixel(x, y).r - 0.5 / 255.0:
				image.set_pixel(x, y, Color(allowance, 0, 0))
				changed = true
	return changed
