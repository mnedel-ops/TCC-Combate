class_name CombatState
extends Resource

## Contrato de estado - TUDO que existe durante uma batalha vive aqui.
## Nenhum metodo de regra de jogo (isso mora em CombatRules). Os unicos
## metodos aqui sao acessores triviais,
## equivalentes a Dictionary.get() com tipo - nao decidem nada.

@export var combatants: Dictionary = {}      # int (instance id) -> CombatantState
@export var player_ids: Array[int] = []
@export var enemy_ids: Array[int] = []
@export var turn_order_ids: Array[int] = []
@export var pending_actions: Array[ActionCommand] = []

@export var round_number: int = 0
@export var phase: String = BattlePhaseMachine.ENCOUNTER_START
@export var combat_over: bool = false
@export var player_won: bool = false

## Temperatura da arena (GDD secao 8) - global, afeta as 4 criaturas em
## campo, nao e um atributo por criatura. Guardada em Kelvin internamente,
## nunca convertida automaticamente pra UI. Padrao: 25 C = 298.15 K.
@export var temperature: float = 298.15

var battlefield: Battlefield
var battle_phase: BattlePhaseMachine


func _init() -> void:
	battlefield = Battlefield.new()
	battle_phase = BattlePhaseMachine.new(BattlePhaseMachine.ENCOUNTER_START)
	phase = battle_phase.current_phase()


func get_combatant(id: int) -> CombatantState:
	return combatants.get(id)


func get_team_ids(is_player: bool) -> Array[int]:
	return player_ids if is_player else enemy_ids


func get_alive_ids(ids: Array[int]) -> Array[int]:
	var alive_ids: Array[int] = []
	for id in ids:
		var c := get_combatant(id)
		if c != null and c.alive:
			alive_ids.append(id)
	return alive_ids


## Get all alive combatants occupying slots on the given side.
func get_alive_opposing_combatants(is_player: bool) -> Array[int]:
	var opposing_ids := battlefield.get_opposing_combatants(is_player)
	return get_alive_ids(opposing_ids)


## Get all valid targetable combatants from a given actor's perspective.
## Only includes combatants alive and on the opposite side.
func get_valid_targets(actor_id: int) -> Array[int]:
	var actor := get_combatant(actor_id)
	if actor == null:
		return []
	return get_alive_opposing_combatants(actor.is_player)
