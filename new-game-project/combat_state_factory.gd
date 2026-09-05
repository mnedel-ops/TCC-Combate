class_name CombatStateFactory
extends RefCounted

## Constroi um CombatState inicial a partir do database + listas de species_id.
## Nao decide regra de combate (isso e CombatRules); so monta estado inicial,
## incluindo os atributos de combate no valor base (nivel 1) da especie.
## Tambem aloca slots iniciais no battlefield.

static func build(database: AlchemonDatabase, player_species_ids: Array[int], enemy_species_ids: Array[int]) -> CombatState:
	var state := CombatState.new()
	var next_instance_id := 0
	var player_slot_index := 0
	var enemy_slot_index := 0

	# Create player combatants and assign slots
	for species_id in player_species_ids:
		var template := database.get_by_id(species_id)
		if template == null:
			continue

		var slot := BattlefieldSlot.PLAYER_SLOT_1 + player_slot_index
		if player_slot_index >= 2:
			push_warning("Too many players for battlefield (max 2 slots)")
			break

		var c := CombatantState.new(
			next_instance_id, species_id, template.max_hp, true, slot,
			1, template.base_attack, template.base_defense, template.base_mechanical_speed, template.base_action_energy
		)
		state.combatants[c.id] = c
		state.player_ids.append(c.id)
		state.battlefield.assign_combatant(c.id, slot)
		next_instance_id += 1
		player_slot_index += 1

	# Create enemy combatants and assign slots
	for species_id in enemy_species_ids:
		var template := database.get_by_id(species_id)
		if template == null:
			continue

		var slot := BattlefieldSlot.ENEMY_SLOT_1 + enemy_slot_index
		if enemy_slot_index >= 2:
			push_warning("Too many enemies for battlefield (max 2 slots)")
			break

		var c := CombatantState.new(
			next_instance_id, species_id, template.max_hp, false, slot,
			1, template.base_attack, template.base_defense, template.base_mechanical_speed, template.base_action_energy
		)
		state.combatants[c.id] = c
		state.enemy_ids.append(c.id)
		state.battlefield.assign_combatant(c.id, slot)
		next_instance_id += 1
		enemy_slot_index += 1

	return state
