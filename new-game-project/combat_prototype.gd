extends Control

@onready var ui: CombatUI = $VBoxContainer

@export var database: AlchemonDatabase
@export var player_alchemon_ids: Array[int] = []
@export var enemy_alchemon_ids: Array[int] = []
@export var rng_seed: int = 1337

var combat_state: Dictionary = {}


func _ready() -> void:
	var player_templates := _build_team_templates(player_alchemon_ids)
	var enemy_templates := _build_team_templates(enemy_alchemon_ids)

	if player_templates.is_empty() or enemy_templates.is_empty():
		push_error("CombatController: time vazio. Confere database e os arrays de ids no Inspector.")
		ui.set_turn_text("Erro de configuracao - veja o console.")
		return

	combat_state = CombatSystem.initialize_state(player_templates, enemy_templates, rng_seed)
	ui.clear_log()
	ui.log_message("Combate comecou! %d contra %d." % [player_templates.size(), enemy_templates.size()])
	_log_initiative_order()
	_refresh_ui()
	_advance_flow()


func _build_team_templates(ids: Array[int]) -> Array:
	var team: Array = []
	if database == null:
		push_error("CombatController: nenhum AlchemonDatabase atribuido no Inspector.")
		return team

	for id in ids:
		var template := database.get_by_id(id)
		if template == null:
			continue
		team.append(_sheet_to_template(template))

	return team


func _sheet_to_template(sheet: AlchemonSheet) -> Dictionary:
	var attacks: Array = []
	for attack in sheet.attacks:
		if attack == null:
			continue
		attacks.append({
			"attack_name": attack.attack_name,
			"damage": attack.damage,
		})

	return {
		"species_id": sheet.id,
		"creature_name": sheet.creature_name,
		"max_hp": sheet.max_hp,
		"attacks": attacks,
	}


func _advance_flow() -> void:
	if combat_state.is_empty() or bool(combat_state.get("combat_over", false)):
		_show_combat_end_if_needed()
		return

	match String(combat_state.get("phase", "")):
		"selecting_actions":
			var actor_id := CombatSystem.get_current_player_actor_id(combat_state)
			if actor_id == -1:
				return
			_show_action_menu_for_actor(actor_id)
		"resolving_round":
			_dispatch_command({"type": "resolve_round"})
		_:
			return


func _show_action_menu_for_actor(actor_id: int) -> void:
	var actor := CombatSystem.get_combatant(combat_state, actor_id)
	if actor.is_empty():
		return

	ui.show_action_menu(actor, func(kind: String):
		match kind:
			"flee":
				_dispatch_command({"type": "attempt_flee", "actor_id": actor_id})
			"attack":
				ui.show_attack_submenu(
					actor,
					func(attack_index: int): _show_target_selection(actor_id, kind, attack_index),
					func(): _show_action_menu_for_actor(actor_id)
				)
			_:
				_show_target_selection(actor_id, kind, -1)
	)


func _show_target_selection(actor_id: int, kind: String, attack_index: int) -> void:
	var targets: Array[int] = CombatSystem.get_valid_targets(combat_state, actor_id, kind)
	if targets.is_empty():
		ui.log_message("Nenhum alvo valido para %s." % kind)
		_show_action_menu_for_actor(actor_id)
		return

	var actor := CombatSystem.get_combatant(combat_state, actor_id)
	ui.set_turn_text("%s: escolha o alvo" % String(actor.get("creature_name", "")))

	var options: Array = []
	for target_id in targets:
		var target := CombatSystem.get_combatant(combat_state, target_id)
		options.append({
			"text": "%s (%d/%d HP)" % [
				String(target.get("creature_name", "")),
				int(target.get("hp", 0)),
				int(target.get("max_hp", 0)),
			],
			"callback": func(chosen_target_id=target_id):
				_dispatch_command({
					"type": "queue_action",
					"actor_id": actor_id,
					"kind": kind,
					"target_id": chosen_target_id,
					"attack_index": attack_index,
				})
		})

	options.append({
		"text": "Voltar",
		"callback": func(): _show_action_menu_for_actor(actor_id),
	})
	ui.show_options(options)


