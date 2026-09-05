class_name AlchemonFormulas
extends RefCounted

## Formulas puras do GDD (secao 7.2 e 5.1) - sem Effort Value (EV), que nao
## faz parte deste jogo. So matematica: numeros entram, numero sai. Nenhuma
## leitura/escrita de CombatantState ou AlchemonSheet aqui - quem le os
## campos e chama isso e AlchemonGrowth / CombatRules.

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
