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

static func apply(state: CombatState, result: CombatResult) -> void:
	match result.outcome:
		CombatResult.Outcome.ATTACK_HIT:
			_apply_damage(state, result.target_id, result.damage)
		CombatResult.Outcome.ITEM_USED:
			_apply_heal(state, result.target_id, result.amount)
		CombatResult.Outcome.CAPTURE_SUCCESS:
			_apply_capture(state, result.target_id)
		_:
			pass # ATTACK_MISS, CAPTURE_FAIL, FLEE_*, INVALID_*, ALREADY_DEAD: nada pra mutar

	CombatRules.check_combat_end(state)


static func _apply_damage(state: CombatState, target_id: int, damage: int) -> void:
	var target := state.get_combatant(target_id)
	if target == null or not target.alive:
		return
	target.hp = max(target.hp - damage, 0)
	if target.hp == 0:
		_kill(state, target)


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
