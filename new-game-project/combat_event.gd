class_name CombatEvent
extends RefCounted

## Evento de UI derivado de um CombatResult. Guarda so IDs, nunca
## referencias de objeto - log, replay e UI ficam desacoplados do
## CombatState mutavel. Kind espelha CombatResult.Outcome 1:1.

enum Kind {
	ATTACK_HIT,
	ATTACK_MISS,
	ITEM_USED,
	CAPTURE_SUCCESS,
	CAPTURE_FAIL,
	FLEE_SUCCESS,
	FLEE_FAIL,
	INVALID_TARGET,
	ALREADY_DEAD,
	INVALID_ACTION,
}

const _KIND_FROM_OUTCOME := {
	CombatResult.Outcome.ATTACK_HIT: Kind.ATTACK_HIT,
	CombatResult.Outcome.ATTACK_MISS: Kind.ATTACK_MISS,
	CombatResult.Outcome.ITEM_USED: Kind.ITEM_USED,
	CombatResult.Outcome.CAPTURE_SUCCESS: Kind.CAPTURE_SUCCESS,
	CombatResult.Outcome.CAPTURE_FAIL: Kind.CAPTURE_FAIL,
	CombatResult.Outcome.FLEE_SUCCESS: Kind.FLEE_SUCCESS,
	CombatResult.Outcome.FLEE_FAIL: Kind.FLEE_FAIL,
	CombatResult.Outcome.INVALID_TARGET: Kind.INVALID_TARGET,
	CombatResult.Outcome.ALREADY_DEAD: Kind.ALREADY_DEAD,
	CombatResult.Outcome.INVALID_ACTION: Kind.INVALID_ACTION,
}

var kind: int
var actor_id: int
var target_id: int
var attack_name: String
var damage: int
var amount: int
var critical: bool
var reason: String


func _init(
	p_kind: int,
	p_actor_id: int = -1,
	p_target_id: int = -1,
	p_attack_name: String = "",
	p_damage: int = 0,
	p_amount: int = 0,
	p_critical: bool = false,
	p_reason: String = ""
) -> void:
	kind = p_kind
	actor_id = p_actor_id
	target_id = p_target_id
	attack_name = p_attack_name
	damage = p_damage
	amount = p_amount
	critical = p_critical
	reason = p_reason


## Fabrica unica pra virar evento de UI a partir de um CombatResult.
static func from_result(result: CombatResult) -> CombatEvent:
	return CombatEvent.new(
		_KIND_FROM_OUTCOME[result.outcome],
		result.actor_id,
		result.target_id,
		result.attack_name,
		result.damage,
		result.amount,
		result.critical,
		result.reason
	)
