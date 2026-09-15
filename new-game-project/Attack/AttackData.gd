class_name AttackData
extends Resource

## Dado puro - um ataque que uma criatura pode usar. Uma AlchemonSheet
## guarda ate 4 desses na sua lista de ataques.

@export var indexAttack: int = -1
@export var attack_name: String = "Ataque"
@export var damage: int = 10
# `damage` is retained for old .tres assets. New combat calculations use power.
@export var power: int = 0
@export var energy_cost: int = 2   # eletrons de valencia gastos ao usar - custo fixo por enquanto
@export var element_type: AlchemonType.Type = AlchemonType.Type.METAL   # tipo do GOLPE (nao do usuario - sem STAB, GDD 10.1)
