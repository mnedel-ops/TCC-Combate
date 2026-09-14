class_name BondRules
extends RefCounted

## Laco entre 2 aliados em campo (GDD sec 9). Escopo atual: so decide
## Mistura vs Composto pelo tipo dos elementos (AlchemonType.Type - o
## mesmo enum usado pra type effectiveness, sem sistema de tipo separado)
## - sem contagem de eletrons, sem PC, sem ruptura por temperatura ainda.
##
## Regra (simplificada para esta fase):
##   metal + metal      -> MIXTURE
##   metal + nao-metal  -> COMPOUND (metal vira Cation, nao-metal vira Anion -
##                          combina com quimica real: metal doa eletron -> cation)
##   nao-metal + nao-metal -> NONE (nao suportado ainda)

const NONE := "none"
const MIXTURE := "mixture"
const COMPOUND := "compound"

const MIXTURE_BONUS := 8            # flat, GDD sec 9.1, aplicado em HP e Energia
const COMPOUND_TRANSFER_RATIO := 0.7  # GDD sec 9.2, % dos atributos do Cation que o Anion absorve


static func determine_bond_kind(type_a: AlchemonType.Type, type_b: AlchemonType.Type) -> String:
	var a_metal := type_a == AlchemonType.Type.METAL
	var b_metal := type_b == AlchemonType.Type.METAL
	if a_metal and b_metal:
		return MIXTURE
	if a_metal != b_metal:
		return COMPOUND
	return NONE


## Attempts to bond actor_id + partner_id. Both must be alive, unbonded,
## and on the same side (caller/controller already restricts target list
## to allies - this only re-validates, never assumes the caller was correct).
static func form_bond(state: CombatState, database: AlchemonDatabase, actor_id: int, partner_id: int) -> Dictionary:
	var a := state.get_combatant(actor_id)
	var b := state.get_combatant(partner_id)

	if a == null or b == null or not a.alive or not b.alive:
		return {"kind": "cancelled", "reason": "invalid_bond_target"}
	if a.id == b.id:
		return {"kind": "cancelled", "reason": "invalid_bond_target"}
	if a.bond_kind != NONE or b.bond_kind != NONE:
		return {"kind": "cancelled", "reason": "already_bonded"}

	var type_a: AlchemonType.Type = database.get_by_id(a.species_id).element_type
	var type_b: AlchemonType.Type = database.get_by_id(b.species_id).element_type
	var kind := determine_bond_kind(type_a, type_b)

	match kind:
		MIXTURE:
			_apply_mixture(a, b)
			return {"kind": "mixture_formed", "actor_id": a.id, "target_id": b.id}
		COMPOUND:
			var a_is_cation := type_a == AlchemonType.Type.METAL
			var cation := a if a_is_cation else b
			var anion := b if a_is_cation else a
			_apply_compound(anion, cation)
			return {"kind": "compound_formed", "actor_id": a.id, "target_id": b.id, "anion_id": anion.id, "cation_id": cation.id}
		_:
			return {"kind": "cancelled", "reason": "unsupported_bond_combo"}


static func _apply_mixture(a: CombatantState, b: CombatantState) -> void:
	a.max_hp += MIXTURE_BONUS
	a.hp += MIXTURE_BONUS
	a.max_valence_electrons += MIXTURE_BONUS
	a.valence_electrons += MIXTURE_BONUS
	a.bond_kind = MIXTURE
	a.bond_partner_id = b.id

	b.max_hp += MIXTURE_BONUS
	b.hp += MIXTURE_BONUS
	b.max_valence_electrons += MIXTURE_BONUS
	b.valence_electrons += MIXTURE_BONUS
	b.bond_kind = MIXTURE
	b.bond_partner_id = a.id


## Anion absorbs 70% of Cation's attributes and becomes the pair's sole
## actor (Cation gets excluded from action-selection/targeting elsewhere
## via CombatState.get_active_ids - see combat_state.gd).
static func _apply_compound(anion: CombatantState, cation: CombatantState) -> void:
	var hp_transfer := int(floor(cation.max_hp * COMPOUND_TRANSFER_RATIO))
	var energy_transfer := int(floor(cation.max_valence_electrons * COMPOUND_TRANSFER_RATIO))

	anion.max_hp += hp_transfer
	anion.hp += hp_transfer
	anion.max_valence_electrons += energy_transfer
	anion.valence_electrons += energy_transfer
	anion.bond_kind = COMPOUND
	anion.is_bond_cation = false
	anion.bond_partner_id = cation.id

	cation.bond_kind = COMPOUND
	cation.is_bond_cation = true
	cation.bond_partner_id = anion.id
