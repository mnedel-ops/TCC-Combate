class_name CombatStateFactory
extends RefCounted

## Constroi um CombatState inicial a partir do database + listas de species_id.
## Nao decide regra de combate (isso e CombatRules); so monta estado inicial.

static func build(database: AlchemonDatabase, player_species_ids: Array[int], enemy_species_ids: Array[int]) -> CombatState:
	var state := CombatState.new()
	var next_instance_id := 0

	for species_id in player_species_ids:
		var template := database.get_by_id(species_id)
		if template == null:
			continue
		var c := CombatantState.new(next_instance_id, species_id, template.max_hp, true)
		state.combatants[c.id] = c
		state.player_ids.append(c.id)
		next_instance_id += 1

	for species_id in enemy_species_ids:
		var template := database.get_by_id(species_id)
		if template == null:
			continue
		var c := CombatantState.new(next_instance_id, species_id, template.max_hp, false)
		state.combatants[c.id] = c
		state.enemy_ids.append(c.id)
		next_instance_id += 1

	return state
