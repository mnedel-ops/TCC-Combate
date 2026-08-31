class_name TransitionResult
extends RefCounted

## Resultado de uma transicao pura: snapshot novo e eventos ordenados para UI/log.
var state: CombatState
var events: Array[CombatEvent]


func _init(p_state: CombatState, p_events: Array[CombatEvent]) -> void:
	state = p_state
	events = p_events
