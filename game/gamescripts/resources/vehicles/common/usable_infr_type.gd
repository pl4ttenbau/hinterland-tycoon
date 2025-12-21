## type of infrastructure that a vehicle can use
## per example: ROAD but only level 2 (RURAL_ROAD)
## or rail tracks (RAIL) but only on 750mm (750_MM)
class_name UsableInfrType extends Resource

@export var domain: Enums.InfrDomain
@export var subtype: String

#region Static Constructors
static func of_domain(_domain: Enums.InfrDomain) -> UsableInfrType:
	var inst := UsableInfrType.new()
	inst.domain = _domain
	return inst
	
static func of(_domain: Enums.InfrDomain, _subtype: String) -> UsableInfrType:
	var inst := UsableInfrType.of_domain(_domain)
	inst.subtype = _subtype
	return inst

static func of_dict(_dict: Dictionary) -> UsableInfrType:
	var inst := UsableInfrType.new()
	inst.domain = InfrUtils.infr_domain_str_2_enum(_dict.get("domain"))
	if _dict.has("subtype"):
		inst.subtype = _dict.get("subtype")
	return inst
#endregion
