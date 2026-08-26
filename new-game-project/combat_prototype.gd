extends Control

## Controller: so orquestra. Le input, chama CombatSystem, mostra resultado.
## Nao tem regra de jogo aqui - toda regra mora em CombatSystem.
## Dado mora em AlchemonSheet/PendingActionData (Resources em arquivo separado).

@onready var log_label: Label = $VBoxContainer/LogLabel
@onready var hp_label: Label = $VBoxContainer/HPLabel
@onready var turn_label: Label = $VBoxContainer/TurnLabel
@onready var action_buttons: VBoxContainer = $VBoxContainer/ActionButtons
@onready var flee_button: Button = $VBoxContainer/FleeButton

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

	flee_button.pressed.connect(_on_flee_pressed)

	turn_order = CombatSystem.roll_initiative(player_team + enemy_team)
	_log_initiative_order()

	_update_hp_label()
	_log("Combate comecou! 2 contra 2.")
	_start_action_selection()


func _log_initiative_order() -> void:
	var order_text := ""
	for c in turn_order:
		order_text += "%s (%d)  " % [c.creature_name, c.initiative]
	_log("Ordem de iniciativa: " + order_text)


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

	turn_label.text = "Acao de %s:" % actor.creature_name
	_clear_action_buttons()

	_add_action_button("Atacar", func(): _begin_target_selection(actor, "attack"))
	_add_action_button("Item", func(): _begin_target_selection(actor, "item"))
	_add_action_button("Capturar", func(): _begin_target_selection(actor, "capture"))


func _begin_target_selection(actor: AlchemonSheet, kind: String) -> void:
	_clear_action_buttons()

	var candidates: Array[AlchemonSheet] = []
	match kind:
		"attack", "capture":
			candidates = enemy_team.filter(func(c): return c.alive)
		"item":
			candidates = player_team.filter(func(c): return c.alive)

	turn_label.text = "%s: escolha o alvo" % actor.creature_name
	for target in candidates:
		_add_action_button(
			"%s (%d/%d HP)" % [target.creature_name, target.hp, target.max_hp],
			func(): _confirm_action(actor, kind, target)
		)


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
	_clear_action_buttons()
	_set_flee_disabled(true)

	for combatant in turn_order:
		if combat_over:
			break
		if not combatant.alive:
			continue

		var action := _find_pending_action(combatant)
		if action == null:
			continue
		if not action.target.alive:
			_log("%s nao tem mais alvo valido, acao cancelada." % combatant.creature_name)
			continue

		turn_label.text = "Turno: %s" % combatant.creature_name
		_execute_action(action)
		_update_hp_label()
		_check_combat_end()

		if not combat_over:
			await get_tree().create_timer(0.5).timeout

	if not combat_over:
		is_resolving = false
		_set_flee_disabled(false)
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
	_clear_action_buttons()
	_set_flee_disabled(true)
	turn_label.text = "Equipe tenta fugir..."

	if CombatSystem.attempt_flee():
		_log("Fugimos! Escapamos do combate.")
		queue_free()
		return

	_log("Tentativa de fuga falhou!")

	for enemy in enemy_team:
		if not enemy.alive or combat_over:
			continue
		var target := CombatSystem.pick_random_alive_target(player_team)
		if target == null:
			continue

		turn_label.text = "Turno: %s" % enemy.creature_name
		_log_result(CombatSystem.resolve_attack(enemy, target))
		_update_hp_label()
		_check_combat_end()
		if combat_over:
			break
		await get_tree().create_timer(0.5).timeout

	if not combat_over:
		is_resolving = false
		_set_flee_disabled(false)
		_start_action_selection()


func _end_combat(player_won: bool) -> void:
	combat_over = true
	_clear_action_buttons()
	_set_flee_disabled(true)
	turn_label.text = "Fim de combate."
	_log("Vitoria!" if player_won else "Derrota!")


# Unico lugar que traduz resultado (Dictionary) -> texto. Trocar apresentacao
# (som, animacao, outro idioma) muda so aqui, nunca no CombatSystem.
func _log_result(result: Dictionary) -> void:
	match result.kind:
		"attack_miss":
			_log("%s ataca %s... e erra!" % [result.actor.creature_name, result.target.creature_name])
		"attack_hit":
			_log("%s ataca %s! %d de dano." % [result.actor.creature_name, result.target.creature_name, result.damage])
		"item_used":
			_log("%s usa item em %s! Recupera %d HP." % [result.actor.creature_name, result.target.creature_name, result.amount])
		"capture_success":
			_log("%s captura %s! Retirado do combate." % [result.actor.creature_name, result.target.creature_name])
		"capture_fail":
			_log("Tentativa de capturar %s falhou!" % result.target.creature_name)


func _set_flee_disabled(value: bool) -> void:
	if is_instance_valid(flee_button):
		flee_button.disabled = value


func _add_action_button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	action_buttons.add_child(button)


func _clear_action_buttons() -> void:
	for child in action_buttons.get_children():
		child.queue_free()


func _update_hp_label() -> void:
	var text := ""
	for c in player_team:
		text += "%s: %d/%d HP   " % [c.creature_name, c.hp, c.max_hp]
	text += "\n"
	for c in enemy_team:
		text += "%s: %d/%d HP   " % [c.creature_name, c.hp, c.max_hp]
	hp_label.text = text


func _log(text: String) -> void:
	log_label.text += "\n" + text
