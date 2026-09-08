class_name CombatStateFactory
extends RefCounted

## Constroi um CombatState inicial a partir do database + listas de species_id.
## Nao decide regra de combate (isso e CombatRules); so monta estado inicial,
## incluindo os atributos de combate no valor base (nivel 1) da especie.
## Tambem aloca slots iniciais no battlefield.

static func build(database: AlchemonDatabase, player_species_ids: Array[int], enemy_species_ids: Array[int]) -> CombatState:
	var state := CombatState.new()
	var next_instance_id := 0

	next_instance_id = _populate_side(state, database, player_species_ids, true, BattlefieldSlot.PLAYER_SLOT_1, next_instance_id)
	_populate_side(state, database, enemy_species_ids, false, BattlefieldSlot.ENEMY_SLOT_1, next_instance_id)

	return state


## Cria os combatentes de um lado (jogador ou inimigo), atribui slots e
## registra no state. Retorna o proximo instance_id livre, pra encadear
## a chamada seguinte sem colidir ids entre os dois lados.
static func _populate_side(
	state: CombatState,
	database: AlchemonDatabase,
	species_ids: Array[int],
	is_player: bool,
	first_slot: int,
	next_instance_id: int
) -> int:
	var slot_index := 0
	for species_id in species_ids:
		var template := database.get_by_id(species_id)
		if template == null:
			continue

		if slot_index >= 2:
			push_warning("Too many %s for battlefield (max 2 slots)" % ("players" if is_player else "enemies"))
			break

		var slot := first_slot + slot_index
		var c := _create_combatant(next_instance_id, species_id, template, is_player, slot)

		state.combatants[c.id] = c
		if is_player:
			state.player_ids.append(c.id)
		else:
			state.enemy_ids.append(c.id)
		state.battlefield.assign_combatant(c.id, slot)

		next_instance_id += 1
		slot_index += 1

	return next_instance_id


static func _create_combatant(instance_id: int, species_id: int, template: AlchemonSheet, is_player: bool, slot: int) -> CombatantState:
	return CombatantState.new(
		instance_id, species_id, template.max_hp, is_player, slot,
		1, template.base_attack, template.base_defense, template.base_mechanical_speed, template.base_action_energy
	)
