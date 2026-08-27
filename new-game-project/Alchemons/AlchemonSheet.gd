class_name AlchemonSheet
extends Resource

## Dado puro - uma criatura em combate. Sem metodos de regra (take_damage,
## heal etc). Quem manipula esses valores e o CombatSystem.

@export var creature_name: String = ""
@export var max_hp: int = 30
@export var hp: int = 30
@export var is_player: bool = false
@export var initiative: int = 0
@export var alive: bool = true

func _init(p_name: String = "", p_max_hp: int = 30, p_is_player: bool = false) -> void:
	creature_name = p_name
	max_hp = p_max_hp
	hp = p_max_hp
	is_player = p_is_player
