class_name BattlefieldSlot
extends RefCounted

## Slot positions on the battlefield: 2 per side (player/enemy).
## Slots represent fixed combat positions where targeting, bonding, and
## positional rules can anchor.

const PLAYER_SLOT_1 := 0
const PLAYER_SLOT_2 := 1
const ENEMY_SLOT_1 := 2
const ENEMY_SLOT_2 := 3


static func slot_name(slot: int) -> String:
	match slot:
		PLAYER_SLOT_1:
			return "Player Slot 1"
		PLAYER_SLOT_2:
			return "Player Slot 2"
		ENEMY_SLOT_1:
			return "Enemy Slot 1"
		ENEMY_SLOT_2:
			return "Enemy Slot 2"
		_:
			return "Unknown Slot"


static func is_player_slot(slot: int) -> bool:
	return slot == PLAYER_SLOT_1 or slot == PLAYER_SLOT_2


static func is_enemy_slot(slot: int) -> bool:
	return slot == ENEMY_SLOT_1 or slot == ENEMY_SLOT_2


static func get_side_slots(is_player: bool) -> Array[int]:
	if is_player:
		return [PLAYER_SLOT_1, PLAYER_SLOT_2]
	else:
		return [ENEMY_SLOT_1, ENEMY_SLOT_2]


static func get_opposite_side_slots(is_player: bool) -> Array[int]:
	if is_player:
		return [ENEMY_SLOT_1, ENEMY_SLOT_2]
	else:
		return [PLAYER_SLOT_1, PLAYER_SLOT_2]
