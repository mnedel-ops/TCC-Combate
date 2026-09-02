class_name TestBattlefieldSlots
extends GDUnitTestSuite

## Tests for the slot system: initialization, occupancy, death, and targeting.


func test_battlefield_slot_constants() -> void:
	assert_that(BattlefieldSlot.PLAYER_SLOT_1).is_equal(0)
	assert_that(BattlefieldSlot.PLAYER_SLOT_2).is_equal(1)
	assert_that(BattlefieldSlot.ENEMY_SLOT_1).is_equal(2)
	assert_that(BattlefieldSlot.ENEMY_SLOT_2).is_equal(3)


func test_battlefield_slot_utilities() -> void:
	assert_that(BattlefieldSlot.is_player_slot(BattlefieldSlot.PLAYER_SLOT_1)).is_true()
	assert_that(BattlefieldSlot.is_player_slot(BattlefieldSlot.ENEMY_SLOT_1)).is_false()
	assert_that(BattlefieldSlot.is_enemy_slot(BattlefieldSlot.ENEMY_SLOT_1)).is_true()
	assert_that(BattlefieldSlot.is_enemy_slot(BattlefieldSlot.PLAYER_SLOT_1)).is_false()


func test_battlefield_init() -> void:
	var bf := Battlefield.new()
	# All slots should be empty initially
	assert_that(bf.get_occupant(BattlefieldSlot.PLAYER_SLOT_1)).is_equal(-1)
	assert_that(bf.get_occupant(BattlefieldSlot.PLAYER_SLOT_2)).is_equal(-1)
	assert_that(bf.get_occupant(BattlefieldSlot.ENEMY_SLOT_1)).is_equal(-1)
	assert_that(bf.get_occupant(BattlefieldSlot.ENEMY_SLOT_2)).is_equal(-1)


func test_battlefield_assign_and_query() -> void:
	var bf := Battlefield.new()
	
	# Assign combatants to slots
	bf.assign_combatant(0, BattlefieldSlot.PLAYER_SLOT_1)
	bf.assign_combatant(1, BattlefieldSlot.PLAYER_SLOT_2)
	bf.assign_combatant(2, BattlefieldSlot.ENEMY_SLOT_1)
	bf.assign_combatant(3, BattlefieldSlot.ENEMY_SLOT_2)
	
	# Query occupants
	assert_that(bf.get_occupant(BattlefieldSlot.PLAYER_SLOT_1)).is_equal(0)
	assert_that(bf.get_occupant(BattlefieldSlot.PLAYER_SLOT_2)).is_equal(1)
	assert_that(bf.get_occupant(BattlefieldSlot.ENEMY_SLOT_1)).is_equal(2)
	assert_that(bf.get_occupant(BattlefieldSlot.ENEMY_SLOT_2)).is_equal(3)
	
	# Query combatant slots
	assert_that(bf.get_combatant_slot(0)).is_equal(BattlefieldSlot.PLAYER_SLOT_1)
	assert_that(bf.get_combatant_slot(1)).is_equal(BattlefieldSlot.PLAYER_SLOT_2)
	assert_that(bf.get_combatant_slot(2)).is_equal(BattlefieldSlot.ENEMY_SLOT_1)
	assert_that(bf.get_combatant_slot(3)).is_equal(BattlefieldSlot.ENEMY_SLOT_2)


func test_battlefield_free_slot() -> void:
	var bf := Battlefield.new()
	
	# Assign and verify
	bf.assign_combatant(0, BattlefieldSlot.PLAYER_SLOT_1)
	assert_that(bf.is_occupied(BattlefieldSlot.PLAYER_SLOT_1)).is_true()
	
	# Free the slot
	bf.free_slot(BattlefieldSlot.PLAYER_SLOT_1)
	assert_that(bf.is_occupied(BattlefieldSlot.PLAYER_SLOT_1)).is_false()
	assert_that(bf.is_available(BattlefieldSlot.PLAYER_SLOT_1)).is_true()
	assert_that(bf.get_occupant(BattlefieldSlot.PLAYER_SLOT_1)).is_equal(-1)


func test_battlefield_side_queries() -> void:
	var bf := Battlefield.new()
	bf.assign_combatant(0, BattlefieldSlot.PLAYER_SLOT_1)
	bf.assign_combatant(1, BattlefieldSlot.PLAYER_SLOT_2)
	bf.assign_combatant(2, BattlefieldSlot.ENEMY_SLOT_1)
	bf.assign_combatant(3, BattlefieldSlot.ENEMY_SLOT_2)
	
	var player_side := bf.get_side_combatants(true)
	var enemy_side := bf.get_side_combatants(false)
	
	assert_that(player_side).contains(0, 1)
	assert_that(enemy_side).contains(2, 3)


