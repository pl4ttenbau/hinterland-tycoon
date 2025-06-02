class_name PlayerCollisionArea extends Area3D

func _enter_tree() -> void:
	self.body_entered.connect(Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node3D) -> void:
	Loggie.info(body.name)
	pass # Replace with function body.
