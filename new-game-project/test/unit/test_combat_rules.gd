class_name CombatRulesTest
extends GdUnitTestSuite

const PLAYER_ID := 1
const ENEMY_ID := 2
const PLAYER_SPECIES_ID := 101
const ENEMY_SPECIES_ID := 202


func test_attack_hit_event_carries_typed_payload() -> void:
	var event := CombatEvent.attack_hit(PLAYER_ID, ENEMY_ID, "Test Attack", 12, true)

	assert_int(event.kind).is_equal(CombatEvent.Kind.ATTACK_HIT)
	assert_int(event.actor_id).is_equal(PLAYER_ID)
	assert_int(event.target_id).is_equal(ENEMY_ID)
	assert_str(event.attack_name).is_equal("Test Attack")
	assert_int(event.damage).is_equal(12)
	assert_bool(event.critical).is_true()


func test_combatant_state_initializes_all_combat_properties() -> void:
	var combatant := CombatantState.new(PLAYER_ID, PLAYER_SPECIES_ID, 42, true)

	assert_int(combatant.id).is_equal(PLAYER_ID)
	assert_int(combatant.species_id).is_equal(PLAYER_SPECIES_ID)
	assert_int(combatant.max_hp).is_equal(42)
	assert_int(combatant.hp).is_equal(42)
	assert_bool(combatant.is_player).is_true()
	assert_bool(combatant.alive).is_true()
	assert_int(combatant.initiative).is_equal(0)


func test_roll_initiative_is_deterministic_for_same_seed_and_keeps_input_unchanged() -> void:
	var state := _build_state()
	seed(90210)
	var first := CombatRules.roll_initiative(state).state
	seed(90210)
	var second := CombatRules.roll_initiative(state).state

	assert_int(state.get_combatant(PLAYER_ID).initiative).is_equal(0)
	assert_int(state.get_combatant(ENEMY_ID).initiative).is_equal(0)
	assert_object(first).is_not_same(state)
	assert_int(first.get_combatant(PLAYER_ID).initiative).is_between(1, 20)
	assert_int(first.get_combatant(ENEMY_ID).initiative).is_between(1, 20)
	assert_int(first.get_combatant(PLAYER_ID).initiative).is_equal(second.get_combatant(PLAYER_ID).initiative)
	assert_int(first.get_combatant(ENEMY_ID).initiative).is_equal(second.get_combatant(ENEMY_ID).initiative)
	assert_array(first.turn_order_ids).contains_exactly_in_any_order(PLAYER_ID, ENEMY_ID)


func test_valid_attack_command_returns_attack_event_without_mutating_input() -> void:
	var state := _build_state()
	var result := CombatRules.resolve_action(state, ActionCommand.new(PLAYER_ID, "attack", ENEMY_ID, 0), _build_database())

	assert_int(result.events[0].kind).is_not_equal(CombatEvent.Kind.CANCELLED)
	assert_int(state.get_combatant(ENEMY_ID).hp).is_equal(30)
	assert_object(result.state).is_not_same(state)


func test_attack_command_with_dead_actor_is_cancelled() -> void:
	var state := _build_state()
	state.get_combatant(PLAYER_ID).alive = false
	var result := CombatRules.resolve_action(state, ActionCommand.new(PLAYER_ID, "attack", ENEMY_ID, 0), _build_database())

	_assert_cancelled(result, "actor_dead")


func test_attack_command_with_dead_target_is_cancelled() -> void:
	var state := _build_state()
	state.get_combatant(ENEMY_ID).alive = false
	var result := CombatRules.resolve_action(state, ActionCommand.new(PLAYER_ID, "attack", ENEMY_ID, 0), _build_database())

	_assert_cancelled(result, "target_dead", 2)
	assert_int(result.events[1].kind).is_equal(CombatEvent.Kind.COMBAT_ENDED)
	assert_bool(result.events[1].player_won).is_true()