func test_state_factory_assigns_slots() -> void:
	var db := AlchemonDatabase.new()
	# Load test data or create minimal templates
	# For now, just verify factory initializes slots correctly
	
	# This test will need actual AlchemonDatabase data
	# Skip for now until test environment is set up
	pass


func test_combat_state_valid_targets_basic() -> void:
	var state := CombatState.new()
	
	# Create combatants
	var player1 := CombatantState.new(0, 1, 10, true, BattlefieldSlot.PLAYER_SLOT_1)
	var player2 := CombatantState.new(1, 2, 10, true, BattlefieldSlot.PLAYER_SLOT_2)
	var enemy1 := CombatantState.new(2, 3, 10, false, BattlefieldSlot.ENEMY_SLOT_1)
	var enemy2 := CombatantState.new(3, 4, 10, false, BattlefieldSlot.ENEMY_SLOT_2)
	
	state.combatants[0] = player1
	state.combatants[1] = player2
	state.combatants[2] = enemy1
	state.combatants[3] = enemy2
	
	state.player_ids = [0, 1]
	state.enemy_ids = [2, 3]
	
	# Assign to battlefield
	state.battlefield.assign_combatant(0, BattlefieldSlot.PLAYER_SLOT_1)
	state.battlefield.assign_combatant(1, BattlefieldSlot.PLAYER_SLOT_2)
	state.battlefield.assign_combatant(2, BattlefieldSlot.ENEMY_SLOT_1)
	state.battlefield.assign_combatant(3, BattlefieldSlot.ENEMY_SLOT_2)
	
	# Player 0 should target enemies (2, 3)
	var targets_p0 := state.get_valid_targets(0)
	assert_that(targets_p0).contains(2, 3)
	assert_that(targets_p0).does_not_contain(0, 1)
	
	# Enemy 2 should target players (0, 1)
	var targets_e2 := state.get_valid_targets(2)
	assert_that(targets_e2).contains(0, 1)
	assert_that(targets_e2).does_not_contain(2, 3)


func test_combat_state_valid_targets_dead_excluded() -> void:
	var state := CombatState.new()
	
	# Create combatants
	var player1 := CombatantState.new(0, 1, 10, true, BattlefieldSlot.PLAYER_SLOT_1)
	var enemy1 := CombatantState.new(2, 3, 10, false, BattlefieldSlot.ENEMY_SLOT_1)
	var enemy2 := CombatantState.new(3, 4, 10, false, BattlefieldSlot.ENEMY_SLOT_2)
	
	enemy2.alive = false  # Enemy 2 is dead
	
	state.combatants[0] = player1
	state.combatants[2] = enemy1
	state.combatants[3] = enemy2
	
	state.player_ids = [0]
	state.enemy_ids = [2, 3]
	
	# Assign to battlefield
	state.battlefield.assign_combatant(0, BattlefieldSlot.PLAYER_SLOT_1)
	state.battlefield.assign_combatant(2, BattlefieldSlot.ENEMY_SLOT_1)
	state.battlefield.assign_combatant(3, BattlefieldSlot.ENEMY_SLOT_2)
	
	# Player 0 should only target alive enemy (2)
	var targets := state.get_valid_targets(0)
	assert_that(targets).contains(2)
	assert_that(targets).does_not_contain(3)  # Dead enemy excluded


func test_combat_state_alive_opposing_combatants() -> void:
	var state := CombatState.new()
	
	# Create combatants
	var enemy1 := CombatantState.new(2, 3, 10, false, BattlefieldSlot.ENEMY_SLOT_1)
	var enemy2 := CombatantState.new(3, 4, 10, false, BattlefieldSlot.ENEMY_SLOT_2)
	
	enemy2.alive = false
	
	state.combatants[2] = enemy1
	state.combatants[3] = enemy2
	
	state.enemy_ids = [2, 3]
	
	# Assign to battlefield
	state.battlefield.assign_combatant(2, BattlefieldSlot.ENEMY_SLOT_1)
	state.battlefield.assign_combatant(3, BattlefieldSlot.ENEMY_SLOT_2)
	
	var alive_opposing := state.get_alive_opposing_combatants(true)
	assert_that(alive_opposing).contains(2)
	assert_that(alive_opposing).does_not_contain(3)
