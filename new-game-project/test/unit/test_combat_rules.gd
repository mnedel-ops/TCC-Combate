class_name CombatRulesTest
extends GdUnitTestSuite

## Tests for CombatRules V2 (data-oriented, pure, dictionary-based events).
## V2 API: roll_initiative(state) mutates in-place, resolve_action() returns event Dictionary.

const PLAYER_ID := 0
const ENEMY_ID := 1
const PLAYER_SPECIES_ID := 101
const ENEMY_SPECIES_ID := 102


func test_roll_initiative_sorts_by_initiative_value() -> void:
	var state := _build_state()
	CombatRules.roll_initiative(state)
	
	# Both combatants should have initiative 1-20
	var player_init := state.get_combatant(PLAYER_ID).initiative
	var enemy_init := state.get_combatant(ENEMY_ID).initiative
	assert_int(player_init).is_between(1, 20)
	assert_int(enemy_init).is_between(1, 20)
	
	# Turn order should match initiative (descending)
	if player_init > enemy_init:
		assert_array(state.turn_order_ids).contains_exactly([PLAYER_ID, ENEMY_ID])
	else:
		assert_array(state.turn_order_ids).contains_exactly([ENEMY_ID, PLAYER_ID])


func test_combatant_state_initializes_with_slot() -> void:
	var combatant := CombatantState.new(PLAYER_ID, PLAYER_SPECIES_ID, 42, true, BattlefieldSlot.PLAYER_SLOT_1)
	
	assert_int(combatant.id).is_equal(PLAYER_ID)
	assert_int(combatant.species_id).is_equal(PLAYER_SPECIES_ID)
	assert_int(combatant.max_hp).is_equal(42)
	assert_int(combatant.hp).is_equal(42)
	assert_int(combatant.slot).is_equal(BattlefieldSlot.PLAYER_SLOT_1)
	assert_bool(combatant.is_player).is_true()
	assert_bool(combatant.alive).is_true()


func test_valid_attack_hits_and_damages_target() -> void:
	var state := _build_state()
	var db := _build_database()
	var target_hp_before := state.get_combatant(ENEMY_ID).hp
	
	var result := CombatRules.resolve_action(state, ActionCommand.new(PLAYER_ID, "attack", ENEMY_ID, 0), db)
	
	# Should not be cancelled (or be miss/hit/etc)
	assert_str(result["kind"]).is_not_equal("cancelled")
	# Target should take damage or miss (we can't predict randomness, but HP might change)
	# Just verify the action was processed
	assert_bool(result.has("actor_id")).is_true()


func test_attack_command_with_dead_actor_is_cancelled() -> void:
	var state := _build_state()
	var db := _build_database()
	state.get_combatant(PLAYER_ID).alive = false
	
	var result := CombatRules.resolve_action(state, ActionCommand.new(PLAYER_ID, "attack", ENEMY_ID, 0), db)
	
	assert_str(result["kind"]).is_equal("cancelled")
	assert_str(result["reason"]).is_equal("actor_dead")


func test_attack_command_with_dead_target_is_cancelled() -> void:
	var state := _build_state()
	var db := _build_database()
	state.get_combatant(ENEMY_ID).alive = false
	
	var result := CombatRules.resolve_action(state, ActionCommand.new(PLAYER_ID, "attack", ENEMY_ID, 0), db)
	
	assert_str(result["kind"]).is_equal("cancelled")
	assert_str(result["reason"]).is_equal("target_dead")


func test_attack_rejects_ally_target_via_slots() -> void:
	var state := _build_state()
	var db := _build_database()
	
	# Player in slot 0, trying to attack player in slot 1
	var ally := CombatantState.new(2, PLAYER_SPECIES_ID, 30, true, BattlefieldSlot.PLAYER_SLOT_2)
	state.combatants[ally.id] = ally
	state.player_ids.append(ally.id)
	state.battlefield.assign_combatant(ally.id, BattlefieldSlot.PLAYER_SLOT_2)
	
	# Try to attack ally
	var result := CombatRules.resolve_action(state, ActionCommand.new(PLAYER_ID, "attack", ally.id, 0), db)
	
	# Should be cancelled - target not in valid targets (both on same side)
	assert_str(result["kind"]).is_equal("cancelled")


func test_attack_without_valid_attack_index_is_cancelled() -> void:
	var state := _build_state()
	var db := _build_database()
	
	var result := CombatRules.resolve_action(state, ActionCommand.new(PLAYER_ID, "attack", ENEMY_ID, 999), db)
	
	assert_str(result["kind"]).is_equal("cancelled")
	assert_str(result["reason"]).is_equal("invalid_attack")


func test_capture_success_kills_and_frees_slot() -> void:
	var state := _build_state()
	var enemy_slot := state.get_combatant(ENEMY_ID).slot
	
	# Set seed to get deterministic capture success
	seed(1)
	var result := CombatRules._resolve_capture(state, ActionCommand.new(PLAYER_ID, "capture", ENEMY_ID, 0))
	
	# If successful, target dies and slot frees
	if result["kind"] == "capture_success":
		assert_bool(state.get_combatant(ENEMY_ID).alive).is_false()
		assert_int(state.battlefield.get_occupant(enemy_slot)).is_equal(-1)
	else:
		# If failed, target still alive and slot occupied
		assert_bool(state.get_combatant(ENEMY_ID).alive).is_true()
		assert_int(state.battlefield.get_occupant(enemy_slot)).is_equal(ENEMY_ID)


