extends GdUnitTestSuite

## BattlefieldRules is a thin static delegate over Battlefield - these
## tests exist to pin down that every delegated call actually reaches
## the real Battlefield instance method with the right arguments, so a
## future "just remove the wrapper" refactor (or a local file drifting
## out of sync, as just happened) gets caught immediately instead of
## failing at runtime deep in combat resolution.

var battlefield: Battlefield


func before_test() -> void:
	battlefield = Battlefield.new()


func test_assign_combatant_places_id_in_slot() -> void:
	BattlefieldRules.assign_combatant(battlefield, 5, BattlefieldSlot.PLAYER_SLOT_1)
	assert_int(BattlefieldRules.get_occupant(battlefield, BattlefieldSlot.PLAYER_SLOT_1)).is_equal(5)


func test_assign_combatant_rejects_already_occupied_slot() -> void:
	BattlefieldRules.assign_combatant(battlefield, 5, BattlefieldSlot.PLAYER_SLOT_1)
	BattlefieldRules.assign_combatant(battlefield, 6, BattlefieldSlot.PLAYER_SLOT_1)
	assert_int(BattlefieldRules.get_occupant(battlefield, BattlefieldSlot.PLAYER_SLOT_1)) \
		.override_failure_message("second assign to an occupied slot should be rejected, not overwrite") \
		.is_equal(5)


func test_get_occupant_returns_negative_one_when_empty() -> void:
	assert_int(BattlefieldRules.get_occupant(battlefield, BattlefieldSlot.ENEMY_SLOT_1)).is_equal(-1)


func test_get_combatant_slot_finds_correct_slot() -> void:
	BattlefieldRules.assign_combatant(battlefield, 7, BattlefieldSlot.ENEMY_SLOT_2)
	assert_int(BattlefieldRules.get_combatant_slot(battlefield, 7)).is_equal(BattlefieldSlot.ENEMY_SLOT_2)


func test_get_combatant_slot_returns_negative_one_when_not_found() -> void:
	assert_int(BattlefieldRules.get_combatant_slot(battlefield, 99)).is_equal(-1)


func test_free_slot_clears_occupant() -> void:
	BattlefieldRules.assign_combatant(battlefield, 5, BattlefieldSlot.PLAYER_SLOT_1)
	BattlefieldRules.free_slot(battlefield, BattlefieldSlot.PLAYER_SLOT_1)
	assert_int(BattlefieldRules.get_occupant(battlefield, BattlefieldSlot.PLAYER_SLOT_1)).is_equal(-1)


func test_free_slot_allows_reassignment() -> void:
	BattlefieldRules.assign_combatant(battlefield, 5, BattlefieldSlot.PLAYER_SLOT_1)
	BattlefieldRules.free_slot(battlefield, BattlefieldSlot.PLAYER_SLOT_1)
	BattlefieldRules.assign_combatant(battlefield, 6, BattlefieldSlot.PLAYER_SLOT_1)
	assert_int(BattlefieldRules.get_occupant(battlefield, BattlefieldSlot.PLAYER_SLOT_1)).is_equal(6)


func test_get_occupied_slots_lists_all_filled() -> void:
	BattlefieldRules.assign_combatant(battlefield, 1, BattlefieldSlot.PLAYER_SLOT_1)
	BattlefieldRules.assign_combatant(battlefield, 2, BattlefieldSlot.ENEMY_SLOT_2)
	var occupied := BattlefieldRules.get_occupied_slots(battlefield)
	assert_int(occupied.size()).is_equal(2)
	assert_bool(BattlefieldSlot.PLAYER_SLOT_1 in occupied).is_true()
	assert_bool(BattlefieldSlot.ENEMY_SLOT_2 in occupied).is_true()


func test_get_occupied_side_slots_filters_by_side() -> void:
	BattlefieldRules.assign_combatant(battlefield, 1, BattlefieldSlot.PLAYER_SLOT_1)
	BattlefieldRules.assign_combatant(battlefield, 2, BattlefieldSlot.PLAYER_SLOT_2)
	BattlefieldRules.assign_combatant(battlefield, 3, BattlefieldSlot.ENEMY_SLOT_1)

	var player_slots := BattlefieldRules.get_occupied_side_slots(battlefield, true)
	assert_int(player_slots.size()).is_equal(2)
	assert_bool(BattlefieldSlot.ENEMY_SLOT_1 in player_slots) \
		.override_failure_message("enemy slot leaked into player side query") \
		.is_false()


func test_get_side_combatants_returns_ids_on_that_side() -> void:
	BattlefieldRules.assign_combatant(battlefield, 10, BattlefieldSlot.PLAYER_SLOT_1)
	BattlefieldRules.assign_combatant(battlefield, 20, BattlefieldSlot.PLAYER_SLOT_2)
	BattlefieldRules.assign_combatant(battlefield, 30, BattlefieldSlot.ENEMY_SLOT_1)

	var player_ids := BattlefieldRules.get_side_combatants(battlefield, true)
	assert_int(player_ids.size()).is_equal(2)
	assert_bool(10 in player_ids).is_true()
	assert_bool(20 in player_ids).is_true()
	assert_bool(30 in player_ids).is_false()


func test_get_opposing_combatants_returns_other_side() -> void:
	BattlefieldRules.assign_combatant(battlefield, 10, BattlefieldSlot.PLAYER_SLOT_1)
	BattlefieldRules.assign_combatant(battlefield, 30, BattlefieldSlot.ENEMY_SLOT_1)

	var opposing_to_player := BattlefieldRules.get_opposing_combatants(battlefield, true)
	assert_int(opposing_to_player.size()).is_equal(1)
	assert_bool(30 in opposing_to_player).is_true()


func test_is_occupied_true_after_assign() -> void:
	BattlefieldRules.assign_combatant(battlefield, 1, BattlefieldSlot.PLAYER_SLOT_1)
	assert_bool(BattlefieldRules.is_occupied(battlefield, BattlefieldSlot.PLAYER_SLOT_1)).is_true()


func test_is_occupied_false_when_empty() -> void:
	assert_bool(BattlefieldRules.is_occupied(battlefield, BattlefieldSlot.PLAYER_SLOT_1)).is_false()


func test_is_available_is_inverse_of_is_occupied() -> void:
	assert_bool(BattlefieldRules.is_available(battlefield, BattlefieldSlot.PLAYER_SLOT_1)).is_true()
	BattlefieldRules.assign_combatant(battlefield, 1, BattlefieldSlot.PLAYER_SLOT_1)
	assert_bool(BattlefieldRules.is_available(battlefield, BattlefieldSlot.PLAYER_SLOT_1)).is_false()
