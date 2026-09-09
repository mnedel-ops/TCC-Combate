class_name AttackData
extends Resource

## Dado puro - um ataque que uma criatura pode usar. Uma AlchemonSheet
## guarda ate 4 desses na sua lista de ataques.
##
## "power" e o Poder do Golpe do GDD - input pra formula de dano (secao
## 10.1) e pra formula de variacao de temperatura (secao 8.2). NUNCA e o
## dano final: o dano de verdade so existe calculado durante a batalha
## (CombatRules._resolve_attack via AlchemonFormulas.compute_damage),
## depende de quem ataca/defende, nivel e efetividade - nao e um numero
## fixo do golpe.
##
## "element_type" e o tipo DO GOLPE (GDD secao 10, listado como um dos
## atributos que definem um ataque) - e o que entra em AlchemonType.effectiveness()
## contra o element_type da criatura alvo. Sem STAB: nao precisa bater com
## o element_type de quem usa o golpe.

@export var indexAttack: int = -1
@export var attack_name: String = "Ataque"
@export var power: int = 10
@export var element_type: AlchemonType.Type = AlchemonType.Type.METAL
