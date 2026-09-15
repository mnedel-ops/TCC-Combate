class_name CombatResultApplier
extends RefCounted

## Unico lugar que muta CombatState a partir de um CombatResult.
## CombatRules so calcula (puro); aqui e onde o resultado vira mudanca
## real de HP, morte e ocupacao de slot. Chamado pelo controller depois
## de cada CombatRules.resolve_action() / resolve_flee().
##
## Garante:
## - State Consistency: HP e alive setados de forma coerente com o resultado.
## - Death Handling: libera o slot no battlefield quando alguem morre.
## - Victory Check: roda CombatRules.check_combat_end() apos toda aplicacao.
## - Leveling: quem derruba ou captura um alvo ganha a XP daquela especie
##   (AlchemonSheet.xp_reward), podendo disparar level up (AlchemonGrowth).
## - Temperatura: todo golpe que acerta aquece a arena compartilhada
##   (CombatState.temperature) pelo CombatResult.temperature_delta.

static func apply(state: CombatState, result: CombatResult, database: AlchemonDatabase) -> void:
	match result.outcome:
		CombatResult.Outcome.ATTACK_HIT:
			_apply_energy_cost(state, result.actor_id, result.energy_cost)
			state.temperature += result.temperature_delta
			var died := _apply_damage(state, result.target_id, result.damage)
			if died:
				_grant_xp(state, database, result.actor_id, result.target_id)
		CombatResult.Outcome.ITEM_USED:
			_apply_heal(state, result.target_id, result.amount)
		CombatResult.Outcome.ATTACK_MISS:
			_apply_energy_cost(state, result.actor_id, result.energy_cost)
		CombatResult.Outcome.CAPTURE_SUCCESS:
			_apply_capture(state, result.target_id)
			_grant_xp(state, database, result.actor_id, result.target_id)
		_:
			pass # ATTACK_MISS, CAPTURE_FAIL, FLEE_*, INVALID_*, ALREADY_DEAD: nada pra mutar

	CombatRules.check_combat_end(state)


static func _apply_energy_cost(state: CombatState, actor_id: int, cost: int) -> void:
	var actor := state.get_combatant(actor_id)
	if actor != null:
		actor.valence_electrons = maxi(actor.valence_electrons - cost, 0)


## Retorna true se este dano especifico matou o alvo (pra so conceder XP
## uma vez, na hora certa, e nao em todo golpe).
static func _apply_damage(state: CombatState, target_id: int, damage: int) -> bool:
	var target := state.get_combatant(target_id)
	if target == null or not target.alive:
		return false
	target.hp = maxi(target.hp - damage, 0)
	if target.hp == 0:
		_kill(state, target)
		return true
	return false


static func _apply_heal(state: CombatState, target_id: int, amount: int) -> void:
	var target := state.get_combatant(target_id)
	if target == null or not target.alive:
		return
	target.hp = mini(target.hp + amount, target.max_hp)


static func _apply_capture(state: CombatState, target_id: int) -> void:
	var target := state.get_combatant(target_id)
	if target == null or not target.alive:
		return
	target.hp = 0
	_kill(state, target)


static func _kill(state: CombatState, target: CombatantState) -> void:
	target.alive = false
	state.battlefield.free_slot(target.slot)


static func _grant_xp(state: CombatState, database: AlchemonDatabase, actor_id: int, defeated_id: int) -> void:
	var actor := state.get_combatant(actor_id)
	if actor == null or not actor.alive:
		return

	var defeated := state.get_combatant(defeated_id)
	if defeated == null:
		return

	var defeated_template := database.get_by_id(defeated.species_id)
	var actor_template := database.get_by_id(actor.species_id)
	if defeated_template == null or actor_template == null:
		return

	AlchemonGrowth.grant_experience(actor, actor_template, defeated_template.xp_reward)
