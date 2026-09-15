extends GdUnitTestSuite

## CombatRules pure logic: parallel command readiness, crit damage math,
## dead-target auto-retarget, valence-electron Slap fallback. No scene
## tree needed - CombatState is plain data (Resource).

var state: CombatState
var database: AlchemonDatabase


func before_test() -> void:
	state = CombatState.new()

	var cheap_attack := AttackData.new()
	cheap_attack.attack_name = "Cheap"
	cheap_attack.damage = 10
	cheap_attack.energy_cost = 2

	var pricey_attack := AttackData.new()
	pricey_attack.attack_name = "Pricey"
	pricey_attack.damage = 999
	pricey_attack.energy_cost = 100

	var species := AlchemonSheet.new("Species0", 30, false, 0)
	species.attacks = [cheap_attack, pricey_attack]

	database = AlchemonDatabase.new()
	database.alchemons = [species]

	var p1 := CombatantState.new(0, 0, 30, true, BattlefieldSlot.PLAYER_SLOT_1, 10)
	var p2 := CombatantState.new(1, 0, 30, true, BattlefieldSlot.PLAYER_SLOT_2, 10)
	var e1 := CombatantState.new(2, 0, 30, false, BattlefieldSlot.ENEMY_SLOT_1, 10)
	var e2 := CombatantState.new(3, 0, 30, false, BattlefieldSlot.ENEMY_SLOT_2, 10)

	for c in [p1, p2, e1, e2]:
		state.combatants[c.id] = c

	state.player_ids = [p1.id, p2.id]
	state.enemy_ids = [e1.id, e2.id]

	BattlefieldRules.assign_combatant(state.battlefield, p1.id, p1.slot)
	BattlefieldRules.assign_combatant(state.battlefield, p2.id, p2.slot)
	BattlefieldRules.assign_combatant(state.battlefield, e1.id, e1.slot)
	BattlefieldRules.assign_combatant(state.battlefield, e2.id, e2.slot)


## --- Parallel command collection ---

func test_has_all_commands_false_when_missing() -> void:
	state.pending_actions.append(ActionCommand.new(0, "attack", 2, 0))
	assert_bool(CombatRules.has_all_commands(state)) \
		.override_failure_message("1 of 4 alive actors queued, should not be ready") \
		.is_false()


func test_has_all_commands_true_when_all_present() -> void:
	state.pending_actions.append(ActionCommand.new(0, "attack", 2, 0))
	state.pending_actions.append(ActionCommand.new(1, "attack", 2, 0))
	state.pending_actions.append(ActionCommand.new(2, "attack", 0, 0))
	state.pending_actions.append(ActionCommand.new(3, "attack", 0, 0))
	assert_bool(CombatRules.has_all_commands(state)) \
		.override_failure_message("all 4 alive actors queued, should be ready") \
		.is_true()


func test_has_all_commands_ignores_dead_actors() -> void:
	state.get_combatant(1).alive = false
	state.pending_actions.append(ActionCommand.new(0, "attack", 2, 0))
	state.pending_actions.append(ActionCommand.new(2, "attack", 0, 0))
	state.pending_actions.append(ActionCommand.new(3, "attack", 0, 0))
	assert_bool(CombatRules.has_all_commands(state)) \
		.override_failure_message("dead player 1 should not be required") \
		.is_true()


func test_required_actor_ids_only_alive() -> void:
	state.get_combatant(3).alive = false
	var required := CombatRules.get_required_actor_ids(state)
	assert_int(required.size()).is_equal(3)
	assert_bool(3 in required).is_false()


## --- Crit damage (pure, no RNG) ---

func test_compute_damage_no_crit() -> void:
	assert_int(CombatRules.compute_damage(10, false)).is_equal(10)


func test_compute_damage_crit_applies_multiplier() -> void:
	assert_int(CombatRules.compute_damage(10, true)).is_equal(15)


## --- Dead target auto-retarget ---

