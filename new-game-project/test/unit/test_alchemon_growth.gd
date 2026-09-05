extends GdUnitTestSuite

## Cobre: seed inicial de atributos, formula de ataque (sem EV), formula
## de iniciativa por velocidade, crescimento de defesa ainda por faixa,
## e o piso minimo de 1.

var template: AlchemonSheet


func before_test() -> void:
	template = AlchemonSheet.new("Hero", 30, true, 0)
	template.base_attack = 10
	template.base_defense = 8
	template.base_mechanical_speed = 12
	template.base_action_energy = 6
	template.defense_growth_min = 2
	template.defense_growth_max = 4


func test_combatant_seeds_stats_from_template_base() -> void:
	var db := AlchemonDatabase.new()
	db.alchemons = [template]
	var state := CombatStateFactory.build(db, [0], [])
	var combatant := state.get_combatant(state.player_ids[0])

	assert_int(combatant.defense).is_equal(8)
	assert_int(combatant.mechanical_speed).is_equal(12)
	assert_int(combatant.action_energy).is_equal(6)
	assert_int(combatant.level).is_equal(1)
	assert_int(combatant.individual_value).is_equal(1)


func test_attack_formula_matches_gdd_without_ev() -> void:
	# floor(0.01 * (2*10 + 1) * 1) + 5 = floor(0.21) + 5 = 5
	assert_int(AlchemonFormulas.compute_attack(10, 1, 1)).is_equal(5)
	# floor(0.01 * (2*10 + 1) * 20) + 5 = floor(4.2) + 5 = 9
	assert_int(AlchemonFormulas.compute_attack(10, 1, 20)).is_equal(9)


func test_level_up_recomputes_attack_via_formula() -> void:
	var combatant := CombatantState.new(0, 0, 30, true, 0)
	combatant.attack = AlchemonFormulas.compute_attack(template.base_attack, combatant.individual_value, combatant.level)

	AlchemonGrowth.level_up(combatant, template)

	var expected := AlchemonFormulas.compute_attack(template.base_attack, combatant.individual_value, combatant.level)
	assert_int(combatant.level).is_equal(2)
	assert_int(combatant.attack).is_equal(expected)


func test_level_up_still_grows_defense_within_configured_range() -> void:
	var combatant := CombatantState.new(0, 0, 30, true, 0)
	combatant.defense = template.base_defense

	AlchemonGrowth.level_up(combatant, template)

	assert_bool(combatant.defense >= 10 and combatant.defense <= 12).is_true()


func test_level_up_never_drops_defense_below_one() -> void:
	template.defense_growth_min = -5
	template.defense_growth_max = -5
	var combatant := CombatantState.new(0, 0, 30, true, 0)
	combatant.defense = 1

	AlchemonGrowth.level_up(combatant, template)

	assert_int(combatant.defense).is_equal(1)


func test_initiative_formula_matches_spec() -> void:
	# floor(((12 + 1) * 2 * 5) / 100) + 5 = floor(1.3) + 5 = 6
	assert_int(AlchemonFormulas.compute_initiative(12, 1, 5)).is_equal(6)


func test_roll_initiative_is_deterministic_from_speed_not_random() -> void:
	var db := AlchemonDatabase.new()
	var fast := AlchemonSheet.new("Fast", 30, true, 0)
	fast.base_mechanical_speed = 50
	var slow := AlchemonSheet.new("Slow", 20, false, 1)
	slow.base_mechanical_speed = 5
	db.alchemons = [fast, slow]

	var state := CombatStateFactory.build(db, [0], [1])
	CombatRules.roll_initiative(state)

	assert_array(state.turn_order_ids).is_equal([state.player_ids[0], state.enemy_ids[0]])


func test_combat_state_defaults_temperature_to_25_celsius_in_kelvin() -> void:
	var state := CombatState.new()

	assert_float(state.temperature).is_equal_approx(298.15, 0.01)
