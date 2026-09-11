extends GutTest

## Tests CombatRules pure logic: parallel command readiness, crit damage
## math, and dead-target auto-retarget. No scene tree needed - CombatState
## is plain data (Resource), matching the data-oriented design of the file.

var state: CombatState
var database: AlchemonDatabase


func before_each() -> void:
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
	assert_false(CombatRules.has_all_commands(state), "1 of 4 alive actors queued, should not be ready")


func test_has_all_commands_true_when_all_present() -> void:
	state.pending_actions.append(ActionCommand.new(0, "attack", 2, 0))
	state.pending_actions.append(ActionCommand.new(1, "attack", 2, 0))
	state.pending_actions.append(ActionCommand.new(2, "attack", 0, 0))
	state.pending_actions.append(ActionCommand.new(3, "attack", 0, 0))
	assert_true(CombatRules.has_all_commands(state), "all 4 alive actors queued, should be ready")


func test_has_all_commands_ignores_dead_actors() -> void:
	state.get_combatant(1).alive = false
	state.pending_actions.append(ActionCommand.new(0, "attack", 2, 0))
	state.pending_actions.append(ActionCommand.new(2, "attack", 0, 0))
	state.pending_actions.append(ActionCommand.new(3, "attack", 0, 0))
	assert_true(CombatRules.has_all_commands(state), "dead player 1 should not be required")


func test_required_actor_ids_only_alive() -> void:
	state.get_combatant(3).alive = false
	var required := CombatRules.get_required_actor_ids(state)
	assert_eq(required.size(), 3)
	assert_false(3 in required)


## --- Crit damage (pure, no RNG) ---

func test_compute_damage_no_crit() -> void:
	assert_eq(CombatRules.compute_damage(10, false), 10)


func test_compute_damage_crit_applies_multiplier() -> void:
	assert_eq(CombatRules.compute_damage(10, true), 15)


## --- Dead target auto-retarget ---

func test_attack_retargets_to_other_enemy_when_target_already_dead() -> void:
	state.get_combatant(2).alive = false
	BattlefieldRules.free_slot(state.battlefield, BattlefieldSlot.ENEMY_SLOT_1)

	var command := ActionCommand.new(0, "attack", 2, 0)
	CombatRules._retarget_if_dead(state, command)

	assert_eq(command.target_id, 3, "should swap to the remaining alive enemy")


func test_item_retargets_to_other_ally_when_target_already_dead() -> void:
	state.get_combatant(1).alive = false
	BattlefieldRules.free_slot(state.battlefield, BattlefieldSlot.PLAYER_SLOT_2)

	var command := ActionCommand.new(0, "item", 1, -1)
	CombatRules._retarget_if_dead(state, command)

	assert_eq(command.target_id, 0, "should swap to the remaining alive ally")


func test_retarget_noop_when_target_still_alive() -> void:
	var command := ActionCommand.new(0, "attack", 2, 0)
	CombatRules._retarget_if_dead(state, command)
	assert_eq(command.target_id, 2, "target already alive, no retarget needed")


func test_retarget_gives_up_when_whole_side_dead() -> void:
	state.get_combatant(2).alive = false
	state.get_combatant(3).alive = false

	var command := ActionCommand.new(0, "attack", 2, 0)
	CombatRules._retarget_if_dead(state, command)

	assert_eq(command.target_id, 2, "no alive replacement exists, target_id left as-is for cancel path")


## --- Valence electron / energy, Slap fallback ---

func test_resolve_attack_deducts_energy_cost_when_affordable() -> void:
	var command := ActionCommand.new(0, "attack", 2, 0)   # p1 uses Cheap (cost 2) on e1
	CombatRules.resolve_action(state, command, database)
	assert_eq(state.get_combatant(0).valence_electrons, 8, "10 - 2 cost = 8 left")


func test_resolve_attack_forced_slap_when_zero_energy() -> void:
	state.get_combatant(0).valence_electrons = 0
	var command := ActionCommand.new(0, "attack", 2, 1)   # p1 targets e1, picks Pricey (dmg 999), but has 0 electrons

	var event := CombatRules.resolve_action(state, command, database)

	assert_true(event.kind == "attack_hit" or event.kind == "attack_miss", "still resolves as an attack, never cancelled")
	assert_eq(event.attack_name, CombatRules.SLAP_NAME, "forced to Slap regardless of chosen attack")
	if event.kind == "attack_hit":
		assert_true(event.damage == 10 or event.damage == 15, "Slap base 10, or 15 on crit")


func test_slap_costs_nothing_and_stays_at_zero() -> void:
	state.get_combatant(0).valence_electrons = 0
	var command := ActionCommand.new(0, "attack", 2, 1)
	CombatRules.resolve_action(state, command, database)
	assert_eq(state.get_combatant(0).valence_electrons, 0, "Slap is free, stays clamped at 0")


func test_pick_random_attack_index_within_range() -> void:
	for i in 20:
		var index := CombatRules.pick_random_attack_index(database, 0)
		assert_true(index == 0 or index == 1, "should pick a valid attack index regardless of energy")

