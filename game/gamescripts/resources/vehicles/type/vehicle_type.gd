@icon("uid://dxyodhnxhip0d")
class_name VehicleTypeData extends Resource

@export var key: String

@export var display_name: String

@export var model_scene_path: String

## Road models may be catalogued before their operating specifications are known.
## Loaded rail definitions still require a positive integer speed.
var max_speed_kmh: Variant = null

@export var usable_infr: UsableInfrType

@export var has_motor: bool = false

@export var motor_type: GameEnums.MotorType = GameEnums.MotorType.UNKNOWN

@export var capacity: GoodsCapacity

@export var length_metres: float

## Empty vehicle mass in metric tonnes and motor output in kilowatts. Variant preserves unknown (null) values;
## typed floats would turn unknown values into zero.
## Empty mass ("Leermasse") is the vehicle without fuel, water, sand, crew or load. It is what a wagon's
## load is added to and what pricing compares; it is NOT what a locomotive weighs when it runs.
var mass_tonnes: Variant = null
## Mass in working order ("Dienstmasse") in tonnes: empty mass plus fuel, water, sand, lubricants and crew.
## For a steam locomotive the difference is large (several tonnes of water and coal); for a diesel it is
## usually a few percent; for a wagon it is the same as the empty mass. Null means "same as empty mass".
## Read it through get_service_mass_tonnes(), which applies that fallback.
var service_mass_tonnes: Variant = null
## Share of the service mass resting on driven axles ("Reibungsmasse"), in tonnes. It bounds how hard
## the vehicle can pull before its wheels slip (see RailPhysics.adhesion_limit). Null means every axle
## is driven, which holds for most locomotives; railcars and steam locomotives with carrying axles or
## tenders have less. Ignored for vehicles without a motor. Read it through get_adhesive_mass_tonnes().
var adhesive_mass_tonnes: Variant = null
## Braked mass ("Bremsgewicht") in tonnes: the brake performance stamped on the vehicle, found by brake
## tests and expressed as an equivalent mass. Summed over a train and divided by the train mass it gives
## the brake percentage (see RailPhysics.brake_percentage). Null means unknown; 0 means unbraked, as
## with many old narrow-gauge wagons that only had a hand brake on some vehicles.
var braked_mass_tonnes: Variant = null
var motor_power_kw: Variant = null
## Starting tractive effort in kN; null means it has not been supplied in the catalog.
var tractive_effort_kn: Variant = null
## Catalog purchase price in whole game DM; null permits formula-based pricing.
var purchase_price: Variant = null

#region Initialization
static func of_key(_key: String) -> VehicleTypeData:
	var inst: VehicleTypeData = VehicleTypeData.new()
	inst.key = _key
	return inst
	
static func of_dict(_dict: Dictionary) -> VehicleTypeData:
	return VehicleMapper.type_dict_to_class(_dict)
#endregion

#region Getters
func get_mesh_path() -> String:
	return self.model_scene_path
	
func get_preview_img_path() -> String:
	return self.model_scene_path.get_base_dir().path_join("preview.png")
	
func is_locomotive(): return self.has_motor

## Mass in working order, falling back to the empty mass when the catalog only knows that.
## Null when neither is known; callers choose their own default for that case.
func get_service_mass_tonnes() -> Variant:
	if _positive_number(self.service_mass_tonnes):
		return float(self.service_mass_tonnes)
	if _positive_number(self.mass_tonnes):
		return float(self.mass_tonnes)
	return null

## Mass on driven axles: authored value, otherwise the whole service mass (all axles driven).
## Zero for vehicles without a motor, since none of their weight helps traction.
## Null when the vehicle has a motor but no mass is known at all.
func get_adhesive_mass_tonnes() -> Variant:
	if not self.has_motor:
		return 0.0
	if _positive_number(self.adhesive_mass_tonnes):
		return float(self.adhesive_mass_tonnes)
	return self.get_service_mass_tonnes()

static func _positive_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value > 0

## Concrete vehicle domains supply their purchase-price balance.
func get_purchase_price() -> Variant:
	return purchase_price

static func get_by_key(veh_type_key: String) -> VehicleTypeData:
	return GameTypes.get_veh_type(veh_type_key)
#endregion
