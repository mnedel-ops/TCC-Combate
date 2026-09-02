class_name BattlePhaseMachine
extends RefCounted

const ENCOUNTER_START := "encounter_start"
const SELECTING_ACTIONS := "selecting_actions"
const RESOLVING_ACTIONS := "resolving_actions"
const END_OF_ROUND := "end_of_round"
const COMBAT_OVER := "combat_over"
const VICTORY := "victory"
const DEFEAT := "defeat"

var _current_phase: String


func _init(start_phase: String = ENCOUNTER_START) -> void:
	_current_phase = start_phase


func current_phase() -> String:
	return _current_phase


static func is_terminal_phase(phase: String) -> bool:
	return phase == VICTORY or phase == DEFEAT


static func is_valid_transition(from_phase: String, to_phase: String) -> bool:
	if is_terminal_phase(from_phase):
		return false

	match from_phase:
		ENCOUNTER_START:
			return to_phase == SELECTING_ACTIONS
		SELECTING_ACTIONS:
			return to_phase == RESOLVING_ACTIONS
		RESOLVING_ACTIONS:
			return to_phase == END_OF_ROUND or to_phase == COMBAT_OVER
		END_OF_ROUND:
			return to_phase == SELECTING_ACTIONS or to_phase == COMBAT_OVER
		COMBAT_OVER:
			return to_phase == VICTORY or to_phase == DEFEAT
		_:
			return false


func transition(next_phase: String) -> bool:
	if not is_valid_transition(_current_phase, next_phase):
		return false
	_current_phase = next_phase
	return true


func is_terminal() -> bool:
	return is_terminal_phase(_current_phase)
