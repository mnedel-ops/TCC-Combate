extends GdUnitTestSuite

## BattlePhaseRules delegates to BattlePhaseMachine's static FSM table.
## These tests pin the full transition graph so the two never silently
## drift apart again (same failure mode that just hit BattlefieldRules).

func test_constants_match_battle_phase_machine() -> void:
	assert_str(BattlePhaseRules.ENCOUNTER_START).is_equal(BattlePhaseMachine.ENCOUNTER_START)
	assert_str(BattlePhaseRules.SELECTING_ACTIONS).is_equal(BattlePhaseMachine.SELECTING_ACTIONS)
	assert_str(BattlePhaseRules.RESOLVING_ACTIONS).is_equal(BattlePhaseMachine.RESOLVING_ACTIONS)
	assert_str(BattlePhaseRules.END_OF_ROUND).is_equal(BattlePhaseMachine.END_OF_ROUND)
	assert_str(BattlePhaseRules.COMBAT_OVER).is_equal(BattlePhaseMachine.COMBAT_OVER)
	assert_str(BattlePhaseRules.VICTORY).is_equal(BattlePhaseMachine.VICTORY)
	assert_str(BattlePhaseRules.DEFEAT).is_equal(BattlePhaseMachine.DEFEAT)


func test_is_terminal_phase_true_for_victory_and_defeat() -> void:
	assert_bool(BattlePhaseRules.is_terminal_phase(BattlePhaseRules.VICTORY)).is_true()
	assert_bool(BattlePhaseRules.is_terminal_phase(BattlePhaseRules.DEFEAT)).is_true()


func test_is_terminal_phase_false_for_non_terminal_phases() -> void:
	assert_bool(BattlePhaseRules.is_terminal_phase(BattlePhaseRules.ENCOUNTER_START)).is_false()
	assert_bool(BattlePhaseRules.is_terminal_phase(BattlePhaseRules.SELECTING_ACTIONS)).is_false()
	assert_bool(BattlePhaseRules.is_terminal_phase(BattlePhaseRules.RESOLVING_ACTIONS)).is_false()
	assert_bool(BattlePhaseRules.is_terminal_phase(BattlePhaseRules.END_OF_ROUND)).is_false()
	assert_bool(BattlePhaseRules.is_terminal_phase(BattlePhaseRules.COMBAT_OVER)).is_false()


func test_encounter_start_only_advances_to_selecting_actions() -> void:
	assert_bool(BattlePhaseRules.is_valid_transition(BattlePhaseRules.ENCOUNTER_START, BattlePhaseRules.SELECTING_ACTIONS)).is_true()
	assert_bool(BattlePhaseRules.is_valid_transition(BattlePhaseRules.ENCOUNTER_START, BattlePhaseRules.RESOLVING_ACTIONS)).is_false()
	assert_bool(BattlePhaseRules.is_valid_transition(BattlePhaseRules.ENCOUNTER_START, BattlePhaseRules.COMBAT_OVER)).is_false()


func test_selecting_actions_only_advances_to_resolving_actions() -> void:
	assert_bool(BattlePhaseRules.is_valid_transition(BattlePhaseRules.SELECTING_ACTIONS, BattlePhaseRules.RESOLVING_ACTIONS)).is_true()
	assert_bool(BattlePhaseRules.is_valid_transition(BattlePhaseRules.SELECTING_ACTIONS, BattlePhaseRules.END_OF_ROUND)).is_false()


func test_resolving_actions_advances_to_end_of_round_or_combat_over() -> void:
	assert_bool(BattlePhaseRules.is_valid_transition(BattlePhaseRules.RESOLVING_ACTIONS, BattlePhaseRules.END_OF_ROUND)).is_true()
	assert_bool(BattlePhaseRules.is_valid_transition(BattlePhaseRules.RESOLVING_ACTIONS, BattlePhaseRules.COMBAT_OVER)).is_true()
	assert_bool(BattlePhaseRules.is_valid_transition(BattlePhaseRules.RESOLVING_ACTIONS, BattlePhaseRules.SELECTING_ACTIONS)).is_false()


func test_end_of_round_advances_to_selecting_actions_or_combat_over() -> void:
	assert_bool(BattlePhaseRules.is_valid_transition(BattlePhaseRules.END_OF_ROUND, BattlePhaseRules.SELECTING_ACTIONS)).is_true()
	assert_bool(BattlePhaseRules.is_valid_transition(BattlePhaseRules.END_OF_ROUND, BattlePhaseRules.COMBAT_OVER)).is_true()
	assert_bool(BattlePhaseRules.is_valid_transition(BattlePhaseRules.END_OF_ROUND, BattlePhaseRules.RESOLVING_ACTIONS)).is_false()


func test_combat_over_advances_to_victory_or_defeat() -> void:
	assert_bool(BattlePhaseRules.is_valid_transition(BattlePhaseRules.COMBAT_OVER, BattlePhaseRules.VICTORY)).is_true()
	assert_bool(BattlePhaseRules.is_valid_transition(BattlePhaseRules.COMBAT_OVER, BattlePhaseRules.DEFEAT)).is_true()
	assert_bool(BattlePhaseRules.is_valid_transition(BattlePhaseRules.COMBAT_OVER, BattlePhaseRules.SELECTING_ACTIONS)).is_false()


func test_terminal_phases_reject_every_transition() -> void:
	assert_bool(BattlePhaseRules.is_valid_transition(BattlePhaseRules.VICTORY, BattlePhaseRules.SELECTING_ACTIONS)).is_false()
	assert_bool(BattlePhaseRules.is_valid_transition(BattlePhaseRules.DEFEAT, BattlePhaseRules.SELECTING_ACTIONS)).is_false()
	assert_bool(BattlePhaseRules.is_valid_transition(BattlePhaseRules.VICTORY, BattlePhaseRules.DEFEAT)) \
		.override_failure_message("victory can't flip to defeat, terminal is terminal") \
		.is_false()
