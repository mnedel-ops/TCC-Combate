class_name Battlefield
extends RefCounted

## Manages battlefield slot state: occupancy, targeting, and slot queries.
## Tracks which combatant occupies which slot, generates valid target lists
## based on occupancy, and handles slot freedom when combatants die.
##
## Slots are immutable positions; occupancy is mutable. Dead combatants
## retain their slot association but free the slot for reuse.

## slot -> combatant_id (or -1 if empty/freed)
var slot_occupancy: Array[int] = [-1, -1, -1, -1]


func _init() -> void:
	# All slots start empty
	slot_occupancy = [-1, -1, -1, -1]


## Assigns combatant to slot. Must not re-assign already-occupied slot in init.
func assign_combatant(combatant_id: int, slot: int) -> void:
	if slot < 0 or slot >= 4:
		push_error("Invalid slot: %d" % slot)
		return
	if slot_occupancy[slot] != -1:
		push_error("Slot %d already occupied by %d" % [slot, slot_occupancy[slot]])
		return
	slot_occupancy[slot] = combatant_id


## Get occupant of slot. Returns -1 if empty/freed.
func get_occupant(slot: int) -> int:
	if slot < 0 or slot >= 4:
		return -1
	return slot_occupancy[slot]


## Get slot of combatant. Returns -1 if not found.
func get_combatant_slot(combatant_id: int) -> int:
	return slot_occupancy.find(combatant_id)


## Free the slot (combatant died). Slot association remains for logic,
## but occupancy is cleared (-1).
func free_slot(slot: int) -> void:
	if slot >= 0 and slot < 4:
		slot_occupancy[slot] = -1


## Get all occupied slots.
func get_occupied_slots() -> Array[int]:
	var occupied: Array[int] = []
	for slot in range(4):
		if slot_occupancy[slot] != -1:
			occupied.append(slot)
	return occupied


## Get all occupied slots on a side (player or enemy).
func get_occupied_side_slots(is_player: bool) -> Array[int]:
	var side_slots := BattlefieldSlot.get_side_slots(is_player)
	var occupied: Array[int] = []
	for slot in side_slots:
		if slot_occupancy[slot] != -1:
			occupied.append(slot)
	return occupied


## Get all combatant IDs on a side.
func get_side_combatants(is_player: bool) -> Array[int]:
	var combatants: Array[int] = []
	for slot in BattlefieldSlot.get_side_slots(is_player):
		if slot_occupancy[slot] != -1:
			combatants.append(slot_occupancy[slot])
	return combatants


## Get all combatant IDs on opposite side.
func get_opposing_combatants(is_player: bool) -> Array[int]:
	return get_side_combatants(not is_player)


## Check if slot is occupied.
func is_occupied(slot: int) -> bool:
	if slot < 0 or slot >= 4:
		return false
	return slot_occupancy[slot] != -1


## Check if slot is unoccupied/freed.
func is_available(slot: int) -> bool:
	return not is_occupied(slot)


## Get debug representation.
func _to_string() -> String:
	return "Battlefield(slots=[P1:%d, P2:%d, E1:%d, E2:%d])" % slot_occupancy
