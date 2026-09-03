extends Control

## Combat state machine controller. Orchestrates battle phases.
## Rules are in CombatRules. UI is in Combat_UI_states.

@onready var ui: Combat_UI_states = $VBoxContainer

@export var database: AlchemonDatabase
@export var player_species_ids: Array[int] = []
@export var enemy_species_ids: Array[int] = []

var state: CombatState
var _selection_order: Array[int] = []
var _current_player_index := 0

func _ready() -> void:
	state = CombatStateFactory.build(database, player_species_ids, enemy_species_ids)

	if state.player_ids.is_empty() or state.enemy_ids.is_empty():
		push_error("CombatControllerV2: time vazio. Confere database e os arrays de species ids.")
		ui.set_turn_text("Erro de configuracao - veja o console.")
		return

	CombatRules.roll_initiative(state)
	state.battle_phase = BattlePhaseMachine.new(BattlePhaseMachine.ENCOUNTER_START)
	state.phase = state.battle_phase.current_phase()

	_refresh_hp_display()
	ui.log_message("Combate comecou!")
	_start_action_selection()


func _name_of(id: int) -> String:
	var c := state.get_combatant(id)
	return database.get_by_id(c.species_id).creature_name


func _refresh_hp_display() -> void:
	var player_entries: Array[Dictionary] = []
	for id in state.player_ids:
		var c := state.get_combatant(id)
		player_entries.append({"name": _name_of(id), "hp": c.hp, "max_hp": c.max_hp})

	var enemy_entries: Array[Dictionary] = []
	for id in state.enemy_ids:
		var c := state.get_combatant(id)
		enemy_entries.append({"name": _name_of(id), "hp": c.hp, "max_hp": c.max_hp})

	ui.update_hp_dict(player_entries, enemy_entries)


func _advance_phase(next_phase: String) -> bool:
	if not state.battle_phase.transition(next_phase):
		push_error("Invalid battle transition: %s -> %s" % [state.battle_phase.current_phase(), next_phase])
		return false
	state.phase = state.battle_phase.current_phase()
	return true


func _start_action_selection() -> void:
	if state.combat_over:
		return
	if state.battle_phase.current_phase() == BattlePhaseMachine.ENCOUNTER_START:
		_advance_phase(BattlePhaseMachine.SELECTING_ACTIONS)
	elif state.battle_phase.current_phase() == BattlePhaseMachine.END_OF_ROUND:
		_advance_phase(BattlePhaseMachine.SELECTING_ACTIONS)

	state.pending_actions.clear()
	_selection_order = state.get_alive_ids(state.player_ids)
	_current_player_index = 0
	_prompt_action_for_current()


func _prompt_action_for_current() -> void:
	if _current_player_index >= _selection_order.size():
		_queue_enemy_commands()
		_resolve_round()
		return

	var actor_id := _selection_order[_current_player_index]
	var actor := state.get_combatant(actor_id)
	var template := database.get_by_id(actor.species_id)

	ui.set_turn_text("Acao de %s:" % _name_of(actor_id))

	var options: Array = [
		{"text": "Item", "callback": func(): _begin_target_selection(actor_id, "item", -1)},
		{"text": "Capturar", "callback": func(): _begin_target_selection(actor_id, "capture", -1)},
		{"text": "Fugir", "callback": _on_flee_pressed},
	]
	for i in template.attacks.size():
		var attack_index := i
		options.append({
			"text": template.attacks[i].attack_name,
			"callback": func(): _begin_target_selection(actor_id, "attack", attack_index),
		})
	ui.show_options(options)


func _begin_target_selection(actor_id: int, kind: String, attack_index: int) -> void:
	var candidate_ids: Array[int] = []
	match kind:
		"attack", "capture":
			candidate_ids = state.get_alive_ids(state.enemy_ids)
		"item":
			candidate_ids = state.get_alive_ids(state.player_ids)

	ui.set_turn_text("%s: escolha o alvo" % _name_of(actor_id))

	var options: Array = []
	for target_id in candidate_ids:
		var c := state.get_combatant(target_id)
		options.append({
			"text": "%s (%d/%d HP)" % [_name_of(target_id), c.hp, c.max_hp],
			"callback": func(): _confirm_action(actor_id, kind, target_id, attack_index),
		})
	ui.show_options(options)


