class_name CombatSystem
extends RefCounted

const MISS_CHANCE := 1.0 / 6.0
const FLEE_CHANCE := 5.0 / 6.0
const CAPTURE_CHANCE := 2.0 / 6.0
const ITEM_HEAL_AMOUNT := 6
const CRIT_ROLL_MAX := 20
const CRIT_MULTIPLIER := 1.5


static func initialize_state(player_templates: Array, enemy_templates: Array, seed: int = 1) -> Dictionary:
	var combatants := {}
	var player_team_ids: Array[int] = []
	var enemy_team_ids: Array[int] = []
	var next_combatant_id := 1

	for template in player_templates:
		var combatant := _create_combatant_from_template(template, next_combatant_id, true)
		combatants[next_combatant_id] = combatant
		player_team_ids.append(next_combatant_id)
		next_combatant_id += 1

	for template in enemy_templates:
		var combatant := _create_combatant_from_template(template, next_combatant_id, false)
		combatants[next_combatant_id] = combatant
		enemy_team_ids.append(next_combatant_id)
		next_combatant_id += 1

	var state := {
		"combatants": combatants,
		"player_team_ids": player_team_ids,
		"enemy_team_ids": enemy_team_ids,
		"turn_order_ids": [],
		"pending_actions": [],
		"combat_over": false,
		"player_won": false,
		"outcome": "ongoing",
		"phase": "selecting_actions",
		"round_number": 1,
		"current_player_selection_index": 0,
		"rng_seed": _normalize_seed(seed),
	}

	state = _roll_initiative(state)
	state["current_player_selection_index"] = _find_next_alive_player_index(state, 0)
	return state


static func apply_command(state: Dictionary, command: Dictionary) -> Dictionary:
	var new_state: Dictionary = state.duplicate(true)
	var events: Array = []
	var command_type := String(command.get("type", ""))

	if command_type == "":
		_append_event(events, "invalid_command", {"reason": "missing_type"})
		return {"state": new_state, "events": events}

	if bool(new_state.get("combat_over", false)):
		_append_event(events, "combat_already_over")
		return {"state": new_state, "events": events}

	match command_type:
		"queue_action":
			_process_queue_action(new_state, command, events)
		"resolve_round":
			_process_resolve_round(new_state, events)
		"attempt_flee":
			_process_attempt_flee(new_state, events)
		_:
			_append_event(events, "invalid_command", {"reason": "unknown_type", "type": command_type})

	return {"state": new_state, "events": events}


static func get_current_player_actor_id(state: Dictionary) -> int:
	if String(state.get("phase", "")) != "selecting_actions":
		return -1
	var index := int(state.get("current_player_selection_index", -1))
	var player_team_ids: Array = state.get("player_team_ids", [])
	if index < 0 or index >= player_team_ids.size():
		return -1
	return int(player_team_ids[index])


static func get_combatant(state: Dictionary, combatant_id: int) -> Dictionary:
	var combatants: Dictionary = state.get("combatants", {})
	return combatants.get(combatant_id, {})


static func get_team_combatants(state: Dictionary, team_key: String) -> Array:
	var team_ids: Array = state.get(team_key, [])
	var result: Array = []
	for combatant_id in team_ids:
		result.append(get_combatant(state, int(combatant_id)))
	return result


static func get_available_actions_for_actor(state: Dictionary, actor_id: int) -> Array:
	var actor := get_combatant(state, actor_id)
	if actor.is_empty() or not bool(actor.get("alive", false)):
		return []
	return ["attack", "item", "capture", "flee"]


static func get_valid_targets(state: Dictionary, actor_id: int, kind: String) -> Array[int]:
	var actor := get_combatant(state, actor_id)
	if actor.is_empty() or not bool(actor.get("alive", false)):
		return []

	var team_ids: Array = []
	match kind:
		"attack", "capture":
			team_ids = state.get("enemy_team_ids", [])
		"item":
			team_ids = state.get("player_team_ids", [])
		_:
			return []

	var targets: Array[int] = []
	for target_id in team_ids:
		var target := get_combatant(state, int(target_id))
		if bool(target.get("alive", false)):
			targets.append(int(target_id))
	return targets


