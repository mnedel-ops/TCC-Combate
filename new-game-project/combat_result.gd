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
var temperature_delta: int  # ΔT (K) causado pelo golpe - so != 0 em ATTACK_HIT
var effectiveness: float    # multiplicador de tipo (GDD 6) - so relevante em ATTACK_HIT; 1.0 (neutro) em todo o resto
var energy_cost: int


func _init(
	p_outcome: int,
	p_actor_id: int = -1,
	p_target_id: int = -1,
	p_attack_name: String = "",
	p_damage: int = 0,
	p_amount: int = 0,
	p_critical: bool = false,
	p_reason: String = "",
	p_temperature_delta: int = 0,
	p_effectiveness: float = 1.0,
	p_energy_cost: int = 0
) -> void:
	outcome = p_outcome
	actor_id = p_actor_id
	target_id = p_target_id
	attack_name = p_attack_name
	damage = p_damage
	amount = p_amount
	critical = p_critical
	reason = p_reason
	temperature_delta = p_temperature_delta
	effectiveness = p_effectiveness
	energy_cost = p_energy_cost


static func attack_hit(p_actor_id: int, p_target_id: int, p_attack_name: String, p_damage: int, p_critical: bool, p_temperature_delta: int = 0, p_effectiveness: float = 1.0, p_energy_cost: int = 0) -> CombatResult:
	return CombatResult.new(Outcome.ATTACK_HIT, p_actor_id, p_target_id, p_attack_name, p_damage, 0, p_critical, "", p_temperature_delta, p_effectiveness, p_energy_cost)


static func attack_miss(p_actor_id: int, p_target_id: int, p_attack_name: String, p_energy_cost: int = 0) -> CombatResult:
	return CombatResult.new(Outcome.ATTACK_MISS, p_actor_id, p_target_id, p_attack_name, 0, 0, false, "", 0, 1.0, p_energy_cost)


static func item_used(p_actor_id: int, p_target_id: int, p_amount: int) -> CombatResult:
	return CombatResult.new(Outcome.ITEM_USED, p_actor_id, p_target_id, "", 0, p_amount)


static func capture_success(p_actor_id: int, p_target_id: int) -> CombatResult:
	return CombatResult.new(Outcome.CAPTURE_SUCCESS, p_actor_id, p_target_id)


static func capture_fail(p_actor_id: int, p_target_id: int) -> CombatResult:
	return CombatResult.new(Outcome.CAPTURE_FAIL, p_actor_id, p_target_id)


static func flee_success() -> CombatResult:
	return CombatResult.new(Outcome.FLEE_SUCCESS)


static func flee_fail() -> CombatResult:
	return CombatResult.new(Outcome.FLEE_FAIL)


static func invalid_target(p_actor_id: int, p_target_id: int, p_reason: String = "invalid_target") -> CombatResult:
	return CombatResult.new(Outcome.INVALID_TARGET, p_actor_id, p_target_id, "", 0, 0, false, p_reason)


static func already_dead(p_actor_id: int, p_target_id: int, p_reason: String = "target_dead") -> CombatResult:
	return CombatResult.new(Outcome.ALREADY_DEAD, p_actor_id, p_target_id, "", 0, 0, false, p_reason)


static func invalid_action(p_actor_id: int, p_target_id: int, p_reason: String = "invalid_action") -> CombatResult:
	return CombatResult.new(Outcome.INVALID_ACTION, p_actor_id, p_target_id, "", 0, 0, false, p_reason)


## True quando o resultado representa uma acao que de fato aconteceu -
## nao foi rejeitada por validacao (target morto/invalido/acao invalida).
func is_actionable() -> bool:
	return outcome != Outcome.INVALID_TARGET \
		and outcome != Outcome.ALREADY_DEAD \
		and outcome != Outcome.INVALID_ACTION