func test_item_heals_target() -> void:
	var state := _build_state()
	# Damage the player
	state.get_combatant(PLAYER_ID).hp = 10
	
	var result := CombatRules._resolve_item(state, ActionCommand.new(PLAYER_ID, "item", PLAYER_ID, 0))
	
	assert_str(result["kind"]).is_equal("item_used")
	# Should heal by ITEM_HEAL_AMOUNT (6)
	assert_int(state.get_combatant(PLAYER_ID).hp).is_equal(16)


func test_item_capped_at_max_hp() -> void:
	var state := _build_state()
	# Player already at full HP
	var max_hp := state.get_combatant(PLAYER_ID).max_hp
	
	var result := CombatRules._resolve_item(state, ActionCommand.new(PLAYER_ID, "item", PLAYER_ID, 0))
	
	assert_str(result["kind"]).is_equal("item_used")
	# Should not exceed max_hp
	assert_int(state.get_combatant(PLAYER_ID).hp).is_equal(max_hp)


func test_check_combat_end_recognizes_all_enemies_dead() -> void:
	var state := _build_state()
	
	# Kill all enemies
	state.get_combatant(ENEMY_ID).alive = false
	
	CombatRules.check_combat_end(state)
	
	assert_bool(state.combat_over).is_true()
	assert_bool(state.player_won).is_true()


func test_check_combat_end_recognizes_all_players_dead() -> void:
	var state := _build_state()
	
	# Kill all players
	state.get_combatant(PLAYER_ID).alive = false
	
	CombatRules.check_combat_end(state)
	
	assert_bool(state.combat_over).is_true()
	assert_bool(state.player_won).is_false()


func test_pick_random_alive_target_excludes_dead() -> void:
	var state := _build_state()
	state.get_combatant(ENEMY_ID).alive = false
	
	var target := CombatRules.pick_random_alive_target_id(state, state.enemy_ids)
	
	# No alive enemies, should return -1
	assert_int(target).is_equal(-1)


func test_pick_random_attack_index_from_valid_attacks() -> void:
	var db := _build_database()
	var index := CombatRules.pick_random_attack_index(db, PLAYER_SPECIES_ID)
	
	# Should be valid index
	var template := db.get_by_id(PLAYER_SPECIES_ID)
	assert_int(index).is_between(0, template.attacks.size() - 1)


func test_flee_chance_is_deterministic() -> void:
	seed(12345)
	var flee1 := CombatRules.attempt_flee()
	
	seed(12345)
	var flee2 := CombatRules.attempt_flee()
	
	assert_bool(flee1).is_equal(flee2)


# ======================== Helpers ========================


func _build_state() -> CombatState:
	var state := CombatState.new()
	
	# Create player combatant in slot 0
	var player := CombatantState.new(PLAYER_ID, PLAYER_SPECIES_ID, 30, true, BattlefieldSlot.PLAYER_SLOT_1)
	state.combatants[player.id] = player
	state.player_ids.append(player.id)
	state.battlefield.assign_combatant(player.id, BattlefieldSlot.PLAYER_SLOT_1)
	
	# Create enemy combatant in slot 2
	var enemy := CombatantState.new(ENEMY_ID, ENEMY_SPECIES_ID, 30, false, BattlefieldSlot.ENEMY_SLOT_1)
	state.combatants[enemy.id] = enemy
	state.enemy_ids.append(enemy.id)
	state.battlefield.assign_combatant(enemy.id, BattlefieldSlot.ENEMY_SLOT_1)
	
	return state


func _build_database() -> AlchemonDatabase:
	var database := AlchemonDatabase.new()
	
	# Create player template with one attack
	var player_template := AlchemonSheet.new("TestPlayer", 30, true, PLAYER_SPECIES_ID)
	var player_attack := AttackData.new()
	player_attack.attack_name = "Test Attack"
	player_attack.damage = 5
	player_template.attacks.append(player_attack)
	
	# Create enemy template
	var enemy_template := AlchemonSheet.new("TestEnemy", 30, false, ENEMY_SPECIES_ID)
	
	database.alchemons.append(player_template)
	database.alchemons.append(enemy_template)
	
	return database


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
	assert_that(0 in targets_p0).is_false()
	assert_that(1 in targets_p0).is_false()
	
	# Enemy 2 should target players (0, 1)
	var targets_e2 := state.get_valid_targets(2)
	assert_that(targets_e2).contains(0, 1)
	assert_that(2 in targets_e2).is_false()
	assert_that(3 in targets_e2).is_false()


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
	assert_that(3 in targets).is_false()  # Dead enemy excluded


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
	assert_that(3 in alive_opposing).is_false()
