class_name CombatResult
extends RefCounted

## Contrato unico de resolucao de combate. Retornado por CombatRules,
## consumido por CombatResultApplier (mutacao) e CombatEvent (UI).
##
## Garantias:
## - Imutavel: todos os campos setados em _init, nunca alterados depois.
##   Sempre construir via os metodos estaticos de fabrica abaixo.
## - Completo: dados suficientes pra UI renderizar o resultado sem tocar
##   em CombatState.
## - Validado: acoes invalidas retornam INVALID_TARGET / ALREADY_DEAD /
##   INVALID_ACTION em vez de crashar ou mutar estado.
## - Sem estado: guarda so IDs (int) e valores primitivos, nunca
##   referencias pra CombatantState ou outro objeto mutavel.

enum Outcome {
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

var outcome: int
var actor_id: int
var target_id: int
var attack_name: String
var damage: int
var amount: int
var critical: bool
var reason: String


func _init(
	p_outcome: int,
	p_actor_id: int = -1,
	p_target_id: int = -1,
	p_attack_name: String = "",
	p_damage: int = 0,
	p_amount: int = 0,
	p_critical: bool = false,
	p_reason: String = ""
) -> void:
	outcome = p_outcome
	actor_id = p_actor_id
	target_id = p_target_id
	attack_name = p_attack_name
	damage = p_damage
	amount = p_amount
	critical = p_critical
	reason = p_reason


static func attack_hit(actor_id: int, target_id: int, attack_name: String, damage: int, critical: bool) -> CombatResult:
	return CombatResult.new(Outcome.ATTACK_HIT, actor_id, target_id, attack_name, damage, 0, critical)


static func attack_miss(actor_id: int, target_id: int, attack_name: String) -> CombatResult:
	return CombatResult.new(Outcome.ATTACK_MISS, actor_id, target_id, attack_name)


static func item_used(actor_id: int, target_id: int, amount: int) -> CombatResult:
	return CombatResult.new(Outcome.ITEM_USED, actor_id, target_id, "", 0, amount)


static func capture_success(actor_id: int, target_id: int) -> CombatResult:
	return CombatResult.new(Outcome.CAPTURE_SUCCESS, actor_id, target_id)


static func capture_fail(actor_id: int, target_id: int) -> CombatResult:
	return CombatResult.new(Outcome.CAPTURE_FAIL, actor_id, target_id)


static func flee_success() -> CombatResult:
	return CombatResult.new(Outcome.FLEE_SUCCESS)


static func flee_fail() -> CombatResult:
	return CombatResult.new(Outcome.FLEE_FAIL)


static func invalid_target(actor_id: int, target_id: int, reason: String = "invalid_target") -> CombatResult:
	return CombatResult.new(Outcome.INVALID_TARGET, actor_id, target_id, "", 0, 0, false, reason)


static func already_dead(actor_id: int, target_id: int, reason: String = "target_dead") -> CombatResult:
	return CombatResult.new(Outcome.ALREADY_DEAD, actor_id, target_id, "", 0, 0, false, reason)


static func invalid_action(actor_id: int, target_id: int, reason: String = "invalid_action") -> CombatResult:
	return CombatResult.new(Outcome.INVALID_ACTION, actor_id, target_id, "", 0, 0, false, reason)


## True quando o resultado representa uma acao que de fato aconteceu -
## nao foi rejeitada por validacao (target morto/invalido/acao invalida).
func is_actionable() -> bool:
	return outcome != Outcome.INVALID_TARGET \
		and outcome != Outcome.ALREADY_DEAD \
		and outcome != Outcome.INVALID_ACTION