func test_attack_command_rejects_ally_target() -> void:
	var state := _build_state()
	var ally := CombatantState.new(3, PLAYER_SPECIES_ID, 30, true)
	state.combatants[ally.id] = ally
	state.player_ids.append(ally.id)
	var result := CombatRules.resolve_action(state, ActionCommand.new(PLAYER_ID, "attack", ally.id, 0), _build_database())

	_assert_cancelled(result, "invalid_target_type")
	assert_int(result.state.get_combatant(ally.id).hp).is_equal(30)


func test_attack_command_without_available_attacks_is_cancelled() -> void:
	var state := _build_state()
	var database := _build_database(false)
	var result := CombatRules.resolve_action(state, ActionCommand.new(PLAYER_ID, "attack", ENEMY_ID, 0), database)

	_assert_cancelled(result, "invalid_attack")


func test_capture_command_rejects_ally_target() -> void:
	var state := _build_state()
	var result := CombatRules.resolve_action(state, ActionCommand.new(PLAYER_ID, "capture", PLAYER_ID), _build_database())

	_assert_cancelled(result, "invalid_target_type")


func test_item_command_rejects_enemy_target() -> void:
	var state := _build_state()
	var result := CombatRules.resolve_action(state, ActionCommand.new(PLAYER_ID, "item", ENEMY_ID), _build_database())

	_assert_cancelled(result, "invalid_target_type")


func test_end_round_emits_event_and_returns_new_state() -> void:
	var state := _build_state()
	var result := CombatRules.end_round(state)

	assert_int(state.round_number).is_equal(0)
	assert_int(result.state.round_number).is_equal(1)
	assert_int(result.events.size()).is_equal(1)
	assert_int(result.events[0].kind).is_equal(CombatEvent.Kind.ROUND_ENDED)
	assert_int(result.events[0].round_number).is_equal(1)


func test_transition_with_last_enemy_defeated_emits_combat_ended_after_action_event() -> void:
	var state := _build_state()
	state.get_combatant(ENEMY_ID).hp = 0
	state.get_combatant(ENEMY_ID).alive = false
	var result := CombatRules.resolve_action(state, ActionCommand.new(PLAYER_ID, "attack", ENEMY_ID, 0), _build_database())

	assert_int(result.events.size()).is_equal(2)
	assert_int(result.events[1].kind).is_equal(CombatEvent.Kind.COMBAT_ENDED)
	assert_bool(result.events[1].player_won).is_true()
	assert_bool(result.state.combat_over).is_true()




func _build_state() -> CombatState:
	var state := CombatState.new()
	var player := CombatantState.new(PLAYER_ID, PLAYER_SPECIES_ID, 30, true)
	var enemy := CombatantState.new(ENEMY_ID, ENEMY_SPECIES_ID, 30, false)
	state.combatants[player.id] = player
	state.combatants[enemy.id] = enemy
	state.player_ids.append(player.id)
	state.enemy_ids.append(enemy.id)
	return state


func _build_database(include_player_attack: bool = true) -> AlchemonDatabase:
	var database := AlchemonDatabase.new()
	var player_template := AlchemonSheet.new("Player", 30, true, PLAYER_SPECIES_ID)
	if include_player_attack:
		var attack := AttackData.new()
		attack.attack_name = "Test Attack"
		attack.damage = 5
		player_template.attacks.append(attack)
	var enemy_template := AlchemonSheet.new("Enemy", 30, false, ENEMY_SPECIES_ID)
	database.alchemons.append(player_template)
	database.alchemons.append(enemy_template)
	return database


func _assert_cancelled(result: TransitionResult, expected_reason: String, expected_event_count: int = 1) -> void:
	assert_int(result.events.size()).is_equal(expected_event_count)
	assert_int(result.events[0].kind).is_equal(CombatEvent.Kind.CANCELLED)
	assert_str(result.events[0].reason).is_equal(expected_reason)
