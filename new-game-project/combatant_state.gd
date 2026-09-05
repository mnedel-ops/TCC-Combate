class_name CombatantState
extends Resource

## Value object - estado MUTAVEL de 1 combatente durante a batalha.
## Dado estatico (nome, ataques, descricao, valores base, faixas de
## crescimento) NAO mora aqui - fica no AlchemonSheet/AlchemonDatabase,
## resolvido via species_id quando precisar exibir ou crescer. Isso evita
## ter 2 fontes de verdade pro mesmo dado estatico.

@export var id: int = -1              # id de INSTANCIA nessa batalha (unico por combatente, nao por especie)
@export var species_id: int = -1      # chave pra buscar nome/ataques/atributos base no AlchemonDatabase
@export var slot: int = -1            # battlefield slot position (BattlefieldSlot.*)
@export var hp: int = 0
@export var max_hp: int = 0
@export var initiative: int = 0
@export var is_player: bool = false
@export var alive: bool = true

## --- Atributos de combate (GDD secao 7), valor atual da instancia ---
## Ataque e recalculado via formula (AlchemonFormulas.compute_attack) a
## cada level up. Defesa/Velocidade Mecanica/Energia de Acao comecam iguais
## ao base_* do AlchemonSheet e ainda crescem via faixa min/max
## (AlchemonGrowth.level_up). Minimo de 1 sempre garantido.
@export var level: int = 1
@export var attack: int = 1
@export var defense: int = 1
@export var mechanical_speed: int = 1
@export var action_energy: int = 1

## Individual Value (IV) - por enquanto fixo em 1 pra todo mundo. Sem
## sistema de Nature nem EV (nao fazem parte do jogo).
@export var individual_value: int = 1

func _init(
	p_id: int = -1,
	p_species_id: int = -1,
	p_max_hp: int = 0,
	p_is_player: bool = false,
	p_slot: int = -1,
	p_level: int = 1,
	p_attack: int = 1,
	p_defense: int = 1,
	p_mechanical_speed: int = 1,
	p_action_energy: int = 1
) -> void:
	id = p_id
	species_id = p_species_id
	max_hp = p_max_hp
	hp = p_max_hp
	is_player = p_is_player
	slot = p_slot
	level = maxi(p_level, 1)
	attack = maxi(p_attack, 1)
	defense = maxi(p_defense, 1)
	mechanical_speed = maxi(p_mechanical_speed, 1)
	action_energy = maxi(p_action_energy, 1)
