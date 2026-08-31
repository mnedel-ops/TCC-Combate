class_name CombatEvent
extends RefCounted

## Evento tipado emitido por uma transicao de combate. IDs, nunca referencias
## de objetos, mantem log, replay e UI desacoplados do estado mutavel.
enum Kind {
	INITIATIVE_ROLLED,
	ATTACK_HIT,
	ATTACK_MISS,
	ITEM_USED,
	CAPTURE_SUCCESS,
	CAPTURE_FAIL,
	CANCELLED,
	UNKNOWN_COMMAND,
	COMBAT_END_CHECKED,
	ROUND_ENDED,
	COMBAT_ENDED,
}

var kind: int = Kind.UNKNOWN_COMMAND
var actor_id: int = -1
var target_id: int = -1
var attack_name: String = ""
var damage: int = 0
var amount: int = 0
var critical: bool = false
var reason: String = ""
var round_number: int = 0
var player_won: bool = false


func _init(p_kind: int = Kind.UNKNOWN_COMMAND) -> void:
	kind = p_kind


static func initiative_rolled() -> CombatEvent:
	return CombatEvent.new(Kind.INITIATIVE_ROLLED)


static func attack_hit(p_actor_id: int, p_target_id: int, p_attack_name: String, p_damage: int, p_critical: bool) -> CombatEvent:
	var event := CombatEvent.new(Kind.ATTACK_HIT)
	event.actor_id = p_actor_id
	event.target_id = p_target_id
	event.attack_name = p_attack_name
	event.damage = p_damage
	event.critical = p_critical
	return event


static func attack_miss(p_actor_id: int, p_target_id: int, p_attack_name: String) -> CombatEvent:
	var event := CombatEvent.new(Kind.ATTACK_MISS)
	event.actor_id = p_actor_id
	event.target_id = p_target_id
	event.attack_name = p_attack_name
	return event


static func item_used(p_actor_id: int, p_target_id: int, p_amount: int) -> CombatEvent:
	var event := CombatEvent.new(Kind.ITEM_USED)
	event.actor_id = p_actor_id
	event.target_id = p_target_id
	event.amount = p_amount
	return event


static func capture_success(p_actor_id: int, p_target_id: int) -> CombatEvent:
	var event := CombatEvent.new(Kind.CAPTURE_SUCCESS)
	event.actor_id = p_actor_id
	event.target_id = p_target_id
	return event


static func capture_fail(p_actor_id: int, p_target_id: int) -> CombatEvent:
	var event := CombatEvent.new(Kind.CAPTURE_FAIL)
	event.actor_id = p_actor_id
	event.target_id = p_target_id
	return event


static func cancelled(p_reason: String, p_actor_id: int = -1) -> CombatEvent:
	var event := CombatEvent.new(Kind.CANCELLED)
	event.actor_id = p_actor_id
	event.reason = p_reason
	return event


static func unknown_command() -> CombatEvent:
	return CombatEvent.new(Kind.UNKNOWN_COMMAND)


static func combat_end_checked() -> CombatEvent:
	return CombatEvent.new(Kind.COMBAT_END_CHECKED)


static func round_ended(p_round_number: int) -> CombatEvent:
	var event := CombatEvent.new(Kind.ROUND_ENDED)
	event.round_number = p_round_number
	return event


static func combat_ended(p_player_won: bool) -> CombatEvent:
	var event := CombatEvent.new(Kind.COMBAT_ENDED)
	event.player_won = p_player_won
	return event
