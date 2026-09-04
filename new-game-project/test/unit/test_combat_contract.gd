extends GdUnitTestSuite

## GdUnit4 test suite - selecao, resolucao, targeting invalido, fim de combate.

var database: AlchemonDatabase
var state: CombatState


func before_test() -> void:
	database = _build_database()
	state = CombatStateFactory.build(database, [0], [1])


func _build_database() -> AlchemonDatabase:
	var tackle := AttackData.new()
	tackle.attack_name = "Tackle"
	tackle.damage = 20

	var hero := AlchemonSheet.new("Hero", 30, true, 0)
	hero.attacks = [tackle]

	var slime := AlchemonSheet.new("Slime", 20, false, 1)
	slime.attacks = [tackle]

	var db := AlchemonDatabase.new()
	db.alchemons = [hero, slime]
	return db


func _player_id() -> int:
	return state.player_ids[0]


func _enemy_id() -> int:
	return state.enemy_ids[0]


# ---------------------------------------------------------------------------
# Selecao (queries de estado / targeting)
# ---------------------------------------------------------------------------

func test_alive_ids_excludes_dead_combatants() -> void:
	state.get_combatant(_enemy_id()).alive = false

	var alive := state.get_alive_ids(state.enemy_ids)

	assert_int(alive.size()).is_equal(0)


func test_valid_targets_only_include_opposing_alive_side() -> void:
	var targets := state.get_valid_targets(_player_id())

	assert_array(targets).is_equal([_enemy_id()])


func test_valid_targets_empty_when_actor_unknown() -> void:
	var targets := state.get_valid_targets(-999)

	assert_bool(targets.is_empty()).is_true()


# ---------------------------------------------------------------------------
# Resolucao (CombatRules.resolve_action -> CombatResult puro)
# ---------------------------------------------------------------------------

func test_attack_resolves_to_hit_or_miss_with_complete_data() -> void:
	seed(1)
	var command := ActionCommand.new(_player_id(), "attack", _enemy_id(), 0)

	var result := CombatRules.resolve_action(state, command, database)

	var is_hit_or_miss := result.outcome == CombatResult.Outcome.ATTACK_HIT \
		or result.outcome == CombatResult.Outcome.ATTACK_MISS
	assert_bool(is_hit_or_miss).is_true()
	assert_int(result.actor_id).is_equal(_player_id())
	assert_int(result.target_id).is_equal(_enemy_id())
	assert_str(result.attack_name).is_equal("Tackle")


func test_resolve_action_does_not_mutate_state() -> void:
	seed(2)
	var target := state.get_combatant(_enemy_id())
	var hp_before := target.hp
	var command := ActionCommand.new(_player_id(), "attack", _enemy_id(), 0)

	CombatRules.resolve_action(state, command, database)

	assert_int(target.hp).is_equal(hp_before)


func test_applier_applies_damage_and_frees_slot_on_death() -> void:
	var target := state.get_combatant(_enemy_id())
	target.hp = 5
	var slot := target.slot
	var result := CombatResult.attack_hit(_player_id(), _enemy_id(), "Tackle", 20, false)

	CombatResultApplier.apply(state, result)

	assert_int(target.hp).is_equal(0)
	assert_bool(target.alive).is_false()
	assert_int(state.battlefield.get_occupant(slot)).is_equal(-1)


func test_applier_item_heal_clamps_to_max_hp() -> void:
	var target := state.get_combatant(_player_id())
	target.hp = target.max_hp - 2
	var result := CombatResult.item_used(_player_id(), _player_id(), 6)

	CombatResultApplier.apply(state, result)

	assert_int(target.hp).is_equal(target.max_hp)


# ---------------------------------------------------------------------------
# Targeting invalido
# ---------------------------------------------------------------------------

func test_attack_on_dead_target_returns_already_dead() -> void:
	state.get_combatant(_enemy_id()).alive = false
	var command := ActionCommand.new(_player_id(), "attack", _enemy_id(), 0)

	var result := CombatRules.resolve_action(state, command, database)

	assert_int(result.outcome).is_equal(CombatResult.Outcome.ALREADY_DEAD)
	assert_bool(result.is_actionable()).is_false()


func test_attack_on_same_side_returns_invalid_target() -> void:
	var command := ActionCommand.new(_player_id(), "attack", _player_id(), 0)

	var result := CombatRules.resolve_action(state, command, database)

	assert_int(result.outcome).is_equal(CombatResult.Outcome.INVALID_TARGET)


func test_attack_with_bad_attack_index_returns_invalid_action() -> void:
	var command := ActionCommand.new(_player_id(), "attack", _enemy_id(), 99)

	var result := CombatRules.resolve_action(state, command, database)

	assert_int(result.outcome).is_equal(CombatResult.Outcome.INVALID_ACTION)


func test_dead_actor_cannot_act() -> void:
	state.get_combatant(_player_id()).alive = false
	var command := ActionCommand.new(_player_id(), "attack", _enemy_id(), 0)

	var result := CombatRules.resolve_action(state, command, database)

	assert_int(result.outcome).is_equal(CombatResult.Outcome.ALREADY_DEAD)


# ---------------------------------------------------------------------------
# Fim de combate
# ---------------------------------------------------------------------------

func test_combat_end_triggers_victory_when_all_enemies_dead() -> void:
	var result := CombatResult.attack_hit(_player_id(), _enemy_id(), "Tackle", 999, false)

	CombatResultApplier.apply(state, result)

	assert_bool(state.combat_over).is_true()
	assert_bool(state.player_won).is_true()
	assert_str(state.battle_phase.current_phase()).is_equal(BattlePhaseMachine.VICTORY)


func test_combat_end_triggers_defeat_when_all_players_dead() -> void:
	var result := CombatResult.attack_hit(_enemy_id(), _player_id(), "Tackle", 999, false)

	CombatResultApplier.apply(state, result)

	assert_bool(state.combat_over).is_true()
	assert_bool(state.player_won).is_false()
	assert_str(state.battle_phase.current_phase()).is_equal(BattlePhaseMachine.DEFEAT)


func test_capture_success_frees_slot_and_can_end_combat() -> void:
	var slot := state.get_combatant(_enemy_id()).slot
	var result := CombatResult.capture_success(_player_id(), _enemy_id())

	CombatResultApplier.apply(state, result)

	assert_bool(state.get_combatant(_enemy_id()).alive).is_false()
	assert_int(state.battlefield.get_occupant(slot)).is_equal(-1)
	assert_bool(state.combat_over).is_true()
	assert_bool(state.player_won).is_true()
