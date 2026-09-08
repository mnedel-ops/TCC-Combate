class_name AlchemonGrowth
extends RefCounted

## Cresce os atributos de um CombatantState ao subir de nivel.
##
## Ataque agora e recalculado do zero via AlchemonFormulas.compute_attack()
## a cada level up (formula do GDD, sem EV) - nao e mais um incremento
## aleatorio acumulado. Defesa, Velocidade Mecanica e Energia de Acao ainda
## usam a faixa min/max configurada no AlchemonSheet (nao convertidas pra
## formula ainda). Minimo de 1 sempre garantido em todos os atributos.
##
## Nao mexe em HP - Vida (HP) continua seguindo max_hp/hp, que ja tem seu
## proprio fluxo (template.max_hp na criacao, sem crescimento por nivel
## ainda).

## XP necessario pra subir 1 nivel. Fixo por enquanto - GDD ainda nao
## define uma curva de XP por nivel/especie.
const XP_TO_LEVEL_UP := 100


static func level_up(combatant: CombatantState, template: AlchemonSheet, levels: int = 1) -> void:
	for i in levels:
		combatant.level += 1

		combatant.attack = AlchemonFormulas.compute_attack(
			template.base_attack, combatant.individual_value, combatant.level
		)

		combatant.defense = maxi(combatant.defense + randi_range(template.defense_growth_min, template.defense_growth_max), 1)
		combatant.mechanical_speed = maxi(combatant.mechanical_speed + randi_range(template.mechanical_speed_growth_min, template.mechanical_speed_growth_max), 1)
		combatant.action_energy = maxi(combatant.action_energy + randi_range(template.action_energy_growth_min, template.action_energy_growth_max), 1)


## Concede XP a um combatente e aplica quantos level ups o total acumulado
## render (normalmente 0 ou 1, mas cobre o caso de uma recompensa grande
## de uma vez so - ex: capturar algo muito acima do nivel atual). Sobra de
## XP alem do necessario pro proximo nivel fica guardada, nunca se perde.
static func grant_experience(combatant: CombatantState, template: AlchemonSheet, amount: int) -> void:
	if amount <= 0:
		return

	combatant.experience += amount
	while combatant.experience >= XP_TO_LEVEL_UP:
		combatant.experience -= XP_TO_LEVEL_UP
		level_up(combatant, template)
