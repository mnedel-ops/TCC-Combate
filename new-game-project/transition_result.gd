class_name TransitionResult
extends RefCounted

## Resultado de uma transicao pura: snapshot novo e evento para UI/log.
var state: CombatState
var event: Dictionary


func _init(p_state: CombatState, p_event: Dictionary = {}) -> void:
	state = p_state
	event = p_event
