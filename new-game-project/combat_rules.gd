class_name CombatRules
extends RefCounted

## Motor de regras puro. So calcula CombatResult a partir de
## CombatState + ActionCommand + AlchemonDatabase - nunca muta combatentes.
## Mutacao real vive em CombatResultApplier. UI resolve nomes via
## AlchemonDatabase na hora de exibir, nunca aqui.

const MISS_CHANCE := 1.0 / 6.0
const FLEE_CHANCE := 5.0 / 6.0
const CAPTURE_CHANCE := 2.0 / 6.0
const ITEM_HEAL_AMOUNT := 6
const CRIT_ROLL_MAX := 20
const CRIT_MULTIPLIER := 1.5


static func roll_initiative(state: CombatState) -> void:
	var all_ids: Array[int] = state.player_ids + state.enemy_ids
	for id in all_ids:
		state.get_combatant(id).initiative = randi_range(1, 20)

	all_ids.sort_custom(func(a, b): return state.get_combatant(a).initiative > state.get_combatant(b).initiative)
	state.turn_order_ids = all_ids


## Contrato publico unico de resolucao. Sempre retorna CombatResult -
## nunca Dictionary, nunca null.
static func resolve_action(state: CombatState, command: ActionCommand, database: AlchemonDatabase) -> CombatResult:
	var actor := state.get_combatant(command.actor_id)
	if actor == null or not actor.alive:
		return CombatResult.already_dead(command.actor_id, command.target_id, "actor_dead")

	match command.kind:
		"attack":
			return _resolve_attack(state, command, database)
		"item":
			return _resolve_item(state, command)
		"capture":
			return _resolve_capture(state, command)
		_:
			return CombatResult.invalid_action(actor.id, command.target_id, "unknown_command")


static func _resolve_attack(state: CombatState, command: ActionCommand, database: AlchemonDatabase) -> CombatResult:
	var actor := state.get_combatant(command.actor_id)
	var target := state.get_combatant(command.target_id)
	if target == null or not target.alive:
		return CombatResult.already_dead(actor.id, command.target_id, "target_dead")

	# Valida alvo do lado oposto via battlefield/estado (nao muta nada).
	if target.id not in state.get_valid_targets(actor.id):
		return CombatResult.invalid_target(actor.id, target.id, "invalid_target")

	var template := database.get_by_id(actor.species_id)
	var valid_index := template != null and command.attack_index >= 0 and command.attack_index < template.attacks.size()
	if not valid_index:
		return CombatResult.invalid_action(actor.id, target.id, "invalid_attack")

	var attack: AttackData = template.attacks[command.attack_index]

	if randf() < MISS_CHANCE:
		return CombatResult.attack_miss(actor.id, target.id, attack.attack_name)

	var is_critical := randi_range(1, CRIT_ROLL_MAX) == CRIT_ROLL_MAX
	var damage := attack.damage
	if is_critical:
		damage = int(round(damage * CRIT_MULTIPLIER))

	return CombatResult.attack_hit(actor.id, target.id, attack.attack_name, damage, is_critical)


static func _resolve_item(state: CombatState, command: ActionCommand) -> CombatResult:
	var actor := state.get_combatant(command.actor_id)
	var target := state.get_combatant(command.target_id)
	if target == null or not target.alive:
		return CombatResult.already_dead(actor.id, command.target_id, "target_dead")

	# Quantidade real que sera curada (clampada), calculada sem mutar target.
	var healed: int = mini(ITEM_HEAL_AMOUNT, target.max_hp - target.hp)
	return CombatResult.item_used(actor.id, target.id, healed)


static func _resolve_capture(state: CombatState, command: ActionCommand) -> CombatResult:
	var actor := state.get_combatant(command.actor_id)
	var target := state.get_combatant(command.target_id)
	if target == null or not target.alive:
		return CombatResult.already_dead(actor.id, command.target_id, "target_dead")

	if randf() < CAPTURE_CHANCE:
		return CombatResult.capture_success(actor.id, target.id)

	return CombatResult.capture_fail(actor.id, target.id)


static func resolve_flee() -> CombatResult:
	if randf() < FLEE_CHANCE:
		return CombatResult.flee_success()
	return CombatResult.flee_fail()


static func check_combat_end(state: CombatState) -> void:
	if state.get_alive_ids(state.player_ids).is_empty():
		_mark_battle_outcome(state, false)
	elif state.get_alive_ids(state.enemy_ids).is_empty():
		_mark_battle_outcome(state, true)


static func _mark_battle_outcome(state: CombatState, player_won: bool) -> void:
	if state.combat_over:
		return # idempotente - nao re-transiciona uma fase ja terminal

	state.combat_over = true
	state.player_won = player_won
	if state.battle_phase == null:
		state.battle_phase = BattlePhaseMachine.new(BattlePhaseMachine.COMBAT_OVER)

	state.battle_phase.force_phase(BattlePhaseMachine.VICTORY if player_won else BattlePhaseMachine.DEFEAT)
	state.phase = state.battle_phase.current_phase()


static func pick_random_alive_target_id(state: CombatState, team_ids: Array[int]) -> int:
	var alive_ids := state.get_alive_ids(team_ids)
	if alive_ids.is_empty():
		return -1
	return alive_ids[randi() % alive_ids.size()]


static func pick_random_attack_index(database: AlchemonDatabase, species_id: int) -> int:
	var template := database.get_by_id(species_id)
	if template == null or template.attacks.is_empty():
		return -1
	return randi() % template.attacks.size()
