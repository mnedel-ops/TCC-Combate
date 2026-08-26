extends Control

const MAX_HP := 30
const ATTACK_DAMAGE := 10
const MISS_CHANCE := 1.0 / 6.0
const FLEE_CHANCE := 5.0 / 6.0
const CAPTURE_CHANCE := 2.0 / 6.0
const ITEM_HEAL_AMOUNT := 6

@export var alchemon : alchemon_sheet

# Uma criatura em combate (jogador ou inimiga).
class Combatant:
	var creature_name: String
	var max_hp: int
	var hp: int
	var is_player: bool
	var initiative: int
	var alive: bool = true

	func _init(p_name: String, p_max_hp: int, p_is_player: bool) -> void:
		creature_name = p_name
		max_hp = p_max_hp
		hp = p_max_hp
		is_player = p_is_player

	func take_damage(amount: int) -> void:
		hp = max(hp - amount, 0)
		if hp == 0:
			alive = false

	func heal(amount: int) -> void:
		hp = min(hp + amount, max_hp)

# Uma acao escolhida pra essa rodada (ator + tipo + alvo).
class PendingAction:
	var actor: Combatant
	var kind: String
	var target: Combatant

	func _init(p_actor: Combatant, p_kind: String, p_target: Combatant) -> void:
		actor = p_actor
		kind = p_kind
		target = p_target

@onready var log_label: Label = $VBoxContainer/LogLabel
@onready var hp_label: Label = $VBoxContainer/HPLabel
@onready var turn_label: Label = $VBoxContainer/TurnLabel
@onready var action_buttons: VBoxContainer = $VBoxContainer/ActionButtons
@onready var flee_button: Button = $VBoxContainer/FleeButton

var player_team: Array[Combatant] = []
var enemy_team: Array[Combatant] = []
var turn_order: Array[Combatant] = []   # ordenado por iniciativa, decidido 1x no inicio

var combat_over := false
var is_resolving := false

var _pending_actions: Array[PendingAction] = []
var _current_player_index := 0   # qual criatura do jogador esta escolhendo agora


func _ready() -> void:
	player_team = [
		Combatant.new(alchemon.name, alchemon.max_hp, true),
		Combatant.new("Criatura B", MAX_HP, true),
	]
	enemy_team = [
		Combatant.new("Inimigo A", MAX_HP, false),
		Combatant.new("Inimigo B", MAX_HP, false),
	]

	flee_button.pressed.connect(_on_flee_pressed)

	_roll_initiative()
	_update_hp_label()
	_log("Combate comecou! 2 contra 2.")
	_start_action_selection()


func _roll_initiative() -> void:
	# Cada criatura rola a propria iniciativa, independente das outras.
	var all: Array[Combatant] = player_team + enemy_team
	for c in all:
		c.initiative = randi_range(1, 20)

	all.sort_custom(func(a, b): return a.initiative > b.initiative)
	turn_order = all

	var order_text := ""
	for c in turn_order:
		order_text += "%s (%d)  " % [c.creature_name, c.initiative]
	_log("Ordem de iniciativa: " + order_text)


func _start_action_selection() -> void:
	_pending_actions.clear()
	_current_player_index = 0
	_prompt_action_for_current_creature()


# Pede acao pra cada criatura VIVA do jogador, uma de cada vez.
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


# Atacar/Capturar miram inimigos vivos. Item mira criaturas do proprio time.
func _begin_target_selection(actor: Combatant, kind: String) -> void:
	_clear_action_buttons()

	var candidates: Array[Combatant] = []
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


func _confirm_action(actor: Combatant, kind: String, target: Combatant) -> void:
	_pending_actions.append(PendingAction.new(actor, kind, target))
	_current_player_index += 1
	_prompt_action_for_current_creature()


# IA simples: cada inimigo vivo ataca um alvo aleatorio entre os jogadores vivos.
func _queue_enemy_actions() -> void:
	for enemy in enemy_team:
		if not enemy.alive:
			continue
		var alive_players := player_team.filter(func(c): return c.alive)
		if alive_players.is_empty():
			continue
		var target: Combatant = alive_players[randi() % alive_players.size()]
		_pending_actions.append(PendingAction.new(enemy, "attack", target))


# Executa as 4 acoes pendentes na ordem de iniciativa (nao na ordem que foram escolhidas).
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


func _find_pending_action(combatant: Combatant) -> PendingAction:
	for action in _pending_actions:
		if action.actor == combatant:
			return action
	return null


# Passo 2 de refatoracao pra DOP: essas funcoes agora sao puras - recebem dado,
# calculam, devolvem o resultado num Dictionary. Nao chamam _log, nao sabem
# que existe UI. Quem decide como mostrar o resultado eh _log_result().
func _resolve_attack(actor: Combatant, target: Combatant) -> Dictionary:
	if randf() < MISS_CHANCE:
		return {"kind": "attack_miss", "actor": actor, "target": target}

	target.take_damage(ATTACK_DAMAGE)
	return {"kind": "attack_hit", "actor": actor, "target": target, "damage": ATTACK_DAMAGE}


func _resolve_item(actor: Combatant, target: Combatant) -> Dictionary:
	target.heal(ITEM_HEAL_AMOUNT)
	return {"kind": "item_used", "actor": actor, "target": target, "amount": ITEM_HEAL_AMOUNT}


func _resolve_capture(actor: Combatant, target: Combatant) -> Dictionary:
	if randf() < CAPTURE_CHANCE:
		target.alive = false
		target.hp = 0
		return {"kind": "capture_success", "actor": actor, "target": target}

	return {"kind": "capture_fail", "actor": actor, "target": target}


# Unico lugar que traduz resultado -> texto. Trocar de idioma, formato,
# ou até de UI (som, animacao) muda so aqui, nunca nas funcoes de calculo acima.
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


func _execute_action(action: PendingAction) -> void:
	var result: Dictionary
	match action.kind:
		"attack":
			result = _resolve_attack(action.actor, action.target)
		"item":
			result = _resolve_item(action.actor, action.target)
		"capture":
			result = _resolve_capture(action.actor, action.target)
	_log_result(result)


func _check_combat_end() -> void:
	var players_alive := player_team.any(func(c): return c.alive)
	var enemies_alive := enemy_team.any(func(c): return c.alive)

	if not players_alive:
		_end_combat(false)
	elif not enemies_alive:
		_end_combat(true)


func _on_flee_pressed() -> void:
	if combat_over or is_resolving:
		return
	_resolve_flee()


# Fuga eh da equipe inteira (nao por criatura), ignora iniciativa, resolve antes de tudo.
func _resolve_flee() -> void:
	is_resolving = true
	_clear_action_buttons()
	_set_flee_disabled(true)
	turn_label.text = "Equipe tenta fugir..."

	if randf() < FLEE_CHANCE:
		_log("Fugimos! Escapamos do combate.")
		queue_free()   # fecha a tela. Trocar por chamada ao SceneManager quando integrar.
		return

	_log("Tentativa de fuga falhou!")

	for enemy in enemy_team:
		if not enemy.alive or combat_over:
			continue
		var alive_players := player_team.filter(func(c): return c.alive)
		if alive_players.is_empty():
			continue
		var target: Combatant = alive_players[randi() % alive_players.size()]

		turn_label.text = "Turno: %s" % enemy.creature_name
		_log_result(_resolve_attack(enemy, target))
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
