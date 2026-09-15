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
# Species/base stats. Per-battle values belong in CombatantState.
@export var base_attack: int = 10
@export var base_defense: int = 10
@export var base_mechanical_speed: int = 10
@export var base_action_energy: int = 8
@export var defense_growth_min: int = 1
@export var defense_growth_max: int = 1
@export var mechanical_speed_growth_min: int = 1
@export var mechanical_speed_growth_max: int = 1
@export var action_energy_growth_min: int = 1
@export var action_energy_growth_max: int = 1
@export var xp_reward: int = 0
@export var physical_state: String = SOLIDO   # SOLIDO | LIQUIDO | GASOSO - ver sec 8.2 (temperatura da arena)
@export var element_type: AlchemonType.Type = AlchemonType.Type.METAL   # tipo da CRIATURA - so importa como defensor (sem STAB)
@export var attacks: Array[AttackData] = []   # ate 4 ataques

func _init(p_name: String = "", p_max_hp: int = 30, p_id_or_is_player: Variant = -1, legacy_id: Variant = null) -> void:
	# Third argument is the species id. Accept prior (name, hp, is_player, id)
	# calls while old tests/assets are migrated.
	if legacy_id != null:
		id = int(legacy_id)
	else:
		id = int(p_id_or_is_player)
	creature_name = p_name
	max_hp = p_max_hp
	hp = p_max_hp
