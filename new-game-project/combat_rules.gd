class_name CombatRules
extends RefCounted

## Resolver only computes an immutable CombatResult. CombatResultApplier is
## the sole writer of CombatState.

const MISS_CHANCE := 1.0 / 6.0
const FLEE_CHANCE := 5.0 / 6.0
const CAPTURE_CHANCE := 2.0 / 6.0
const ITEM_HEAL_AMOUNT := 6
const CRIT_CHANCE := 0.125
const CRIT_MULTIPLIER := 1.5
const SLAP_NAME := "Slap"
const SLAP_DAMAGE := 10
const SLAP_COST := 0


static func roll_initiative(state: CombatState) -> void:
	var all_ids: Array[int] = state.player_ids + state.enemy_ids
	for id in all_ids:
		var combatant := state.get_combatant(id)
		combatant.initiative = AlchemonFormulas.compute_initiative(combatant.mechanical_speed, combatant.individual_value, combatant.level)
	all_ids.sort_custom(func(a, b): return state.get_combatant(a).initiative > state.get_combatant(b).initiative)
	state.turn_order_ids = all_ids


static func get_required_actor_ids(state: CombatState) -> Array[int]:
	return state.get_active_ids(state.player_ids) + state.get_active_ids(state.enemy_ids)


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


static func compute_damage(base_damage: int, is_critical: bool) -> int:
	return int(round(float(base_damage) * (CRIT_MULTIPLIER if is_critical else 1.0)))


## Returns replacement id without changing submitted command data.
static func _retarget_if_dead(state: CombatState, command: ActionCommand) -> int:
	if command.target_id == -1:
		return -1
	var target := state.get_combatant(command.target_id)
	if target != null and target.alive:
		return command.target_id
	var actor := state.get_combatant(command.actor_id)
	if actor == null:
		return command.target_id
	var same_side := command.kind == "item"
	var pool := state.get_team_ids(actor.is_player if same_side else not actor.is_player)
	var replacement := pick_random_alive_target_id(state, pool)
	return replacement if replacement != -1 else command.target_id


static func resolve_action(state: CombatState, command: ActionCommand, database: AlchemonDatabase) -> CombatResult:
	var actor := state.get_combatant(command.actor_id)
	if actor == null or not actor.alive:
		return CombatResult.already_dead(command.actor_id, command.target_id, "actor_dead")
	var target_id := _retarget_if_dead(state, command)
	match command.kind:
		"attack":
			return _resolve_attack(state, command, database, target_id)
		"item":
			return _resolve_item(state, command, target_id)
		"capture":
			return _resolve_capture(state, command, target_id)
		_:
			return CombatResult.invalid_action(actor.id, target_id, "unknown_command")


static func _resolve_attack(state: CombatState, command: ActionCommand, database: AlchemonDatabase, target_id: int) -> CombatResult:
	var actor := state.get_combatant(command.actor_id)
	var target := state.get_combatant(target_id)
	if target == null or not target.alive:
		return CombatResult.already_dead(actor.id, target_id)
	if target.id not in state.get_valid_targets(actor.id):
		return CombatResult.invalid_target(actor.id, target.id)
	var template := database.get_by_id(actor.species_id)
	if template == null or command.attack_index < 0 or command.attack_index >= template.attacks.size():
		return CombatResult.invalid_action(actor.id, target.id, "invalid_attack")
	var attack: AttackData = template.attacks[command.attack_index]
	var is_slap := actor.valence_electrons <= 0
	var attack_name := SLAP_NAME if is_slap else attack.attack_name
	var power := SLAP_DAMAGE if is_slap else (attack.power if attack.power > 0 else attack.damage)
	var cost := SLAP_COST if is_slap else attack.energy_cost
	if randf() < MISS_CHANCE:
		return CombatResult.attack_miss(actor.id, target.id, attack_name, cost)
	var critical := randf() < CRIT_CHANCE
	var effectiveness := AlchemonType.NEUTRAL
	if not is_slap:
		var target_template := database.get_by_id(target.species_id)
		if target_template == null:
			return CombatResult.invalid_action(actor.id, target.id, "unknown_species")
		effectiveness = AlchemonType.effectiveness(attack.element_type, target_template.element_type)
	var base_damage := SLAP_DAMAGE if is_slap else AlchemonFormulas.compute_damage(actor.level, power, actor.attack, target.defense, effectiveness)
	var temperature_delta := 0 if is_slap else AlchemonFormulas.compute_temperature_delta(actor.level, power, actor.attack)
	return CombatResult.attack_hit(actor.id, target.id, attack_name, compute_damage(base_damage, critical), critical, temperature_delta, effectiveness, cost)


static func _resolve_item(state: CombatState, command: ActionCommand, target_id: int) -> CombatResult:
	var actor := state.get_combatant(command.actor_id)
	var target := state.get_combatant(target_id)
	if target == null or not target.alive:
		return CombatResult.already_dead(actor.id, target_id)
	if target.is_player != actor.is_player:
		return CombatResult.invalid_target(actor.id, target.id)
	return CombatResult.item_used(actor.id, target.id, ITEM_HEAL_AMOUNT)


static func _resolve_capture(state: CombatState, command: ActionCommand, target_id: int) -> CombatResult:
	var actor := state.get_combatant(command.actor_id)
	var target := state.get_combatant(target_id)
	if target == null or not target.alive:
		return CombatResult.already_dead(actor.id, target_id)
	if target.is_player == actor.is_player:
		return CombatResult.invalid_target(actor.id, target.id)
	return CombatResult.capture_success(actor.id, target.id) if randf() < CAPTURE_CHANCE else CombatResult.capture_fail(actor.id, target.id)


static func resolve_flee() -> CombatResult:
	return CombatResult.flee_success() if randf() < FLEE_CHANCE else CombatResult.flee_fail()


static func check_combat_end(state: CombatState) -> void:
	if state.get_alive_ids(state.player_ids).is_empty():
		_mark_battle_outcome(state, false)
	elif state.get_alive_ids(state.enemy_ids).is_empty():
		_mark_battle_outcome(state, true)


static func _mark_battle_outcome(state: CombatState, player_won: bool) -> void:
	state.combat_over = true
	state.player_won = player_won
	state.phase = BattlePhaseRules.COMBAT_OVER
	state.phase = BattlePhaseRules.VICTORY if player_won else BattlePhaseRules.DEFEAT
	state.battle_phase.force_phase(state.phase)


static func pick_random_alive_target_id(state: CombatState, team_ids: Array[int]) -> int:
	var alive_ids := state.get_active_ids(team_ids)
	return -1 if alive_ids.is_empty() else alive_ids[randi() % alive_ids.size()]


static func pick_random_attack_index(database: AlchemonDatabase, species_id: int) -> int:
	var template := database.get_by_id(species_id)
	return -1 if template == null or template.attacks.is_empty() else randi() % template.attacks.size()
