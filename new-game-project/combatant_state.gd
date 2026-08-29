class_name CombatantState
extends Resource

## Value object - estado MUTAVEL de 1 combatente durante a batalha.
## Dado estatico (nome, ataques, descricao) NAO mora aqui - fica no
## AlchemonSheet/AlchemonDatabase, resolvido via species_id quando precisar
## exibir. Isso evita ter 2 fontes de verdade pro mesmo dado estatico.

@export var id: int = -1              # id de INSTANCIA nessa batalha (unico por combatente, nao por especie)
@export var species_id: int = -1      # chave pra buscar nome/ataques no AlchemonDatabase
@export var hp: int = 0
@export var max_hp: int = 0
@export var initiative: int = 0
@export var is_player: bool = false
@export var alive: bool = true

func _init(
	p_id: int = -1,
	p_species_id: int = -1,
	p_max_hp: int = 0,
	p_is_player: bool = false
) -> void:
	id = p_id
	species_id = p_species_id
	max_hp = p_max_hp
	hp = p_max_hp
	is_player = p_is_player
