extends Control

const MAX_HP := 30
const ATTACK_DAMAGE := 10
const MISS_CHANCE := 1.0 / 6.0
const FLEE_CHANCE := 5.0 / 6.0
const CAPTURE_CHANCE := 2.0 / 6.0
const ITEM_HEAL_AMOUNT := 6

class Combatant:
	var display_name: String
	var hp: int
	var max_hp: int
	var is_player: bool
	var initiative: int
	var alive := true

	func _init(name_: String, hp_: int, is_player_: bool) -> void:
		display_name = name_
		hp = hp_
		max_hp = hp_
		is_player = is_player_

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var turn_label: Label = $VBoxContainer/TurnLabel
@onready var log_label: Label = $VBoxContainer/LogLabel
@onready var attack_button: Button = $VBoxContainer/ActionButtons/AttackButton
@onready var item_button: Button = $VBoxContainer/ActionButtons/ItemButton
@onready var capture_button: Button = $VBoxContainer/ActionButtons/CaptureButton
@onready var flee_button: Button = $VBoxContainer/ActionButtons/FleeButton
@onready var target_buttons: HBoxContainer = $VBoxContainer/TargetButtons

var player_team: Array[Combatant] = []
var enemy_team: Array[Combatant] = []
var turn_queue: Array[Combatant] = []

var turn_index := 0
var active: Combatant
var pending_action: String = ""   # "attack" | "item" | "capture" | ""
var combat_over := false
var is_resolving := false

func _ready() -> void:
	attack_button.pressed.connect(func(): _start_targeting("attack"))
	item_button.pressed.connect(func(): _start_targeting("item"))
	capture_button.pressed.connect(func(): _start_targeting("capture"))
	flee_button.pressed.connect(_on_flee_pressed)

	player_team = [
		Combatant.new("Jogador 1", MAX_HP, true),
		Combatant.new("Jogador 2", MAX_HP, true),
	]
	enemy_team = [
		Combatant.new("Inimigo 1", MAX_HP, false),
		Combatant.new("Inimigo 2", MAX_HP, false),
	]

	_roll_initiative()
	_update_status_label()
	_log("Combate comecou! Ordem de turno: %s" % _queue_names())

	active = turn_queue[turn_index]
	_start_turn()

func _roll_initiative() -> void:
	var all: Array[Combatant] = player_team + enemy_team
	var used_values: Array[int] = []

	for c in all:
		var value := randi_range(1, 20)
		while used_values.has(value):          # evita empate, cada criatura rola sozinha
			value = randi_range(1, 20)
		used_values.append(value)
		c.initiative = value

	all.sort_custom(func(a, b): return a.initiative > b.initiative)
	turn_queue = all

func _queue_names() -> String:
	var names: Array[String] = []
	for c in turn_queue:
		names.append("%s(%d)" % [c.display_name, c.initiative])
	return " > ".join(names)

func _start_turn() -> void:
	if active.is_player:
		turn_label.text = "Turno de %s - escolha uma acao." % active.display_name
		_set_action_buttons_disabled(false)
	else:
		turn_label.text = "Turno de %s..." % active.display_name
		_set_action_buttons_disabled(true)
		is_resolving = true
		await get_tree().create_timer(0.6).timeout
		_enemy_take_turn(active)

func _on_flee_pressed() -> void:
	if combat_over or is_resolving:
		return
	# Fuga e' da equipe inteira, ignora fila - substitui a acao do turno ativo.
	is_resolving = true
	_set_action_buttons_disabled(true)
	turn_label.text = "%s tenta fugir com o grupo..." % active.display_name

	if randf() < FLEE_CHANCE:
		_log("Fugimos! Escapamos do combate.")
		queue_free()   # fecha a tela. Trocar por chamada ao SceneManager quando integrar.
		return

	_log("Tentativa de fuga falhou!")
	await get_tree().create_timer(0.4).timeout
	_advance_turn()

