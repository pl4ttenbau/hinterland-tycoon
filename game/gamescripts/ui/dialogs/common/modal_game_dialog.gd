## Holds a world-input block for the lifetime of the dialog in the scene tree.
class_name ModalGameDialog extends GameDialog


func _enter_tree() -> void:
	super()
	UiState.block_world_input(self)


func _exit_tree() -> void:
	super()
	# Tree removal also releases the block when a scene is unloaded or freed directly.
	UiState.release_world_input(self)
