class_name AlchemonSheet
extends Resource

## Dado puro - a ficha-base (especie) de uma criatura. Sem metodos de regra
## (take_damage, heal, level_up etc) e sem estado de batalha (hp atual,
## alive, initiative, is_player) - isso e tudo instancia, mora em
## CombatantState. Uma especie nunca "morre" nem "ataca" - so descreve.

@export var id: int = -1
@export var creature_name: String = ""
@export var max_hp: int = 30
@export var attacks: Array[AttackData] = []   # ate 4 ataques

## --- Atributos de combate (GDD secao 7) ---
## Vida (HP) -> Massa atomica: ja coberta por max_hp acima.
## Ataque -> Eletronegatividade | Defesa -> Energia de ionizacao
## Velocidade Mecanica -> Velocidade cinetica | Energia de Acao -> Eletrons de valencia
##
## base_attack e usado direto na formula do GDD (AlchemonFormulas.compute_attack)
## a cada level up - nao tem mais faixa de crescimento propria, o proprio
## Nivel + IV ja determinam o novo valor.
@export_range(1, 999) var base_attack: int = 5
@export_range(1, 999) var base_defense: int = 5
@export_range(1, 999) var base_mechanical_speed: int = 5
@export_range(1, 999) var base_action_energy: int = 5

## Faixa (min/max) de ganho por level up - ainda usada por Defesa,
## Velocidade Mecanica e Energia de Acao (nao convertidas pra formula
## ainda). Quanto mais forte a especie nesse atributo, maior a faixa.
@export_range(1, 50) var defense_growth_min: int = 1
@export_range(1, 50) var defense_growth_max: int = 3
@export_range(1, 50) var mechanical_speed_growth_min: int = 1
@export_range(1, 50) var mechanical_speed_growth_max: int = 3
@export_range(1, 50) var action_energy_growth_min: int = 1
@export_range(1, 50) var action_energy_growth_max: int = 3

## Temperatura de mudanca de estado fisico (GDD secao 8.2) - ponto de
## fusao/ebulicao do elemento, em Kelvin. NAO e a temperatura atual da
## arena (isso e CombatState.temperature, que muda a cada golpe e e
## compartilhada pelas 4 criaturas). Este e um valor fixo da especie: o
## limiar que, cruzado pelo CombatState.temperature, muda o estado fisico
## deste Alchemon especificamente.
@export var temperature: float = 0.0

## XP concedida a quem derrota (mata) ou captura esta especie. Flat por
## enquanto - GDD ainda nao define escala por nivel/forca da especie.
@export_range(0, 9999) var xp_reward: int = 20

func _init(p_name: String = "", p_max_hp: int = 30, p_id: int = -1) -> void:
	id = p_id
	creature_name = p_name
	max_hp = p_max_hp
