class_name CombatantState
extends Resource

## Value object - estado MUTAVEL de 1 combatente durante a batalha.
## Dado estatico (nome, ataques, descricao) NAO mora aqui - fica no
## AlchemonSheet/AlchemonDatabase, resolvido via species_id quando precisar
## exibir. Isso evita ter 2 fontes de verdade pro mesmo dado estatico.

@export var id: int = -1              # id de INSTANCIA nessa batalha (unico por combatente, nao por especie)
@export var species_id: int = -1      # chave pra buscar nome/ataques no AlchemonDatabase
@export var slot: int = -1            # battlefield slot position (BattlefieldSlot.*)
@export var hp: int = 0
@export var max_hp: int = 0
@export var valence_electrons: int = 0
@export var max_valence_electrons: int = 0
@export var level: int = 1
@export var experience: int = 0
@export var individual_value: int = 1
@export var attack: int = 1
@export var defense: int = 1
@export var mechanical_speed: int = 1
@export var action_energy: int = 1
@export var bond_kind: String = BondRules.NONE   # NONE | MIXTURE | COMPOUND - see BondRules
@export var bond_partner_id: int = -1
@export var is_bond_cation: bool = false         # only meaningful when bond_kind == COMPOUND
@export var initiative: int = 0
@export var is_player: bool = false
@export var alive: bool = true

func _init(
	p_id: int = -1,
	p_species_id: int = -1,
	p_max_hp: int = 0,
	p_is_player: bool = false,
	p_slot: int = -1,
	p_max_valence_electrons: int = 0
) -> void:
	id = p_id
	species_id = p_species_id
	max_hp = p_max_hp
	hp = p_max_hp
	is_player = p_is_player
	slot = p_slot
	max_valence_electrons = p_max_valence_electrons
	valence_electrons = p_max_valence_electrons
