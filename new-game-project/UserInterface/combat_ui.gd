class_name CombatUI
extends VBoxContainer

@onready var log_label: Label = $LogLabel
@onready var hp_label: Label = $HPLabel
@onready var turn_label: Label = $TurnLabel
@onready var action_buttons: VBoxContainer = $ActionButtons


func log_message(text: String) -> void:
	log_label.text += "\n" + text


func clear_log() -> void:
	log_label.text = ""


func set_turn_text(text: String) -> void:
	turn_label.text = text


func update_from_state(state: Dictionary) -> void:
	var combatants: Dictionary = state.get("combatants", {})
	var player_team_ids: Array = state.get("player_team_ids", [])
	var enemy_team_ids: Array = state.get("enemy_team_ids", [])

	var text := ""
	for combatant_id in player_team_ids:
		var combatant: Dictionary = combatants.get(int(combatant_id), {})
		text += _build_hp_line(combatant) + "   "

	text += "\n"
	for combatant_id in enemy_team_ids:
		var combatant: Dictionary = combatants.get(int(combatant_id), {})
		text += _build_hp_line(combatant) + "   "

	hp_label.text = text


func show_options(options: Array) -> void:
	clear_options()
	for option in options:
		var button := Button.new()
		button.text = String(option.get("text", ""))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(option.get("callback", func(): pass))
		action_buttons.add_child(button)


func clear_options() -> void:
	for child in action_buttons.get_children():
		child.queue_free()


func show_combat_end(outcome: String) -> void:
	set_turn_text("Fim de combate.")
	match outcome:
		"victory":
			log_message("Vitoria!")
		"defeat":
			log_message("Derrota!")
		"fled":
			log_message("Fuga bem-sucedida!")
		_:
			log_message("Combate encerrado.")
	clear_options()


func show_action_menu(actor: Dictionary, action_callback: Callable) -> void:
	set_turn_text("Acao de %s:" % String(actor.get("creature_name", "")))

	var options: Array = [
		{"text": "Ataque", "callback": func(): action_callback.call("attack")},
		{"text": "Item", "callback": func(): action_callback.call("item")},
		{"text": "Capturar", "callback": func(): action_callback.call("capture")},
		{"text": "Fugir", "callback": func(): action_callback.call("flee")},
	]
	show_options(options)


func show_attack_submenu(actor: Dictionary, attack_callback: Callable, back_callback: Callable) -> void:
	set_turn_text("Escolha um ataque:")

	var options: Array = []
	var attacks: Array = actor.get("attacks", [])
	for i in range(attacks.size()):
		var attack: Dictionary = attacks[i]
		options.append({
			"text": String(attack.get("attack_name", "Ataque")),
			"callback": func(index=i): attack_callback.call(index),
		})

	options.append({
		"text": "Voltar",
		"callback": func(): back_callback.call(),
	})
	show_options(options)


func _build_hp_line(combatant: Dictionary) -> String:
	if combatant.is_empty():
		return ""
	var fainted := " (KO)" if not bool(combatant.get("alive", false)) else ""
	return "%s: %d/%d HP%s" % [
		String(combatant.get("creature_name", "")),
		int(combatant.get("hp", 0)),
		int(combatant.get("max_hp", 0)),
		fainted,
	]