func test_attack_retargets_to_other_enemy_when_target_already_dead() -> void:
	state.get_combatant(2).alive = false
	BattlefieldRules.free_slot(state.battlefield, BattlefieldSlot.ENEMY_SLOT_1)

	var command := ActionCommand.new(0, "attack", 2, 0)
	var target_id := CombatRules._retarget_if_dead(state, command)

	assert_int(command.target_id) \
		.override_failure_message("should swap to the remaining alive enemy") \
		.is_equal(2)
	assert_int(target_id).is_equal(3)


func test_item_retargets_to_other_ally_when_target_already_dead() -> void:
	state.get_combatant(1).alive = false
	BattlefieldRules.free_slot(state.battlefield, BattlefieldSlot.PLAYER_SLOT_2)

	var command := ActionCommand.new(0, "item", 1, -1)
	var target_id := CombatRules._retarget_if_dead(state, command)

	assert_int(command.target_id) \
		.override_failure_message("should swap to the remaining alive ally") \
		.is_equal(1)
	assert_int(target_id).is_equal(0)


func test_retarget_noop_when_target_still_alive() -> void:
	var command := ActionCommand.new(0, "attack", 2, 0)
	var target_id := CombatRules._retarget_if_dead(state, command)
	assert_int(command.target_id) \
		.override_failure_message("target already alive, no retarget needed") \
		.is_equal(2)
	assert_int(target_id).is_equal(2)


func test_retarget_gives_up_when_whole_side_dead() -> void:
	state.get_combatant(2).alive = false
	state.get_combatant(3).alive = false

	var command := ActionCommand.new(0, "attack", 2, 0)
	var target_id := CombatRules._retarget_if_dead(state, command)

	assert_int(command.target_id) \
		.override_failure_message("no alive replacement exists, target_id left as-is for cancel path") \
		.is_equal(2)
	assert_int(target_id).is_equal(2)


## --- Valence electron / energy, Slap fallback ---

func test_resolve_attack_deducts_energy_cost_when_affordable() -> void:
	var command := ActionCommand.new(0, "attack", 2, 0)   # p1 uses Cheap (cost 2) on e1
	var result := CombatRules.resolve_action(state, command, database)
	CombatResultApplier.apply(state, result, database)
	assert_int(state.get_combatant(0).valence_electrons) \
		.override_failure_message("10 - 2 cost = 8 left") \
		.is_equal(8)


func test_resolve_attack_forced_slap_when_zero_energy() -> void:
	state.get_combatant(0).valence_electrons = 0
	var command := ActionCommand.new(0, "attack", 2, 1)   # p1 targets e1, picks Pricey (dmg 999), but has 0 electrons

	var event: CombatResult = CombatRules.resolve_action(state, command, database)

	var resolved_as_attack: bool = event.outcome == CombatResult.Outcome.ATTACK_HIT or event.outcome == CombatResult.Outcome.ATTACK_MISS
	assert_bool(resolved_as_attack) \
		.override_failure_message("still resolves as an attack, never cancelled") \
		.is_true()
	assert_str(event.attack_name) \
		.override_failure_message("forced to Slap regardless of chosen attack") \
		.is_equal(CombatRules.SLAP_NAME)
	if event.outcome == CombatResult.Outcome.ATTACK_HIT:
		var plausible_damage: bool = event.damage == 10 or event.damage == 15
		assert_bool(plausible_damage) \
			.override_failure_message("Slap base 10, or 15 on crit") \
			.is_true()


func test_slap_costs_nothing_and_stays_at_zero() -> void:
	state.get_combatant(0).valence_electrons = 0
	var command := ActionCommand.new(0, "attack", 2, 1)
	var result := CombatRules.resolve_action(state, command, database)
	CombatResultApplier.apply(state, result, database)
	assert_int(state.get_combatant(0).valence_electrons) \
		.override_failure_message("Slap is free, stays clamped at 0") \
		.is_equal(0)


func test_pick_random_attack_index_within_range() -> void:
	for i in 20:
		var index := CombatRules.pick_random_attack_index(database, 0)
		var in_range: bool = index == 0 or index == 1
		assert_bool(in_range) \
			.override_failure_message("should pick a valid attack index regardless of energy") \
			.is_true()