static func _process_queue_action(state: Dictionary, command: Dictionary, events: Array) -> void:
	if String(state.get("phase", "")) != "selecting_actions":
		_append_event(events, "action_rejected", {"reason": "not_in_selection_phase"})
		return

	var actor_id := int(command.get("actor_id", -1))
	var expected_actor_id := get_current_player_actor_id(state)
	if actor_id != expected_actor_id:
		_append_event(events, "action_rejected", {"reason": "wrong_actor", "expected_actor_id": expected_actor_id, "actor_id": actor_id})
		return

	var kind := String(command.get("kind", ""))
	if kind == "flee":
		_process_attempt_flee(state, events)
		return

	var actor := get_combatant(state, actor_id)
	if actor.is_empty() or not bool(actor.get("alive", false)):
		_append_event(events, "action_rejected", {"reason": "actor_not_alive", "actor_id": actor_id})
		return

	if kind != "attack" and kind != "item" and kind != "capture":
		_append_event(events, "action_rejected", {"reason": "invalid_kind", "kind": kind})
		return

	var target_id := int(command.get("target_id", -1))
	var valid_targets := get_valid_targets(state, actor_id, kind)
	if not valid_targets.has(target_id):
		_append_event(events, "action_rejected", {"reason": "invalid_target", "actor_id": actor_id, "target_id": target_id, "kind": kind})
		return

	var action := {
		"actor_id": actor_id,
		"kind": kind,
		"target_id": target_id,
		"attack_index": -1,
	}

	if kind == "attack":
		var attack_index := int(command.get("attack_index", -1))
		var attacks: Array = actor.get("attacks", [])
		if attack_index < 0 or attack_index >= attacks.size():
			_append_event(events, "action_rejected", {"reason": "invalid_attack_index", "actor_id": actor_id, "attack_index": attack_index})
			return
		action["attack_index"] = attack_index

	var pending_actions: Array = state.get("pending_actions", [])
	pending_actions.append(action)
	state["pending_actions"] = pending_actions
	_append_event(events, "action_queued", action)

	var current_index := int(state.get("current_player_selection_index", 0))
	var next_index := _find_next_alive_player_index(state, current_index + 1)
	state["current_player_selection_index"] = next_index

	if next_index == -1:
		_queue_enemy_actions(state, events)
		state["phase"] = "resolving_round"
		_append_event(events, "round_ready", {"round_number": int(state.get("round_number", 1))})
	else:
		var player_team_ids: Array = state.get("player_team_ids", [])
		_append_event(events, "awaiting_player_action", {"actor_id": int(player_team_ids[next_index])})


static func _process_resolve_round(state: Dictionary, events: Array) -> void:
	if String(state.get("phase", "")) != "resolving_round":
		_append_event(events, "round_resolve_rejected", {"reason": "not_in_resolving_phase"})
		return

	_append_event(events, "round_started", {"round_number": int(state.get("round_number", 1))})

	var turn_order_ids: Array = state.get("turn_order_ids", [])
	for actor_id_variant in turn_order_ids:
		if bool(state.get("combat_over", false)):
			break

		var actor_id := int(actor_id_variant)
		var actor := get_combatant(state, actor_id)
		if actor.is_empty() or not bool(actor.get("alive", false)):
			continue

		var action := _find_pending_action_for_actor(state, actor_id)
		if action.is_empty():
			continue

		_append_event(events, "turn_start", {"actor_id": actor_id})
		_resolve_single_action(state, action, events)
		_check_combat_end(state, events)

	if bool(state.get("combat_over", false)):
		return

	state["pending_actions"] = []
	state["round_number"] = int(state.get("round_number", 1)) + 1
	state["phase"] = "selecting_actions"
	state["current_player_selection_index"] = _find_next_alive_player_index(state, 0)
	_append_event(events, "round_resolved", {"round_number": int(state.get("round_number", 1)) - 1})

	var next_actor_id := get_current_player_actor_id(state)
	if next_actor_id != -1:
		_append_event(events, "awaiting_player_action", {"actor_id": next_actor_id})


