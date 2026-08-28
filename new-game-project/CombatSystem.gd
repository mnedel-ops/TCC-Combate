class_name CombatSystem
extends RefCounted

## Sistema puro: recebe AlchemonSheet, calcula, devolve resultado (Dictionary)
## ou muta o dado diretamente (hp/alive). Nunca toca em Label, Button, _log,
## nem sabe que existe UI. Tudo aqui e testavel sem nenhum node na arvore.

const MISS_CHANCE := 1.0 / 6.0
const FLEE_CHANCE := 5.0 / 6.0
const CAPTURE_CHANCE := 2.0 / 6.0
const ITEM_HEAL_AMOUNT := 6
const CRIT_ROLL_MAX := 20     # 1 em 20
const CRIT_MULTIPLIER := 1.5


static func roll_initiative(all_combatants: Array[AlchemonSheet]) -> Array[AlchemonSheet]:
	for c in all_combatants:
		c.initiative = randi_range(1, 20)

	var sorted_order := all_combatants.duplicate()
	sorted_order.sort_custom(func(a, b): return a.initiative > b.initiative)
	return sorted_order


static func resolve_attack(actor: AlchemonSheet, target: AlchemonSheet, attack: AttackData) -> Dictionary:
	if randf() < MISS_CHANCE:
		return {"kind": "attack_miss", "actor": actor, "target": target, "attack_name": attack.attack_name}

	var is_critical := randi_range(1, CRIT_ROLL_MAX) == CRIT_ROLL_MAX
	var final_damage := attack.damage
	if is_critical:
		final_damage = int(round(final_damage * CRIT_MULTIPLIER))

	target.hp = max(target.hp - final_damage, 0)
	if target.hp == 0:
		target.alive = false

	return {
		"kind": "attack_hit",
		"actor": actor,
		"target": target,
		"damage": final_damage,
		"critical": is_critical,
		"attack_name": attack.attack_name,
	}


static func pick_random_attack(actor: AlchemonSheet) -> AttackData:
	if actor.attacks.is_empty():
		return null
	return actor.attacks[randi() % actor.attacks.size()]


static func resolve_item(actor: AlchemonSheet, target: AlchemonSheet) -> Dictionary:
	target.hp = min(target.hp + ITEM_HEAL_AMOUNT, target.max_hp)
	return {"kind": "item_used", "actor": actor, "target": target, "amount": ITEM_HEAL_AMOUNT}


static func resolve_capture(actor: AlchemonSheet, target: AlchemonSheet) -> Dictionary:
	if randf() < CAPTURE_CHANCE:
		target.alive = false
		target.hp = 0
		return {"kind": "capture_success", "actor": actor, "target": target}

	return {"kind": "capture_fail", "actor": actor, "target": target}


static func attempt_flee() -> bool:
	return randf() < FLEE_CHANCE


static func is_team_alive(team: Array[AlchemonSheet]) -> bool:
	return team.any(func(c): return c.alive)


static func pick_random_alive_target(team: Array[AlchemonSheet]) -> AlchemonSheet:
	var alive_members := team.filter(func(c): return c.alive)
	if alive_members.is_empty():
		return null
	return alive_members[randi() % alive_members.size()]