func _confirm_action(actor_id: int, kind: String, target_id: int, attack_index: int) -> void:
	state.pending_actions.append(ActionCommand.new(actor_id, kind, target_id, attack_index))
	_current_player_index += 1
	_prompt_action_for_current()


func _queue_enemy_commands() -> void:
	for enemy_id in state.get_alive_ids(state.enemy_ids):
		var target_id := CombatRules.pick_random_alive_target_id(state, state.player_ids)
		if target_id == -1:
			continue
		var enemy := state.get_combatant(enemy_id)
		var attack_index := CombatRules.pick_random_attack_index(database, enemy.species_id)
		if attack_index == -1:
			continue
		state.pending_actions.append(ActionCommand.new(enemy_id, "attack", target_id, attack_index))


func _find_command_for(actor_id: int) -> ActionCommand:
	for command in state.pending_actions:
		if command.actor_id == actor_id:
			return command
	return null


func _resolve_round() -> void:
	if not _advance_phase(BattlePhaseMachine.RESOLVING_ACTIONS):
		return
	ui.clear_options()

	for actor_id in state.turn_order_ids:
		if state.combat_over:
			break

		var actor := state.get_combatant(actor_id)
		if not actor.alive:
			continue

		var command := _find_command_for(actor_id)
		if command == null:
			continue

		ui.set_turn_text("Turno: %s" % _name_of(actor_id))
		var event := CombatRules.resolve_action(state, command, database)
		_log_event(event)
		_refresh_hp_display()
		CombatRules.check_combat_end(state)

		if not state.combat_over:
			await get_tree().create_timer(0.5).timeout

	if state.combat_over:
		_show_combat_end()
	else:
		_advance_phase(BattlePhaseMachine.END_OF_ROUND)
		_start_action_selection()


func _on_flee_pressed() -> void:
	if state.combat_over or state.battle_phase.current_phase() == BattlePhaseMachine.RESOLVING_ACTIONS:
		return
	_resolve_flee()


func _resolve_flee() -> void:
	if not _advance_phase(BattlePhaseMachine.RESOLVING_ACTIONS):
		return
	ui.clear_options()
	ui.set_turn_text("Equipe tenta fugir...")

	if CombatRules.attempt_flee():
		ui.log_message("Fugimos! Escapamos do combate.")
		queue_free()
		return

	ui.log_message("Tentativa de fuga falhou!")

	for enemy_id in state.get_alive_ids(state.enemy_ids):
		if state.combat_over:
			break
		var target_id := CombatRules.pick_random_alive_target_id(state, state.player_ids)
		if target_id == -1:
			continue
		var enemy := state.get_combatant(enemy_id)
		var attack_index := CombatRules.pick_random_attack_index(database, enemy.species_id)
		if attack_index == -1:
			continue

		ui.set_turn_text("Turno: %s" % _name_of(enemy_id))
		var command := ActionCommand.new(enemy_id, "attack", target_id, attack_index)
		var event := CombatRules.resolve_action(state, command, database)
		_log_event(event)
		_refresh_hp_display()
		CombatRules.check_combat_end(state)
		if state.combat_over:
			break
		await get_tree().create_timer(0.5).timeout

	if state.combat_over:
		_show_combat_end()
	else:
		_advance_phase(BattlePhaseMachine.END_OF_ROUND)
		_start_action_selection()


func _show_combat_end() -> void:
	ui.show_combat_end(state.player_won)


func _log_event(event: Dictionary) -> void:
	match event.get("kind"):
		"attack_miss":
			ui.log_message("%s usa %s em %s... e erra!" % [_name_of(event.actor_id), event.attack_name, _name_of(event.target_id)])
		"attack_hit":
			var crit_text := " CRITICO!" if event.critical else ""
			ui.log_message("%s usa %s em %s! %d de dano.%s" % [_name_of(event.actor_id), event.attack_name, _name_of(event.target_id), event.damage, crit_text])
		"item_used":
			ui.log_message("%s usa item em %s! Recupera %d HP." % [_name_of(event.actor_id), _name_of(event.target_id), event.amount])
		"capture_success":
			ui.log_message("%s captura %s! Retirado do combate." % [_name_of(event.actor_id), _name_of(event.target_id)])
		"capture_fail":
			ui.log_message("Tentativa de capturar %s falhou!" % _name_of(event.target_id))
		"cancelled":
			ui.log_message("Acao cancelada (%s)." % event.get("reason", "motivo desconhecido"))