static func _process_attempt_flee(state: Dictionary, events: Array) -> void:
	_append_event(events, "flee_attempted")
	if _roll_chance(state, FLEE_CHANCE):
		state["combat_over"] = true
		state["outcome"] = "fled"
		state["phase"] = "combat_end"
		_append_event(events, "flee_success")
		_append_event(events, "combat_end", {"outcome": "fled"})
		return

	_append_event(events, "flee_failed")
	state["pending_actions"] = []

	var enemy_team_ids: Array = state.get("enemy_team_ids", [])
	for enemy_id_variant in enemy_team_ids:
		if bool(state.get("combat_over", false)):
			break

		var enemy_id := int(enemy_id_variant)
		var enemy := get_combatant(state, enemy_id)
		if enemy.is_empty() or not bool(enemy.get("alive", false)):
			continue

		var possible_targets := _alive_team_ids(state, "player_team_ids")
		if possible_targets.is_empty():
			break

		var target_id := _pick_random_id(state, possible_targets)
		var attacks: Array = enemy.get("attacks", [])
		if attacks.is_empty():
			_append_event(events, "action_cancelled", {"actor_id": enemy_id, "reason": "no_attacks"})
			continue
		var attack_index := _roll_int(state, 0, attacks.size() - 1)
		var action := {
			"actor_id": enemy_id,
			"kind": "attack",
			"target_id": target_id,
			"attack_index": attack_index,
		}
		_append_event(events, "turn_start", {"actor_id": enemy_id})
		_resolve_single_action(state, action, events)
		_check_combat_end(state, events)

	if bool(state.get("combat_over", false)):
		return

	state["phase"] = "selecting_actions"
	state["current_player_selection_index"] = _find_next_alive_player_index(state, 0)
	var next_actor_id := get_current_player_actor_id(state)
	if next_actor_id != -1:
		_append_event(events, "awaiting_player_action", {"actor_id": next_actor_id})


static func _resolve_single_action(state: Dictionary, action: Dictionary, events: Array) -> void:
	var actor_id := int(action.get("actor_id", -1))
	var target_id := int(action.get("target_id", -1))
	var kind := String(action.get("kind", ""))

	var actor := get_combatant(state, actor_id)
	if actor.is_empty() or not bool(actor.get("alive", false)):
		_append_event(events, "action_cancelled", {"actor_id": actor_id, "reason": "actor_not_alive"})
		return

	var target := get_combatant(state, target_id)
	if target.is_empty() or not bool(target.get("alive", false)):
		_append_event(events, "action_cancelled", {"actor_id": actor_id, "target_id": target_id, "reason": "target_not_alive"})
		return

	match kind:
		"attack":
			_resolve_attack(state, action, events)
		"item":
			_resolve_item(state, action, events)
		"capture":
			_resolve_capture(state, action, events)
		_:
			_append_event(events, "action_cancelled", {"actor_id": actor_id, "reason": "unknown_kind", "kind": kind})


static func _resolve_attack(state: Dictionary, action: Dictionary, events: Array) -> void:
	var actor_id := int(action["actor_id"])
	var target_id := int(action["target_id"])
	var actor := get_combatant(state, actor_id)
	var target := get_combatant(state, target_id)
	var attacks: Array = actor.get("attacks", [])
	var attack_index := int(action.get("attack_index", -1))

	if attack_index < 0 or attack_index >= attacks.size():
		_append_event(events, "action_cancelled", {"actor_id": actor_id, "reason": "invalid_attack_index", "attack_index": attack_index})
		return

	var attack: Dictionary = attacks[attack_index]
	if _roll_chance(state, MISS_CHANCE):
		_append_event(events, "attack_miss", {
			"actor_id": actor_id,
			"target_id": target_id,
			"attack_name": String(attack.get("attack_name", "Ataque")),
		})
		return

	var is_critical := _roll_int(state, 1, CRIT_ROLL_MAX) == CRIT_ROLL_MAX
	var damage := int(attack.get("damage", 0))
	if is_critical:
		damage = int(round(float(damage) * CRIT_MULTIPLIER))

	target["hp"] = max(int(target.get("hp", 0)) - damage, 0)
	if int(target.get("hp", 0)) == 0:
		target["alive"] = false

	_set_combatant(state, target_id, target)

	_append_event(events, "attack_hit", {
		"actor_id": actor_id,
		"target_id": target_id,
		"damage": damage,
		"critical": is_critical,
		"attack_name": String(attack.get("attack_name", "Ataque")),
	})

	if not bool(target.get("alive", true)):
		_append_event(events, "combatant_defeated", {"combatant_id": target_id})


