class_name CombatRules
extends RefCounted

## Sistema puro (V2) operando sobre CombatState + ActionCommand + AlchemonDatabase.
## Convive com combat_system.gd (V1, que ainda roda a versao em producao) ate
## a migracao ser validada. Eventos usam ids - quem exibe resolve nome via
## AlchemonDatabase, nunca aqui dentro.

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


static func resolve_action(state: CombatState, command: ActionCommand, database: AlchemonDatabase) -> Dictionary:
	var actor := state.get_combatant(command.actor_id)
	if actor == null or not actor.alive:
		return {"kind": "cancelled", "reason": "actor_dead"}

	match command.kind:
		"attack":
			return _resolve_attack(state, command, database)
		"item":
			return _resolve_item(state, command)
		"capture":
			return _resolve_capture(state, command)
		_:
			return {"kind": "unknown_command"}


static func _resolve_attack(state: CombatState, command: ActionCommand, database: AlchemonDatabase) -> Dictionary:
	var actor := state.get_combatant(command.actor_id)
	var target := state.get_combatant(command.target_id)
	if target == null or not target.alive:
		return {"kind": "cancelled", "reason": "target_dead", "actor_id": actor.id}

	# Validate target is on opposing side via battlefield
	if target.id not in state.get_valid_targets(actor.id):
		return {"kind": "cancelled", "reason": "invalid_target", "actor_id": actor.id}

	var template := database.get_by_id(actor.species_id)
	var valid_index := command.attack_index >= 0 and command.attack_index < template.attacks.size()
	if not valid_index:
		return {"kind": "cancelled", "reason": "invalid_attack", "actor_id": actor.id}

	var attack: AttackData = template.attacks[command.attack_index]

	if randf() < MISS_CHANCE:
		return {"kind": "attack_miss", "actor_id": actor.id, "target_id": target.id, "attack_name": attack.attack_name}

	var is_critical := randi_range(1, CRIT_ROLL_MAX) == CRIT_ROLL_MAX
	var damage := attack.damage
	if is_critical:
		damage = int(round(damage * CRIT_MULTIPLIER))

	target.hp = max(target.hp - damage, 0)
	if target.hp == 0:
		target.alive = false
		# Free the slot when combatant dies
		state.battlefield.free_slot(target.slot)

	return {
		"kind": "attack_hit",
		"actor_id": actor.id,
		"target_id": target.id,
		"damage": damage,
		"critical": is_critical,
		"attack_name": attack.attack_name,
	}


static func _resolve_item(state: CombatState, command: ActionCommand) -> Dictionary:
	var actor := state.get_combatant(command.actor_id)
	var target := state.get_combatant(command.target_id)
	if target == null or not target.alive:
		return {"kind": "cancelled", "reason": "target_dead", "actor_id": actor.id}

	target.hp = min(target.hp + ITEM_HEAL_AMOUNT, target.max_hp)
	return {"kind": "item_used", "actor_id": actor.id, "target_id": target.id, "amount": ITEM_HEAL_AMOUNT}


static func _resolve_capture(state: CombatState, command: ActionCommand) -> Dictionary:
	var actor := state.get_combatant(command.actor_id)
	var target := state.get_combatant(command.target_id)
	if target == null or not target.alive:
		return {"kind": "cancelled", "reason": "target_dead", "actor_id": actor.id}

	if randf() < CAPTURE_CHANCE:
		target.alive = false
		target.hp = 0
		# Free the slot when combatant is captured
		state.battlefield.free_slot(target.slot)
		return {"kind": "capture_success", "actor_id": actor.id, "target_id": target.id}

	return {"kind": "capture_fail", "actor_id": actor.id, "target_id": target.id}


static func attempt_flee() -> bool:
	return randf() < FLEE_CHANCE


static func check_combat_end(state: CombatState) -> void:
	if state.get_alive_ids(state.player_ids).is_empty():
		state.combat_over = true
		state.player_won = false
		state.phase = "combat_over"
	elif state.get_alive_ids(state.enemy_ids).is_empty():
		state.combat_over = true
		state.player_won = true
		state.phase = "combat_over"


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
