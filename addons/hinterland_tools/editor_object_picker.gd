@tool
@abstract
## Typed selection contract for infrastructure and future town/industry pickers.
class_name EditorObjectPicker extends RefCounted

@abstract func get_hits(world: Node, camera: Camera3D, mouse: Vector2, max_depth: float = INF) -> Array[EditorPickHit]
