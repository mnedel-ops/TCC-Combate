class_name AlchemonDatabase
extends Resource

## Lista de todos os AlchemonSheet que existem no jogo (fichas-base, "especie").
## Quem consome (ex: CombatController) busca por id e instancia uma copia
## pra usar em combate - o registro aqui nunca e alterado por uma batalha.

@export var alchemons: Array[AlchemonSheet] = []

func get_by_id(id: int) -> AlchemonSheet:
	for a in alchemons:
		if a.id == id:
			return a
	push_warning("AlchemonSheet com id %d nao encontrado no database." % id)
	return null
