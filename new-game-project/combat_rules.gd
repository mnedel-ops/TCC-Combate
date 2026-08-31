class_name CombatRules
extends RefCounted

## Sistema puro operando sobre CombatState + ActionCommand + AlchemonDatabase.
## Eventos usam IDs; quem exibe resolve nome via AlchemonDatabase, nunca aqui.

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

<<<<<<< Updated upstream
	all_ids.sort_custom(func(a, b): return state.get_combatant(a).initiative > state.get_combatant(b).initiative)
	state.turn_order_ids = all_ids
=======
	all_ids.sort_custom(func(a, b): return next_state.get_combatant(a).initiative > next_state.get_combatant(b).initiative)
	next_state.turn_order_ids = all_ids
	return TransitionResult.new(next_state, [CombatEvent.initiative_rolled()])
>>>>>>> Stashed changes


static func resolve_action(state: CombatState, command: ActionCommand, database: AlchemonDatabase) -> Dictionary:
	var actor := state.get_combatant(command.actor_id)
	if actor == null or not actor.alive:
<<<<<<< Updated upstream
		return {"kind": "cancelled", "reason": "actor_dead"}

=======
		return TransitionResult.new(next_state, [CombatEvent.cancelled("actor_dead")])

	var event: CombatEvent
>>>>>>> Stashed changes
	match command.kind:
		"attack":
			return _resolve_attack(state, command, database)
		"item":
			return _resolve_item(state, command)
		"capture":
			return _resolve_capture(state, command)
		_:
<<<<<<< Updated upstream
			return {"kind": "unknown_command"}
=======
			event = CombatEvent.unknown_command()

	var events: Array[CombatEvent] = [event]
	var combat_end_event := _check_combat_end_in_place(next_state)
	if combat_end_event != null:
		events.append(combat_end_event)
	return TransitionResult.new(next_state, events)
>>>>>>> Stashed changes


static func _resolve_attack(state: CombatState, command: ActionCommand, database: AlchemonDatabase) -> CombatEvent:
	var actor := state.get_combatant(command.actor_id)
	var target := state.get_combatant(command.target_id)
	if target == null or not target.alive:
		return CombatEvent.cancelled("target_dead", actor.id)
	if target.is_player == actor.is_player:
		return CombatEvent.cancelled("invalid_target_type", actor.id)

	var template := database.get_by_id(actor.species_id)
	var valid_index := template != null and command.attack_index >= 0 and command.attack_index < template.attacks.size()
	if not valid_index:
		return CombatEvent.cancelled("invalid_attack", actor.id)

	var attack: AttackData = template.attacks[command.attack_index]

	if randf() < MISS_CHANCE:
		return CombatEvent.attack_miss(actor.id, target.id, attack.attack_name)

	var is_critical := randi_range(1, CRIT_ROLL_MAX) == CRIT_ROLL_MAX
	var damage := attack.damage
	if is_critical:
		damage = int(round(damage * CRIT_MULTIPLIER))

	target.hp = max(target.hp - damage, 0)
	if target.hp == 0:
		target.alive = false

	return CombatEvent.attack_hit(actor.id, target.id, attack.attack_name, damage, is_critical)


static func _resolve_item(state: CombatState, command: ActionCommand) -> CombatEvent:
	var actor := state.get_combatant(command.actor_id)
	var target := state.get_combatant(command.target_id)
	if target == null or not target.alive:
		return CombatEvent.cancelled("target_dead", actor.id)
	if target.is_player != actor.is_player:
		return CombatEvent.cancelled("invalid_target_type", actor.id)

	target.hp = min(target.hp + ITEM_HEAL_AMOUNT, target.max_hp)
	return CombatEvent.item_used(actor.id, target.id, ITEM_HEAL_AMOUNT)


static func _resolve_capture(state: CombatState, command: ActionCommand) -> CombatEvent:
	var actor := state.get_combatant(command.actor_id)
	var target := state.get_combatant(command.target_id)
	if target == null or not target.alive:
		return CombatEvent.cancelled("target_dead", actor.id)
	if target.is_player == actor.is_player:
		return CombatEvent.cancelled("invalid_target_type", actor.id)

	if randf() < CAPTURE_CHANCE:
		target.alive = false
		target.hp = 0
		return CombatEvent.capture_success(actor.id, target.id)

	return CombatEvent.capture_fail(actor.id, target.id)


static func attempt_flee() -> bool:
	return randf() < FLEE_CHANCE


<<<<<<< Updated upstream
static func check_combat_end(state: CombatState) -> void:
=======
static func check_combat_end(state: CombatState) -> TransitionResult:
	var next_state := state.clone()
	var events: Array[CombatEvent] = [CombatEvent.combat_end_checked()]
	var combat_end_event := _check_combat_end_in_place(next_state)
	if combat_end_event != null:
		events.append(combat_end_event)
	return TransitionResult.new(next_state, events)


static func end_round(state: CombatState) -> TransitionResult:
	var next_state := state.clone()
	next_state.round_number += 1
	return TransitionResult.new(next_state, [CombatEvent.round_ended(next_state.round_number)])


static func _check_combat_end_in_place(state: CombatState) -> CombatEvent:
	if state.combat_over:
		return null
>>>>>>> Stashed changes
	if state.get_alive_ids(state.player_ids).is_empty():
		state.combat_over = true
		state.player_won = false
		state.phase = "combat_over"
		return CombatEvent.combat_ended(false)
	elif state.get_alive_ids(state.enemy_ids).is_empty():
		state.combat_over = true
		state.player_won = true
		state.phase = "combat_over"
		return CombatEvent.combat_ended(true)
	return null


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
