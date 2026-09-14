class_name AlchemonSheet
extends Resource

## Dado puro - uma criatura em combate. Sem metodos de regra (take_damage,
## heal etc). Quem manipula esses valores e CombatRules.

const SOLIDO := "solido"
const LIQUIDO := "liquido"
const GASOSO := "gasoso"

@export var id: int = -1
@export var creature_name: String = ""
@export var max_hp: int = 30
@export var hp: int = 30
@export var max_valence_electrons: int = 8   # cresce no level-up, mesma formula de sec 7.2 (ainda nao implementada)
@export var is_player: bool = false
@export var initiative: int = 0
@export var alive: bool = true
@export var physical_state: String = SOLIDO   # SOLIDO | LIQUIDO | GASOSO - ver sec 8.2 (temperatura da arena)
@export var element_type: AlchemonType.Type = AlchemonType.Type.METAL   # tipo da CRIATURA - so importa como defensor (sem STAB)
@export var attacks: Array[AttackData] = []   # ate 4 ataques

func _init(p_name: String = "", p_max_hp: int = 30, p_is_player: bool = false, p_id: int = -1) -> void:
	id = p_id
	creature_name = p_name
	max_hp = p_max_hp
	hp = p_max_hp
	is_player = p_is_player
