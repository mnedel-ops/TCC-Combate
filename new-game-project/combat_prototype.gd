extends Control

## Controller: so orquestra. Le eventos da CombatUI, chama CombatSystem,
## manda resultado de volta pra CombatUI mostrar. Sem regra de jogo aqui
## (mora em CombatSystem) e sem manipulacao de Label/Button aqui (mora em CombatUI).

@onready var ui: CombatUI = $VBoxContainer

var player_team: Array[AlchemonSheet] = []
var enemy_team: Array[AlchemonSheet] = []
var turn_order: Array[AlchemonSheet] = []

var combat_over := false
var is_resolving := false

var _pending_actions: Array[PendingActionData] = []
var _current_player_index := 0


func _ready() -> void:
	player_team = [
		AlchemonSheet.new("Criatura A", 30, true),
		AlchemonSheet.new("Criatura B", 30, true),
	]
	enemy_team = [
		AlchemonSheet.new("Inimigo A", 30, false),
		AlchemonSheet.new("Inimigo B", 30, false),
	]

	ui.flee_pressed.connect(_on_flee_pressed)

	turn_order = CombatSystem.roll_initiative(player_team + enemy_team)
	_log_initiative_order()

	ui.update_hp(player_team, enemy_team)
	ui.log_message("Combate comecou! 2 contra 2.")
	_start_action_selection()


func _log_initiative_order() -> void:
	var order_text := ""
	for c in turn_order:
		order_text += "%s (%d)  " % [c.creature_name, c.initiative]
	ui.log_message("Ordem de iniciativa: " + order_text)


func _start_action_selection() -> void:
	_pending_actions.clear()
	_current_player_index = 0
	_prompt_action_for_current_creature()


func _prompt_action_for_current_creature() -> void:
	if _current_player_index >= player_team.size():
		_queue_enemy_actions()
		_resolve_round()
		return

	var actor := player_team[_current_player_index]
	if not actor.alive:
		_current_player_index += 1
		_prompt_action_for_current_creature()
		return

	ui.set_turn_text("Acao de %s:" % actor.creature_name)
	ui.show_options([
		{"text": "Atacar", "callback": func(): _begin_target_selection(actor, "attack")},
		{"text": "Item", "callback": func(): _begin_target_selection(actor, "item")},
		{"text": "Capturar", "callback": func(): _begin_target_selection(actor, "capture")},
	])


func _begin_target_selection(actor: AlchemonSheet, kind: String) -> void:
	var candidates: Array[AlchemonSheet] = []
	match kind:
		"attack", "capture":
			candidates = enemy_team.filter(func(c): return c.alive)
		"item":
			candidates = player_team.filter(func(c): return c.alive)

	ui.set_turn_text("%s: escolha o alvo" % actor.creature_name)

	var options: Array = []
	for target in candidates:
		options.append({
			"text": "%s (%d/%d HP)" % [target.creature_name, target.hp, target.max_hp],
			"callback": func(): _confirm_action(actor, kind, target),
		})
	ui.show_options(options)


func _confirm_action(actor: AlchemonSheet, kind: String, target: AlchemonSheet) -> void:
	_pending_actions.append(PendingActionData.new(actor, kind, target))
	_current_player_index += 1
	_prompt_action_for_current_creature()


func _queue_enemy_actions() -> void:
	for enemy in enemy_team:
		if not enemy.alive:
			continue
		var target := CombatSystem.pick_random_alive_target(player_team)
		if target == null:
			continue
		_pending_actions.append(PendingActionData.new(enemy, "attack", target))


func _resolve_round() -> void:
	is_resolving = true
	ui.clear_options()
	ui.set_flee_disabled(true)

	for combatant in turn_order:
		if combat_over:
			break
		if not combatant.alive:
			continue

		var action := _find_pending_action(combatant)
		if action == null:
			continue
		if not action.target.alive:
			ui.log_message("%s nao tem mais alvo valido, acao cancelada." % combatant.creature_name)
			continue

		ui.set_turn_text("Turno: %s" % combatant.creature_name)
		_execute_action(action)
		ui.update_hp(player_team, enemy_team)
		_check_combat_end()

		if not combat_over:
			await get_tree().create_timer(0.5).timeout

	if not combat_over:
		is_resolving = false
		ui.set_flee_disabled(false)
		_start_action_selection()


func _find_pending_action(combatant: AlchemonSheet) -> PendingActionData:
	for action in _pending_actions:
		if action.actor == combatant:
			return action
	return null


func _execute_action(action: PendingActionData) -> void:
	var result: Dictionary
	match action.kind:
		"attack":
			result = CombatSystem.resolve_attack(action.actor, action.target)
		"item":
			result = CombatSystem.resolve_item(action.actor, action.target)
		"capture":
			result = CombatSystem.resolve_capture(action.actor, action.target)
	_log_result(result)


func _check_combat_end() -> void:
	if not CombatSystem.is_team_alive(player_team):
		_end_combat(false)
	elif not CombatSystem.is_team_alive(enemy_team):
		_end_combat(true)


func _on_flee_pressed() -> void:
	if combat_over or is_resolving:
		return
	_resolve_flee()


func _resolve_flee() -> void:
	is_resolving = true
	ui.clear_options()
	ui.set_flee_disabled(true)
	ui.set_turn_text("Equipe tenta fugir...")

	if CombatSystem.attempt_flee():
		ui.log_message("Fugimos! Escapamos do combate.")
		queue_free()
		return

	ui.log_message("Tentativa de fuga falhou!")

	for enemy in enemy_team:
		if not enemy.alive or combat_over:
			continue
		var target := CombatSystem.pick_random_alive_target(player_team)
		if target == null:
			continue

		ui.set_turn_text("Turno: %s" % enemy.creature_name)
		_log_result(CombatSystem.resolve_attack(enemy, target))
		ui.update_hp(player_team, enemy_team)
		_check_combat_end()
		if combat_over:
			break
		await get_tree().create_timer(0.5).timeout

	if not combat_over:
		is_resolving = false
		ui.set_flee_disabled(false)
		_start_action_selection()


func _end_combat(player_won: bool) -> void:
	combat_over = true
	ui.show_combat_end(player_won)


# Unico lugar que traduz resultado (Dictionary) -> texto pra CombatUI.
func _log_result(result: Dictionary) -> void:
	match result.kind:
		"attack_miss":
			ui.log_message("%s ataca %s... e erra!" % [result.actor.creature_name, result.target.creature_name])
		"attack_hit":
			ui.log_message("%s ataca %s! %d de dano." % [result.actor.creature_name, result.target.creature_name, result.damage])
		"item_used":
			ui.log_message("%s usa item em %s! Recupera %d HP." % [result.actor.creature_name, result.target.creature_name, result.amount])
		"capture_success":
			ui.log_message("%s captura %s! Retirado do combate." % [result.actor.creature_name, result.target.creature_name])
		"capture_fail":
			ui.log_message("Tentativa de capturar %s falhou!" % result.target.creature_name)