static func _resolve_item(state: Dictionary, action: Dictionary, events: Array) -> void:
	var actor_id := int(action["actor_id"])
	var target_id := int(action["target_id"])
	var target := get_combatant(state, target_id)

	var old_hp := int(target.get("hp", 0))
	target["hp"] = min(old_hp + ITEM_HEAL_AMOUNT, int(target.get("max_hp", old_hp)))
	_set_combatant(state, target_id, target)

	_append_event(events, "item_used", {
		"actor_id": actor_id,
		"target_id": target_id,
		"amount": int(target["hp"]) - old_hp,
	})


static func _resolve_capture(state: Dictionary, action: Dictionary, events: Array) -> void:
	var actor_id := int(action["actor_id"])
	var target_id := int(action["target_id"])
	var target := get_combatant(state, target_id)

	if _roll_chance(state, CAPTURE_CHANCE):
		target["alive"] = false
		target["hp"] = 0
		_set_combatant(state, target_id, target)
		_append_event(events, "capture_success", {"actor_id": actor_id, "target_id": target_id})
		_append_event(events, "combatant_defeated", {"combatant_id": target_id})
		return

	_append_event(events, "capture_fail", {"actor_id": actor_id, "target_id": target_id})


static func _check_combat_end(state: Dictionary, events: Array) -> void:
	var player_alive := _team_has_alive(state, "player_team_ids")
	var enemy_alive := _team_has_alive(state, "enemy_team_ids")

	if not player_alive:
		state["combat_over"] = true
		state["player_won"] = false
		state["outcome"] = "defeat"
		state["phase"] = "combat_end"
		_append_event(events, "combat_end", {"outcome": "defeat"})
	elif not enemy_alive:
		state["combat_over"] = true
		state["player_won"] = true
		state["outcome"] = "victory"
		state["phase"] = "combat_end"
		_append_event(events, "combat_end", {"outcome": "victory"})


static func _queue_enemy_actions(state: Dictionary, events: Array) -> void:
	var pending_actions: Array = state.get("pending_actions", [])
	var enemy_team_ids: Array = state.get("enemy_team_ids", [])

	for enemy_id_variant in enemy_team_ids:
		var enemy_id := int(enemy_id_variant)
		var enemy := get_combatant(state, enemy_id)
		if enemy.is_empty() or not bool(enemy.get("alive", false)):
			continue

		var alive_targets := _alive_team_ids(state, "player_team_ids")
		if alive_targets.is_empty():
			break

		var attacks: Array = enemy.get("attacks", [])
		if attacks.is_empty():
			continue

		var target_id := _pick_random_id(state, alive_targets)
		var attack_index := _roll_int(state, 0, attacks.size() - 1)
		var action := {
			"actor_id": enemy_id,
			"kind": "attack",
			"target_id": target_id,
			"attack_index": attack_index,
		}
		pending_actions.append(action)
		_append_event(events, "enemy_action_queued", action)

	state["pending_actions"] = pending_actions


