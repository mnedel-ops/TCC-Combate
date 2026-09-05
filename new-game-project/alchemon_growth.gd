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

static func level_up(combatant: CombatantState, template: AlchemonSheet, levels: int = 1) -> void:
	for i in levels:
		combatant.level += 1

		combatant.attack = AlchemonFormulas.compute_attack(
			template.base_attack, combatant.individual_value, combatant.level
		)

		combatant.defense = maxi(combatant.defense + randi_range(template.defense_growth_min, template.defense_growth_max), 1)
		combatant.mechanical_speed = maxi(combatant.mechanical_speed + randi_range(template.mechanical_speed_growth_min, template.mechanical_speed_growth_max), 1)
		combatant.action_energy = maxi(combatant.action_energy + randi_range(template.action_energy_growth_min, template.action_energy_growth_max), 1)
