class_name CombatStateFactory
extends RefCounted

## Constroi um CombatState inicial a partir do database + listas de species_id.
## Nao decide regra de combate (isso e CombatRules); so monta estado inicial.
## Tambem aloca slots iniciais no battlefield via BattlefieldRules.

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

		var c := CombatantState.new(next_instance_id, species_id, template.max_hp, true, slot, template.max_valence_electrons)
		_seed_stats(c, template)
		state.combatants[c.id] = c
		state.player_ids.append(c.id)
		BattlefieldRules.assign_combatant(state.battlefield, c.id, slot)
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

		var c := CombatantState.new(next_instance_id, species_id, template.max_hp, false, slot, template.max_valence_electrons)
		_seed_stats(c, template)
		state.combatants[c.id] = c
		state.enemy_ids.append(c.id)
		BattlefieldRules.assign_combatant(state.battlefield, c.id, slot)
		next_instance_id += 1
		enemy_slot_index += 1

	return state


static func _seed_stats(combatant: CombatantState, template: AlchemonSheet) -> void:
	combatant.level = 1
	combatant.experience = 0
	combatant.individual_value = 1
	combatant.attack = AlchemonFormulas.compute_attack(template.base_attack, combatant.individual_value, combatant.level)
	combatant.defense = maxi(template.base_defense, 1)
	combatant.mechanical_speed = maxi(template.base_mechanical_speed, 1)
	combatant.action_energy = maxi(template.base_action_energy, 1)
