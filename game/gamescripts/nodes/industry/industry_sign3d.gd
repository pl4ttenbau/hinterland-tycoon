class_name IndustrySign3D extends Sprite3D

const SIGN_SCENE_UID = "uid://bb5bylj7g1h04"

#region Initializuation
func _enter_tree() -> void:
	self.global_position.y += 20.0
	
static func of(industry3d: Industry3D) -> IndustrySign3D:
	var sign3d: IndustrySign3D = load(SIGN_SCENE_UID).instantiate()
	industry3d.add_child(sign3d)
	industry3d.sign3d = sign3d
	# set name & res initial amount
	sign3d.set_sign_name(industry3d.industry.ind_name)
	sign3d.set_res_amount(0)
	return sign3d
#endregion

func set_sign_name(_name: String):
	$SubViewport/Industry3DSign.industry_name = _name

func set_res_amount(_amount: int):
	$SubViewport/Industry3DSign.res_amount = _amount
	
