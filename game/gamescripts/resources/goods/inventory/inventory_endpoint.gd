## Lightweight UI/service reference to a live inventory component and its access position.
class_name InventoryEndpoint extends RefCounted

enum Kind { OTHER, PLAYER, VEHICLE, STOP, INDUSTRY }
var kind: Kind = Kind.OTHER
var label: String
var _component: WeakRef
var _anchor: WeakRef

static func from_node(owner: Node, title: String = "", access: Node3D = null) -> InventoryEndpoint:
	var component: InventoryContainer = InventoryContainer.find_on(owner)
	if component == null:
		return null
	var endpoint := InventoryEndpoint.new()
	endpoint._component = weakref(component)
	endpoint._anchor = weakref(access if access != null else owner)
	endpoint.label = title if not title.is_empty() else (component.display_name if not component.display_name.is_empty() else str(owner.name))
	return endpoint

func component() -> InventoryContainer:
	return _component.get_ref() as InventoryContainer if _component != null else null

func available() -> bool:
	var node: InventoryContainer = component()
	return is_instance_valid(node) and node.is_inside_tree()

func inventory() -> GoodsInventory:
	return component().get_inventory() if available() else null

func position() -> Vector3:
	var node: Node3D = _anchor.get_ref() as Node3D if _anchor != null else null
	return node.global_position if is_instance_valid(node) and node.is_inside_tree() else Vector3.INF
