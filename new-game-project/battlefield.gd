class_name Battlefield
extends RefCounted

## Pure data. Slot occupancy only - no behavior, no validation, no
## side effects. All queries/mutations live in BattlefieldRules,
## same split as CombatState (data) / CombatRules (logic).

## slot -> combatant_id (or -1 if empty/freed)
var slot_occupancy: Array[int] = [-1, -1, -1, -1]

func assign_combatant(combatant_id: int, slot: int) -> void:
	if slot < 0 or slot >= BattlefieldSlot.SLOT_COUNT:
		push_error("Invalid slot: %d" % slot)
		return
	if slot_occupancy[slot] != -1:
		push_error("Slot %d already occupied by %d" % [slot, slot_occupancy[slot]])
		return
	slot_occupancy[slot] = combatant_id