func _dispatch_command(command: Dictionary) -> void:
	var result := CombatSystem.apply_command(combat_state, command)
	combat_state = result.get("state", combat_state)
	_refresh_ui()
	_log_events(result.get("events", []))
	_show_combat_end_if_needed()
	if not bool(combat_state.get("combat_over", false)):
		_advance_flow()


func _refresh_ui() -> void:
	ui.update_from_state(combat_state)


func _log_initiative_order() -> void:
	var order_ids: Array = combat_state.get("turn_order_ids", [])
	var order_text := ""
	for combatant_id in order_ids:
		var combatant := CombatSystem.get_combatant(combat_state, int(combatant_id))
		order_text += "%s (%d)  " % [
			String(combatant.get("creature_name", "")),
			int(combatant.get("initiative", 0)),
		]
	ui.log_message("Ordem de iniciativa: " + order_text)


func _log_events(events: Array) -> void:
	for event in events:
		_log_event(event)


func _log_event(event: Dictionary) -> void:
	var kind := String(event.get("kind", ""))
	match kind:
		"attack_miss":
			ui.log_message("%s usa %s em %s... e erra!" % [
				_name_of(int(event.get("actor_id", -1))),
				String(event.get("attack_name", "Ataque")),
				_name_of(int(event.get("target_id", -1))),
			])
		"attack_hit":
			var crit_text := " CRITICO!" if bool(event.get("critical", false)) else ""
			ui.log_message("%s usa %s em %s! %d de dano.%s" % [
				_name_of(int(event.get("actor_id", -1))),
				String(event.get("attack_name", "Ataque")),
				_name_of(int(event.get("target_id", -1))),
				int(event.get("damage", 0)),
				crit_text,
			])
		"item_used":
			ui.log_message("%s usa item em %s! Recupera %d HP." % [
				_name_of(int(event.get("actor_id", -1))),
				_name_of(int(event.get("target_id", -1))),
				int(event.get("amount", 0)),
			])
		"capture_success":
			ui.log_message("%s captura %s! Retirado do combate." % [
				_name_of(int(event.get("actor_id", -1))),
				_name_of(int(event.get("target_id", -1))),
			])
		"capture_fail":
			ui.log_message("Tentativa de capturar %s falhou!" % _name_of(int(event.get("target_id", -1))))
		"action_rejected":
			ui.log_message("Acao rejeitada: %s" % String(event.get("reason", "invalida")))
		"action_cancelled":
			ui.log_message("Acao cancelada: %s" % String(event.get("reason", "sem alvo")))
		"flee_attempted":
			ui.log_message("Equipe tenta fugir...")
		"flee_failed":
			ui.log_message("Tentativa de fuga falhou!")
		"flee_success":
			ui.log_message("Fugimos! Escapamos do combate.")
		"round_started":
			ui.log_message("--- Rodada %d ---" % int(event.get("round_number", 0)))
		"turn_start":
			ui.set_turn_text("Turno: %s" % _name_of(int(event.get("actor_id", -1))))
		"combatant_defeated":
			ui.log_message("%s caiu." % _name_of(int(event.get("combatant_id", -1))))
		"combat_end":
			var outcome := String(event.get("outcome", "combat_end"))
			ui.log_message("Combate encerrado: %s" % outcome)
		_:
			pass


func _name_of(combatant_id: int) -> String:
	var combatant := CombatSystem.get_combatant(combat_state, combatant_id)
	return String(combatant.get("creature_name", "desconhecido"))


func _show_combat_end_if_needed() -> void:
	if not bool(combat_state.get("combat_over", false)):
		return
	ui.show_combat_end(String(combat_state.get("outcome", "combat_end")))
