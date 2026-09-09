extends GdUnitTestSuite

## Cobre: seed inicial de atributos, formula de ataque (sem EV), formula
## de iniciativa por velocidade, crescimento de defesa ainda por faixa,
## e o piso minimo de 1.

var template: AlchemonSheet


func before_test() -> void:
	template = AlchemonSheet.new("Hero", 30, 0)
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


func test_damage_formula_matches_gdd() -> void:
	# (((2*10/5+2) * 40 * (50/50)) / 50 + 2) * 1.0
	# = ((6 * 40 * 1) / 50 + 2) = (240/50 + 2) = (4.8 + 2) = 6.8 -> floor 6
	assert_int(AlchemonFormulas.compute_damage(10, 40, 50, 50)).is_equal(6)


func test_damage_formula_never_divides_by_zero_defense() -> void:
	# defense=0 deve se comportar como defense=1, nao travar/crashar
	var with_zero := AlchemonFormulas.compute_damage(10, 40, 50, 0)
	var with_one := AlchemonFormulas.compute_damage(10, 40, 50, 1)
	assert_int(with_zero).is_equal(with_one)


func test_damage_formula_applies_effectiveness_multiplier() -> void:
	# scaled = (2*10/5+2) * 40 * (50/50) = 240; pre-floor = 240/50 + 2 = 6.8
	# effectiveness multiplies BEFORE the floor (GDD: "(...) x Efetividade",
	# floored as a whole) - floor(6.8*2)=13, NOT floor(6.8)*2=12. Doubling
	# effectiveness doesn't mean doubling the already-floored result.
	var neutral := AlchemonFormulas.compute_damage(10, 40, 50, 50, 1.0)
	var doubled := AlchemonFormulas.compute_damage(10, 40, 50, 50, 2.0)
	assert_int(neutral).is_equal(6)
	assert_int(doubled).is_equal(13)


func test_temperature_delta_formula_matches_gdd() -> void:
	# (10/10+1) * (40/10) * (50/100) = 2 * 4 * 0.5 = 4
	assert_int(AlchemonFormulas.compute_temperature_delta(10, 40, 50)).is_equal(4)


func test_crit_chance_is_flat_twelve_point_five_percent() -> void:
	assert_float(CombatRules.CRIT_CHANCE).is_equal_approx(0.125, 0.0001)


func test_roll_initiative_is_deterministic_from_speed_not_random() -> void:
	var db := AlchemonDatabase.new()
	var fast := AlchemonSheet.new("Fast", 30, 0)
	fast.base_mechanical_speed = 50
	var slow := AlchemonSheet.new("Slow", 20, 1)
	slow.base_mechanical_speed = 5
	db.alchemons = [fast, slow]

	var state := CombatStateFactory.build(db, [0], [1])
	CombatRules.roll_initiative(state)

	assert_array(state.turn_order_ids).is_equal([state.player_ids[0], state.enemy_ids[0]])


func test_combat_state_defaults_temperature_to_25_celsius_in_kelvin() -> void:
	var state := CombatState.new()

	assert_float(state.temperature).is_equal_approx(298.15, 0.01)


# ---------------------------------------------------------------------------
# XP e nivel (AlchemonGrowth.grant_experience)
# ---------------------------------------------------------------------------

func test_combatant_starts_at_level_1_with_zero_experience() -> void:
	var db := AlchemonDatabase.new()
	db.alchemons = [template]
	var state := CombatStateFactory.build(db, [0], [])
	var combatant := state.get_combatant(state.player_ids[0])

	assert_int(combatant.level).is_equal(1)
	assert_int(combatant.experience).is_equal(0)


func test_grant_experience_below_threshold_does_not_level_up() -> void:
	var combatant := CombatantState.new(0, 0, 30, true, 0)

	AlchemonGrowth.grant_experience(combatant, template, 60)

	assert_int(combatant.experience).is_equal(60)
	assert_int(combatant.level).is_equal(1)


func test_grant_experience_at_threshold_levels_up_and_resets_experience() -> void:
	var combatant := CombatantState.new(0, 0, 30, true, 0)

	AlchemonGrowth.grant_experience(combatant, template, AlchemonGrowth.XP_TO_LEVEL_UP)

	assert_int(combatant.level).is_equal(2)
	assert_int(combatant.experience).is_equal(0)


func test_grant_experience_overflow_keeps_remainder_and_can_double_level() -> void:
	var combatant := CombatantState.new(0, 0, 30, true, 0)

	AlchemonGrowth.grant_experience(combatant, template, AlchemonGrowth.XP_TO_LEVEL_UP + 30)

	assert_int(combatant.level).is_equal(2)
	assert_int(combatant.experience).is_equal(30)

	AlchemonGrowth.grant_experience(combatant, template, AlchemonGrowth.XP_TO_LEVEL_UP * 2 - 30)

	assert_int(combatant.level).is_equal(4)
	assert_int(combatant.experience).is_equal(0)


func test_defeating_target_grants_its_xp_reward_to_actor() -> void:
	var db := _build_database_with_reward(60)
	var state := CombatStateFactory.build(db, [0], [1])
	var actor_id := state.player_ids[0]
	var target_id := state.enemy_ids[0]

	var result := CombatResult.attack_hit(actor_id, target_id, "Tackle", 999, false)
	CombatResultApplier.apply(state, result, db)

	var actor := state.get_combatant(actor_id)
	assert_int(actor.experience).is_equal(60)
	assert_int(actor.level).is_equal(1)


func test_defeating_target_can_trigger_level_up_through_the_applier() -> void:
	var db := _build_database_with_reward(AlchemonGrowth.XP_TO_LEVEL_UP + 50)
	var state := CombatStateFactory.build(db, [0], [1])
	var actor_id := state.player_ids[0]
	var target_id := state.enemy_ids[0]

	var result := CombatResult.attack_hit(actor_id, target_id, "Tackle", 999, false)
	CombatResultApplier.apply(state, result, db)

	var actor := state.get_combatant(actor_id)
	assert_int(actor.level).is_equal(2)
	assert_int(actor.experience).is_equal(50)


func test_capture_also_grants_xp() -> void:
	var db := _build_database_with_reward(AlchemonGrowth.XP_TO_LEVEL_UP)
	var state := CombatStateFactory.build(db, [0], [1])
	var actor_id := state.player_ids[0]
	var target_id := state.enemy_ids[0]

	var result := CombatResult.capture_success(actor_id, target_id)
	CombatResultApplier.apply(state, result, db)

	assert_int(state.get_combatant(actor_id).level).is_equal(2)


func test_miss_grants_no_xp() -> void:
	var db := _build_database_with_reward(999)
	var state := CombatStateFactory.build(db, [0], [1])
	var actor_id := state.player_ids[0]
	var target_id := state.enemy_ids[0]

	var result := CombatResult.attack_miss(actor_id, target_id, "Tackle")
	CombatResultApplier.apply(state, result, db)

	assert_int(state.get_combatant(actor_id).experience).is_equal(0)


func _build_database_with_reward(reward: int) -> AlchemonDatabase:
	var tackle := AttackData.new()
	tackle.attack_name = "Tackle"
	tackle.power = 20

	var hero := AlchemonSheet.new("Hero", 30, 0)
	hero.attacks = [tackle]

	var slime := AlchemonSheet.new("Slime", 20, 1)
	slime.attacks = [tackle]
	slime.xp_reward = reward

	var db := AlchemonDatabase.new()
	db.alchemons = [hero, slime]
	return db
