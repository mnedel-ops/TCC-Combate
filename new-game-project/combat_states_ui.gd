class_name CombatUI_states
extends VBoxContainer

## Gerencia TODA a apresentacao do combate: log, HP, texto de turno, botoes.
## Nao decide regra nenhuma - so mostra o que o Controller manda. Botoes
## (incluindo Fugir) sao todos instanciados dinamicamente via show_options.

@onready var log_label: Label = $LogLabel
@onready var hp_label: Label = $HPLabel
@onready var turn_label: Label = $TurnLabel
@onready var action_buttons: VBoxContainer = $ActionButtons


func log_message(text: String) -> void:
	log_label.text += "\n" + text


func set_turn_text(text: String) -> void:
	turn_label.text = text


func update_hp(player_team: Array[AlchemonSheet], enemy_team: Array[AlchemonSheet]) -> void:
	var text := ""
	for c in player_team:
		text += "%s: %d/%d HP   " % [c.creature_name, c.hp, c.max_hp]
	text += "\n"
	for c in enemy_team:
		text += "%s: %d/%d HP   " % [c.creature_name, c.hp, c.max_hp]
	hp_label.text = text


# Versao V2, sem depender de AlchemonSheet - recebe so {name, hp, max_hp}.
# CombatUI nao precisa saber se o chamador usa referencia direta (V1) ou
# CombatState por id (V2); so entende Dictionary generico.
func update_hp_dict(player_entries: Array[Dictionary], enemy_entries: Array[Dictionary]) -> void:
	var text := ""
	for e in player_entries:
		text += "%s: %d/%d HP   " % [e.name, e.hp, e.max_hp]
	text += "\n"
	for e in enemy_entries:
		text += "%s: %d/%d HP   " % [e.name, e.hp, e.max_hp]
	hp_label.text = text


# options: Array de {"text": String, "callback": Callable}
func show_options(options: Array) -> void:
	clear_options()
	for option in options:
		var button := Button.new()
		button.text = option.text
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(option.callback)
		action_buttons.add_child(button)


func clear_options() -> void:
	for child in action_buttons.get_children():
		child.queue_free()


func show_combat_end(player_won: bool) -> void:
	set_turn_text("Fim de combate.")
	log_message("Vitoria!" if player_won else "Derrota!")
	clear_options()
