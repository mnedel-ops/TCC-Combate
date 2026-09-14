class_name TypeEffectiveness
extends RefCounted

## Pure lookup, GDD sec 6. Cycle:
##   Metal supera Metaloide -> Metaloide supera Ametal -> Ametal supera Metal
## Attacker's own element (no separate move-type field yet) is compared
## against the defender's element to get the damage multiplier.

const SUPER_EFFECTIVE := 1.5
const RESISTED := 0.66
const NEUTRAL := 1.0


## True if attacker_type beats defender_type in the cycle above.
static func _beats(attacker_type: String, defender_type: String) -> bool:
	match attacker_type:
		ElementType.METAL:
			return defender_type == ElementType.METALOIDE
		ElementType.METALOIDE:
			return defender_type == ElementType.AMETAL
		ElementType.AMETAL:
			return defender_type == ElementType.METAL
		_:
			return false


static func get_multiplier(attacker_type: String, defender_type: String) -> float:
	if _beats(attacker_type, defender_type):
		return SUPER_EFFECTIVE
	if _beats(defender_type, attacker_type):
		return RESISTED
	return NEUTRAL
