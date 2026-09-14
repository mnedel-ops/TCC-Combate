class_name CombatRules
extends RefCounted

## Pure rules engine operating on CombatState + ActionCommand + AlchemonDatabase.
## Stateless, deterministic (except for randomness). Events use IDs; UI resolves names
## via AlchemonDatabase at display time, never here.

const MISS_CHANCE := 1.0 / 6.0
const FLEE_CHANCE := 5.0 / 6.0
const CAPTURE_CHANCE := 2.0 / 6.0
const ITEM_HEAL_AMOUNT := 6
const CRIT_ROLL_MAX := 20
const CRIT_MULTIPLIER := 1.5
const SLAP_NAME := "Slap"       # forced fallback attack when actor has 0 valence electrons
const SLAP_DAMAGE := 10
const SLAP_COST := 0


static func roll_initiative(state: CombatState) -> void:
	var all_ids: Array[int] = state.player_ids + state.enemy_ids
	for id in all_ids:
		state.get_combatant(id).initiative = randi_range(1, 20)

	all_ids.sort_custom(func(a, b): return state.get_combatant(a).initiative > state.get_combatant(b).initiative)
	state.turn_order_ids = all_ids


## Data-oriented readiness check. Round only resolves when every alive
## actor (both players AND enemy AI) has a queued command.
static func get_required_actor_ids(state: CombatState) -> Array[int]:
	return state.get_alive_ids(state.player_ids) + state.get_alive_ids(state.enemy_ids)


static func find_command_for(state: CombatState, actor_id: int) -> ActionCommand:
	for command in state.pending_actions:
		if command.actor_id == actor_id:
			return command
	return null


static func has_all_commands(state: CombatState) -> bool:
	for id in get_required_actor_ids(state):
		if find_command_for(state, id) == null:
			return false
	return true


## Pure damage calc. Separated from RNG so crit math is testable without seeding.
static func compute_damage(base_damage: int, is_critical: bool) -> int:
	if is_critical:
		return int(round(base_damage * CRIT_MULTIPLIER))
	return base_damage


## If original target already dead (killed by earlier action same round),
## auto-swap to remaining alive creature on correct side. Attack/capture
## retarget enemy side, item retargets own side.
static func _retarget_if_dead(state: CombatState, command: ActionCommand) -> void:
	if command.target_id == -1:
		return
	var target := state.get_combatant(command.target_id)
	if target != null and target.alive:
		return
	var actor := state.get_combatant(command.actor_id)
	if actor == null:
		return
	var pool_is_player := actor.is_player if command.kind == "item" else not actor.is_player
	var replacement := pick_random_alive_target_id(state, state.get_team_ids(pool_is_player))
	if replacement != -1:
		command.target_id = replacement


static func resolve_action(state: CombatState, command: ActionCommand, database: AlchemonDatabase) -> Dictionary:
	var actor := state.get_combatant(command.actor_id)
	if actor == null or not actor.alive:
		return {"kind": "cancelled", "reason": "actor_dead"}

	_retarget_if_dead(state, command)

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

	# Player still picks by name/index like normal - but with 0 valence
	# electrons left, every attack executes as a free 10-dmg Slap instead.
	# UI keeps showing the real attack names; only the resolved effect swaps.
	var attack_name := attack.attack_name
	var base_damage := attack.damage
	var cost := attack.energy_cost

	if actor.valence_electrons <= 0:
		attack_name = SLAP_NAME
		base_damage = SLAP_DAMAGE
		cost = SLAP_COST

	actor.valence_electrons = max(actor.valence_electrons - cost, 0)

	if randf() < MISS_CHANCE:
		return {"kind": "attack_miss", "actor_id": actor.id, "target_id": target.id, "attack_name": attack_name}

	var is_critical := randi_range(1, CRIT_ROLL_MAX) == CRIT_ROLL_MAX
	var damage := compute_damage(base_damage, is_critical)

	target.hp = max(target.hp - damage, 0)
	if target.hp == 0:
		target.alive = false
		# Free the slot when combatant dies
		BattlefieldRules.free_slot(state.battlefield, target.slot)

	return {
		"kind": "attack_hit",
		"actor_id": actor.id,
		"target_id": target.id,
		"damage": damage,
		"critical": is_critical,
		"attack_name": attack_name,
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
		BattlefieldRules.free_slot(state.battlefield, target.slot)
		return {"kind": "capture_success", "actor_id": actor.id, "target_id": target.id}

	return {"kind": "capture_fail", "actor_id": actor.id, "target_id": target.id}


static func attempt_flee() -> bool:
	return randf() < FLEE_CHANCE


static func check_combat_end(state: CombatState) -> void:
	if state.get_alive_ids(state.player_ids).is_empty():
		_mark_battle_outcome(state, false)
	elif state.get_alive_ids(state.enemy_ids).is_empty():
		_mark_battle_outcome(state, true)


static func _mark_battle_outcome(state: CombatState, player_won: bool) -> void:
	state.combat_over = true
	state.player_won = player_won

	if BattlePhaseRules.is_valid_transition(state.phase, BattlePhaseRules.COMBAT_OVER):
		state.phase = BattlePhaseRules.COMBAT_OVER

	var final_phase := BattlePhaseRules.VICTORY if player_won else BattlePhaseRules.DEFEAT
	if BattlePhaseRules.is_valid_transition(state.phase, final_phase):
		state.phase = final_phase

	# Keep the BattlePhaseMachine instance (state.battle_phase) in lockstep
	# with state.phase - victory/defeat must always be reachable regardless
	# of what "normal" phase combat was in when the kill happened, so this
	# forces it directly instead of going through transition() validation.
	if state.battle_phase != null:
		state.battle_phase.force_phase(state.phase)


static func pick_random_alive_target_id(state: CombatState, team_ids: Array[int]) -> int:
	var alive_ids := state.get_alive_ids(team_ids)
	if alive_ids.is_empty():
		return -1
	return alive_ids[randi() % alive_ids.size()]


## Only picks among any attack. Fallback to Slap (see _resolve_attack)
## handles the 0-energy case, so the AI never needs to worry about
## affordability when choosing what to try.
static func pick_random_attack_index(database: AlchemonDatabase, species_id: int) -> int:
	var template := database.get_by_id(species_id)
	if template == null or template.attacks.is_empty():
		return -1
	return randi() % template.attacks.size()
