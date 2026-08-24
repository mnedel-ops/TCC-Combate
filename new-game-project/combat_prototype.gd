extends Control

const PLAYER_MAX_HP := 30
const ENEMY_MAX_HP := 30
const ATTACK_DAMAGE := 10
const MISS_CHANCE := 1.0 / 6.0
const FLEE_CHANCE := 5.0 / 6.0
const CAPTURE_CHANCE := 2.0 / 6.0
const ITEM_HEAL_AMOUNT := 6

@onready var log_label: Label = $VBoxContainer/LogLabel
@onready var hp_label: Label = $VBoxContainer/HPLabel
@onready var turn_label: Label = $VBoxContainer/TurnLabel
@onready var attack_button: Button = $VBoxContainer/AttackButton
@onready var flee_button: Button = $VBoxContainer/FleeButton
@onready var capture_button: Button = $VBoxContainer/CaptureButton
@onready var item_button: Button = $VBoxContainer/ItemButton

var player_hp := PLAYER_MAX_HP
var enemy_hp := ENEMY_MAX_HP
var combat_over := false
var is_resolving := false   # trava input enquanto a rodada resolve

var player_first := true    # decidido 1x, no inicio do combate, pela iniciativa

func _ready() -> void:
	attack_button.pressed.connect(_on_attack_pressed)
	flee_button.pressed.connect(_on_flee_pressed)
	capture_button.pressed.connect(_on_capture_pressed)
	item_button.pressed.connect(_on_item_pressed)
	_roll_initiative()
	_update_hp_label()
	turn_label.text = "Escolha uma acao para comecar."
	_log("Combate comecou!")

func _roll_initiative() -> void:
	var player_initiative := randi_range(1, 20)
	var enemy_initiative := randi_range(1, 20)

	while enemy_initiative == player_initiative:   # empate: rerola so o inimigo
		enemy_initiative = randi_range(1, 20)

	player_first = player_initiative > enemy_initiative

	_log("Iniciativa - Jogador: %d | Inimigo: %d" % [player_initiative, enemy_initiative])
	_log("Jogador comeca o combate." if player_first else "Inimigo comeca o combate.")

func _unhandled_input(event: InputEvent) -> void:
	if combat_over or is_resolving:
		return
	if event.is_action_pressed("menu_select"):
		_on_attack_pressed()

func _on_attack_pressed() -> void:
	if combat_over or is_resolving:
		return
	_resolve_round()

func _on_flee_pressed() -> void:
	if combat_over or is_resolving:
		return
	_resolve_flee()

func _on_capture_pressed() -> void:
	if combat_over or is_resolving:
		return
	_resolve_capture()

func _on_item_pressed() -> void:
	if combat_over or is_resolving:
		return
	_resolve_item_use()

# Ataque normal: respeita a ordem de iniciativa sorteada no inicio do combate.
func _resolve_round() -> void:
	is_resolving = true
	_set_buttons_disabled(true)

	if player_first:
		turn_label.text = "Turno: Jogador"
		_player_attack()
		if not combat_over:
			await get_tree().create_timer(0.6).timeout
			turn_label.text = "Turno: Inimigo"
			_enemy_attack()
	else:
		turn_label.text = "Turno: Inimigo"
		_enemy_attack()
		if not combat_over:
			await get_tree().create_timer(0.6).timeout
			turn_label.text = "Turno: Jogador"
			_player_attack()

	if not combat_over:
		turn_label.text = "Escolha uma acao."
		is_resolving = false
		_set_buttons_disabled(false)

func _resolve_flee() -> void:
	# Fuga ignora a iniciativa - sempre resolve primeiro, antes do turno do oponente.
	is_resolving = true
	_set_buttons_disabled(true)
	turn_label.text = "Turno: Jogador (fuga)"

	if randf() < FLEE_CHANCE:
		_log("Fugi! Escapei do combate.")
		queue_free()   # fecha a tela. Trocar por chamada ao SceneManager quando integrar.
		return

	_log("Tentativa de fuga falhou!")
	await _enemy_turn_after_player_action()

func _resolve_capture() -> void:
	# Captura tambem ignora a iniciativa, igual a fuga - acontece antes de tudo.
	is_resolving = true
	_set_buttons_disabled(true)
	turn_label.text = "Turno: Jogador (captura)"

	if randf() < CAPTURE_CHANCE:
		_log("Capturei a criatura! Combate encerrado.")
		queue_free()   # fecha a tela. Trocar por chamada ao SceneManager quando integrar.
		return

	_log("Tentativa de captura falhou!")
	await _enemy_turn_after_player_action()

func _resolve_item_use() -> void:
	# Usar item tambem ignora a iniciativa - acontece antes da acao de combate.
	is_resolving = true
	_set_buttons_disabled(true)
	turn_label.text = "Turno: Jogador (item)"

	player_hp = min(player_hp + ITEM_HEAL_AMOUNT, PLAYER_MAX_HP)
	_log("Usei um item de cura! Recuperei %d HP." % ITEM_HEAL_AMOUNT)
	_update_hp_label()

	await _enemy_turn_after_player_action()

# Usado por fuga/captura/item quando a tentativa nao encerra o combate:
# a acao ja consumiu a rodada, entao o inimigo age em seguida, sem checar iniciativa.
func _enemy_turn_after_player_action() -> void:
	await get_tree().create_timer(0.6).timeout
	turn_label.text = "Turno: Inimigo"
	_enemy_attack()

	if not combat_over:
		turn_label.text = "Escolha uma acao."
		is_resolving = false
		_set_buttons_disabled(false)

func _player_attack() -> void:
	if randf() < MISS_CHANCE:
		_log("Jogador ataca... e erra!")
	else:
		enemy_hp = max(enemy_hp - ATTACK_DAMAGE, 0)
		_log("Jogador ataca! Inimigo leva %d de dano." % ATTACK_DAMAGE)
	_update_hp_label()

	if enemy_hp <= 0:
		_end_combat(true)

func _enemy_attack() -> void:
	if randf() < MISS_CHANCE:
		_log("Inimigo ataca... e erra!")
	else:
		player_hp = max(player_hp - ATTACK_DAMAGE, 0)
		_log("Inimigo ataca! Jogador leva %d de dano." % ATTACK_DAMAGE)
	_update_hp_label()

	if player_hp <= 0:
		_end_combat(false)

func _end_combat(player_won: bool) -> void:
	combat_over = true
	_set_buttons_disabled(true)
	turn_label.text = "Fim de combate."
	_log("Vitoria!" if player_won else "Derrota!")

func _set_buttons_disabled(value: bool) -> void:
	attack_button.disabled = value
	flee_button.disabled = value
	capture_button.disabled = value
	item_button.disabled = value

func _update_hp_label() -> void:
	hp_label.text = "Jogador: %d HP   |   Inimigo: %d HP" % [player_hp, enemy_hp]

func _log(text: String) -> void:
	log_label.text += "\n" + text
