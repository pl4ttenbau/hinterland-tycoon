## A separate field-plant layer sharing our bounded terrain-particle placement.
@tool
extends "res://game/gamescripts/nodes/world/terrain_grass.gd"

func get_vegetation_layer() -> StringName:
	return &"wheat"

func _make_crossed_cards() -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS: int = 4
	for card: int in range(2):
		var rotation := Basis(Vector3.UP, float(card) * PI / 2.0)
		for segment: int in range(SEGMENTS):
			var bottom: float = float(segment) / SEGMENTS
			var top: float = float(segment + 1) / SEGMENTS
			var positions: Array[Vector3] = [Vector3(-0.9, bottom * 1.8, 0), Vector3(-0.9, top * 1.8, 0),
				Vector3(0.9, top * 1.8, 0), Vector3(0.9, bottom * 1.8, 0)]
			var uvs: Array[Vector2] = [Vector2(0, 1.0 - bottom), Vector2(0, 1.0 - top),
				Vector2(1, 1.0 - top), Vector2(1, 1.0 - bottom)]
			for index: int in [0, 1, 2, 0, 2, 3]:
				builder.set_color(Color.WHITE)
				builder.set_normal(Vector3.UP)
				builder.set_uv(uvs[index])
				builder.set_uv2(Vector2(float(card) / 3.0, 0.0))
				builder.add_vertex(rotation * positions[index])
	return builder.commit()
