class_name Battlefield
extends RefCounted

## Pure data. Slot occupancy only - no behavior, no validation, no
## side effects. All queries/mutations live in BattlefieldRules,
## same split as CombatState (data) / CombatRules (logic).

## slot -> combatant_id (or -1 if empty/freed)
var slot_occupancy: Array[int] = [-1, -1, -1, -1]


func _init() -> void:
	slot_occupancy = [-1, -1, -1, -1]