func _start_targeting(action: String) -> void:
	if combat_over or is_resolving:
		return
	pending_action = action
	_set_action_buttons_disabled(true)

	var targets: Array[Combatant]
	if action == "item":
		targets = player_team.filter(func(c): return c.alive)   # cura alcanca aliados vivos
	else:
		targets = enemy_team.filter(func(c): return c.alive)    # ataque/captura miram inimigos

	_show_target_buttons(targets)

func _show_target_buttons(targets: Array[Combatant]) -> void:
	for child in target_buttons.get_children():
		child.queue_free()

	for target in targets:
		var button := Button.new()
		button.text = "%s (%d/%d HP)" % [target.display_name, target.hp, target.max_hp]
		button.pressed.connect(_on_target_chosen.bind(target))
		target_buttons.add_child(button)

	target_buttons.visible = true

func _on_target_chosen(target: Combatant) -> void:
	target_buttons.visible = false
	for child in target_buttons.get_children():
		child.queue_free()

	is_resolving = true

	match pending_action:
		"attack":
			_resolve_attack(active, target)
		"item":
			_resolve_item(target)
		"capture":
			_resolve_capture(target)

	pending_action = ""
	_after_action()

func _resolve_attack(attacker: Combatant, target: Combatant) -> void:
	if randf() < MISS_CHANCE:
		_log("%s ataca %s... e erra!" % [attacker.display_name, target.display_name])
		return

	target.hp = max(target.hp - ATTACK_DAMAGE, 0)
	_log("%s ataca %s! %d de dano." % [attacker.display_name, target.display_name, ATTACK_DAMAGE])

	if target.hp <= 0:
		target.alive = false
		_log("%s foi derrotado!" % target.display_name)

func _resolve_item(target: Combatant) -> void:
	target.hp = min(target.hp + ITEM_HEAL_AMOUNT, target.max_hp)
	_log("%s usa um item de cura em %s! Recupera %d HP." % [active.display_name, target.display_name, ITEM_HEAL_AMOUNT])

func _resolve_capture(target: Combatant) -> void:
	if randf() < CAPTURE_CHANCE:
		target.alive = false
		_log("Capturei %s!" % target.display_name)
	else:
		_log("Tentativa de capturar %s falhou!" % target.display_name)

func _enemy_take_turn(enemy: Combatant) -> void:
	var alive_players := player_team.filter(func(c): return c.alive)
	if alive_players.is_empty():
		return   # _check_combat_end ja deve ter fechado o combate antes disso
	var target: Combatant = alive_players[randi() % alive_players.size()]
	_resolve_attack(enemy, target)
	_after_action()

func _after_action() -> void:
	_update_status_label()
	if _check_combat_end():
		return
	_advance_turn()

func _advance_turn() -> void:
	turn_index = wrapi(turn_index + 1, 0, turn_queue.size())
	while not turn_queue[turn_index].alive:
		turn_index = wrapi(turn_index + 1, 0, turn_queue.size())

	active = turn_queue[turn_index]
	is_resolving = false
	_start_turn()

func _check_combat_end() -> bool:
	var players_alive := player_team.any(func(c): return c.alive)
	var enemies_alive := enemy_team.any(func(c): return c.alive)

	if not enemies_alive:
		_end_combat(true)
		return true
	if not players_alive:
		_end_combat(false)
		return true
	return false

func _end_combat(player_won: bool) -> void:
	combat_over = true
	is_resolving = true
	_set_action_buttons_disabled(true)
	turn_label.text = "Fim de combate."
	_log("Vitoria!" if player_won else "Derrota!")

func _set_action_buttons_disabled(value: bool) -> void:
	attack_button.disabled = value
	item_button.disabled = value
	capture_button.disabled = value
	flee_button.disabled = value

func _update_status_label() -> void:
	var parts: Array[String] = []
	for c in player_team:
		parts.append("%s: %d/%d" % [c.display_name, c.hp, c.max_hp])
	parts.append("||")
	for c in enemy_team:
		parts.append("%s: %d/%d" % [c.display_name, c.hp, c.max_hp])
	status_label.text = " | ".join(parts)

func _log(text: String) -> void:
	log_label.text += "\n" + text
