class_name BattlefieldRules
extends RefCounted

## Static-call compat layer over Battlefield. Battlefield keeps the real
## slot-occupancy logic (validation, push_error on bad slot/reassign) as
## instance methods - combat_state.gd, combat_result_applier.gd and
## test_combat_contract.gd all call those directly and must keep working.
## This class exists purely so CombatRules / CombatStateFactory can call
## slot mutations as `BattlefieldRules.x(battlefield, ...)` without a
## second, divergent copy of the validation logic.

static func assign_combatant(battlefield: Battlefield, combatant_id: int, slot: int) -> void:
	battlefield.assign_combatant(combatant_id, slot)


static func free_slot(battlefield: Battlefield, slot: int) -> void:
	battlefield.free_slot(slot)


static func get_occupant(battlefield: Battlefield, slot: int) -> int:
	return battlefield.get_occupant(slot)


static func get_combatant_slot(battlefield: Battlefield, combatant_id: int) -> int:
	return battlefield.get_combatant_slot(combatant_id)


static func get_occupied_slots(battlefield: Battlefield) -> Array[int]:
	return battlefield.get_occupied_slots()


static func get_occupied_side_slots(battlefield: Battlefield, is_player: bool) -> Array[int]:
	return battlefield.get_occupied_side_slots(is_player)


static func get_side_combatants(battlefield: Battlefield, is_player: bool) -> Array[int]:
	return battlefield.get_side_combatants(is_player)


static func get_opposing_combatants(battlefield: Battlefield, is_player: bool) -> Array[int]:
	return battlefield.get_opposing_combatants(is_player)


static func is_occupied(battlefield: Battlefield, slot: int) -> bool:
	return battlefield.is_occupied(slot)


static func is_available(battlefield: Battlefield, slot: int) -> bool:
	return battlefield.is_available(slot)
