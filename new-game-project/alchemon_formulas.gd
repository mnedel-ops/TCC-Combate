class_name AlchemonFormulas
extends RefCounted

## Formulas puras do GDD (secoes 5.1, 7.2, 8.2, 10.1) - sem Effort Value
## (EV), que nao faz parte deste jogo. So matematica: numeros entram,
## numero sai. Nenhuma leitura/escrita de CombatantState ou AlchemonSheet
## aqui - quem le os campos e chama isso e AlchemonGrowth / CombatRules.

## GDD 7.2 "Outros Atributos", sem termo de EV:
## floor(0.01 * (2*Base + IV) * Level) + 5
static func compute_attack(base_attack: int, individual_value: int, level: int) -> int:
	var raw := 0.01 * (2.0 * base_attack + individual_value) * level
	return int(floor(raw)) + 5


## Iniciativa por Velocidade Mecanica. Formula especifica pra ordem de
## turno - distinta da formula generica de atributo acima:
## floor(((velocidade_mecanica + IV) * 2 * Level) / 100) + 5
static func compute_initiative(mechanical_speed: int, individual_value: int, level: int) -> int:
	var raw := float((mechanical_speed + individual_value) * 2 * level) / 100.0
	return int(floor(raw)) + 5


## GDD 10.1 - formula de dano.
## (((2*Level/5 + 2) * Power * (Attack/Defense)) / 50 + 2) * Effectiveness
##
## "power" e o Poder do Golpe (AttackData.power) - nao e o dano final,
## so um input da formula. "effectiveness" default 1.0: o multiplicador
## de tipo x tipo do GDD ainda nao existe (sem sistema elemental) - a
## assinatura ja aceita o valor real quando esse sistema for implementado.
static func compute_damage(level: int, power: int, attack: int, defense: int, effectiveness: float = 1.0) -> int:
	var defense_safe := maxi(defense, 1)  # nunca divide por zero
	var scaled := (2.0 * level / 5.0 + 2.0) * power * (float(attack) / defense_safe)
	var damage := (scaled / 50.0 + 2.0) * effectiveness
	return maxi(int(floor(damage)), 0)


## GDD 8.2 - variacao de temperatura da arena causada por um golpe.
## floor((Level/10 + 1) * (Power/10) * (Attack/100))
##
## Sempre um incremento - o GDD nao define sinal, entao todo golpe aquece
## a arena, nenhum esfria. So calculado quando o golpe acerta (chamado por
## CombatRules so no caminho de ATTACK_HIT, nunca em MISS).
static func compute_temperature_delta(level: int, power: int, attack: int) -> int:
	var raw := (float(level) / 10.0 + 1.0) * (float(power) / 10.0) * (float(attack) / 100.0)
	return int(floor(raw))