static func _roll_initiative(state: Dictionary) -> Dictionary:
	var order: Array = []
	var combatants: Dictionary = state.get("combatants", {})

	for combatant_id in combatants.keys():
		var combatant: Dictionary = combatants[combatant_id]
		combatant["initiative"] = _roll_int(state, 1, 20)
		combatants[combatant_id] = combatant
		order.append(int(combatant_id))

	order.sort_custom(func(a, b):
		var ca: Dictionary = combatants.get(int(a), {})
		var cb: Dictionary = combatants.get(int(b), {})
		return int(ca.get("initiative", 0)) > int(cb.get("initiative", 0))
	)

	state["combatants"] = combatants
	state["turn_order_ids"] = order
	return state


static func _create_combatant_from_template(template: Dictionary, combatant_id: int, is_player: bool) -> Dictionary:
	var attacks: Array = []
	for attack in template.get("attacks", []):
		attacks.append({
			"attack_name": String(attack.get("attack_name", "Ataque")),
			"damage": int(attack.get("damage", 0)),
		})

	var max_hp := int(template.get("max_hp", 1))
	return {
		"combatant_id": combatant_id,
		"species_id": int(template.get("species_id", -1)),
		"creature_name": String(template.get("creature_name", "")),
		"max_hp": max_hp,
		"hp": max_hp,
		"is_player": is_player,
		"initiative": 0,
		"alive": true,
		"attacks": attacks,
	}


static func _find_pending_action_for_actor(state: Dictionary, actor_id: int) -> Dictionary:
	var pending_actions: Array = state.get("pending_actions", [])
	for action in pending_actions:
		if int(action.get("actor_id", -1)) == actor_id:
			return action
	return {}


static func _find_next_alive_player_index(state: Dictionary, start_index: int) -> int:
	var player_team_ids: Array = state.get("player_team_ids", [])
	for i in range(start_index, player_team_ids.size()):
		var combatant := get_combatant(state, int(player_team_ids[i]))
		if bool(combatant.get("alive", false)):
			return i
	return -1


static func _alive_team_ids(state: Dictionary, team_key: String) -> Array[int]:
	var team_ids: Array = state.get(team_key, [])
	var alive_ids: Array[int] = []
	for combatant_id in team_ids:
		var combatant := get_combatant(state, int(combatant_id))
		if bool(combatant.get("alive", false)):
			alive_ids.append(int(combatant_id))
	return alive_ids


static func _team_has_alive(state: Dictionary, team_key: String) -> bool:
	var team_ids: Array = state.get(team_key, [])
	for combatant_id in team_ids:
		var combatant := get_combatant(state, int(combatant_id))
		if bool(combatant.get("alive", false)):
			return true
	return false


static func _set_combatant(state: Dictionary, combatant_id: int, combatant: Dictionary) -> void:
	var combatants: Dictionary = state.get("combatants", {})
	combatants[combatant_id] = combatant
	state["combatants"] = combatants


static func _pick_random_id(state: Dictionary, ids: Array[int]) -> int:
	if ids.is_empty():
		return -1
	var index := _roll_int(state, 0, ids.size() - 1)
	return int(ids[index])


static func _append_event(events: Array, kind: String, payload: Dictionary = {}) -> void:
	var event := {"kind": kind}
	for key in payload.keys():
		event[key] = payload[key]
	events.append(event)


static func _roll_chance(state: Dictionary, chance: float) -> bool:
	return _roll_float(state) < chance


static func _roll_int(state: Dictionary, min_value: int, max_value: int) -> int:
	if min_value >= max_value:
		return min_value
	var roll := _roll_float(state)
	var span := float(max_value - min_value + 1)
	var value := min_value + int(floor(roll * span))
	if value > max_value:
		value = max_value
	return value


static func _roll_float(state: Dictionary) -> float:
	var current_seed := _normalize_seed(int(state.get("rng_seed", 1)))
	var next_seed := _next_seed(current_seed)
	state["rng_seed"] = next_seed
	return float(next_seed) / 4294967295.0


static func _next_seed(seed: int) -> int:
	return int((int(seed) * 1664525 + 1013904223) & 0xFFFFFFFF)


static func _normalize_seed(seed: int) -> int:
	var normalized := int(seed & 0xFFFFFFFF)
	if normalized == 0:
		normalized = 1
	return normalized
