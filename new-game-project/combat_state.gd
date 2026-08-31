class_name CombatState
extends Resource

## Contrato de estado - TUDO que existe durante uma batalha vive aqui.
## Nenhum metodo de regra de jogo (isso vai pro CombatSystem, no proximo
## passo da refatoracao). Os unicos metodos aqui sao acessores triviais,
## equivalentes a Dictionary.get() com tipo - nao decidem nada.

@export var combatants: Dictionary = {}      # int (instance id) -> CombatantState
@export var player_ids: Array[int] = []
@export var enemy_ids: Array[int] = []
@export var turn_order_ids: Array[int] = []
@export var pending_actions: Array[ActionCommand] = []

@export var round_number: int = 0
@export var phase: String = "selecting_actions"  # selecting_actions | resolving_round | combat_over
@export var combat_over: bool = false
@export var player_won: bool = false


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
