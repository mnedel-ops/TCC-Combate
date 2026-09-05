class_name AlchemonSheet
extends Resource

## Dado puro - uma criatura em combate. Sem metodos de regra (take_damage,
## heal etc). Quem manipula esses valores e CombatRules / AlchemonGrowth.

@export var id: int = -1
@export var creature_name: String = ""
@export var max_hp: int = 30
@export var hp: int = 30
@export var is_player: bool = false
@export var initiative: int = 0
@export var alive: bool = true
@export var attacks: Array[AttackData] = []   # ate 4 ataques

## --- Atributos de combate (GDD secao 7) ---
## Vida (HP) -> Massa atomica: ja coberta por max_hp/hp acima.
## Ataque -> Eletronegatividade | Defesa -> Energia de ionizacao
## Velocidade Mecanica -> Velocidade cinetica | Energia de Acao -> Eletrons de valencia
## Valor base = atributo no nivel 1. Minimo de 1 aplicado no editor via
## export_range e reforcado em runtime por AlchemonGrowth/CombatantState.
@export_range(1, 999) var base_attack: int = 5
@export_range(1, 999) var base_defense: int = 5
@export_range(1, 999) var base_mechanical_speed: int = 5
@export_range(1, 999) var base_action_energy: int = 5

## Faixa (min/max) de ganho por level up. Especies mais fortes num
## atributo configuram uma faixa mais alta aqui - e so isso que
## AlchemonGrowth le pra decidir o incremento de cada level up.
@export_range(1, 50) var attack_growth_min: int = 1
@export_range(1, 50) var attack_growth_max: int = 3
@export_range(1, 50) var defense_growth_min: int = 1
@export_range(1, 50) var defense_growth_max: int = 3
@export_range(1, 50) var mechanical_speed_growth_min: int = 1
@export_range(1, 50) var mechanical_speed_growth_max: int = 3
@export_range(1, 50) var action_energy_growth_min: int = 1
@export_range(1, 50) var action_energy_growth_max: int = 3

func _init(p_name: String = "", p_max_hp: int = 30, p_is_player: bool = false, p_id: int = -1) -> void:
	id = p_id
	creature_name = p_name
	max_hp = p_max_hp
	hp = p_max_hp
	is_player = p_is_player
