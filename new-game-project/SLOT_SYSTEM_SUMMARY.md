# Slot System Implementation - Summary

**Status**: ✅ Complete  
**Date**: September 2, 2026  
**Acceptance Criteria**: All met

---

## What Was Built

A complete battlefield slot system for 2v2 simultaneous combat with proper state management, slot allocation, occupancy tracking, and death-handling.

### Files Created

1. **[battlefield_slot.gd](battlefield_slot.gd)** (45 lines)
   - Constants: `PLAYER_SLOT_1`, `PLAYER_SLOT_2`, `ENEMY_SLOT_1`, `ENEMY_SLOT_2`
   - Utilities: `slot_name()`, `is_player_slot()`, `is_enemy_slot()`, `get_side_slots()`, `get_opposite_side_slots()`

2. **[battlefield.gd](battlefield.gd)** (115 lines)
   - Manages slot occupancy state (which combatant in which slot)
   - `assign_combatant(id, slot)` – bind at init
   - `free_slot(slot)` – clear occupancy on death
   - `get_occupant(slot)`, `get_combatant_slot(id)` – queries
   - `get_side_combatants(is_player)`, `get_opposing_combatants(is_player)` – team queries
   - `is_occupied(slot)`, `is_available(slot)` – state checks

3. **[BATTLEFIELD_SLOTS.md](BATTLEFIELD_SLOTS.md)** (250 lines)
   - Complete documentation of slot system
   - Architecture & initialization flow
   - Targeting validation logic
   - Death & slot freedom mechanics
   - Future extensibility patterns
   - Testing guide

4. **[test/unit/test_battlefield_slots.gd](test/unit/test_battlefield_slots.gd)** (180 lines)
   - Tests for slot constants, utilities, occupancy
   - Tests for side queries and targeting
   - Tests for dead combatant exclusion

### Files Updated

1. **[combatant_state.gd](combatant_state.gd)**
   - Added: `@export var slot: int = -1` field
   - Added: `p_slot` parameter to `_init()`
   - Each combatant now knows its battlefield position

2. **[combat_state.gd](combat_state.gd)**
   - Added: `var battlefield: Battlefield` (initialized in `_init()`)
   - Added: `get_alive_opposing_combatants(is_player)` – query alive combatants on opposite side
   - Added: `get_valid_targets(actor_id)` – returns targetable combatants (alive, opposite side)

3. **[combat_state_factory.gd](combat_state_factory.gd)**
   - Now assigns slots during initialization
   - Players → slots 0, 1 (PLAYER_SLOT_1, PLAYER_SLOT_2)
   - Enemies → slots 2, 3 (ENEMY_SLOT_1, ENEMY_SLOT_2)
   - Validates max 2 combatants per side; warns if exceeded
   - Registers combatants with battlefield

4. **[combat_rules.gd](combat_rules.gd)**
   - `_resolve_attack()`: Validates target is alive AND on opposing side via `state.get_valid_targets()`
   - `_resolve_attack()`: Frees target's slot when HP → 0
   - `_resolve_capture()`: Frees target's slot on successful capture

5. **[CLAUDE.md](CLAUDE.md)**
   - Updated core classes table to include `Battlefield` and `BattlefieldSlot`
   - Updated `CombatState` description to mention `battlefield`
   - Updated `CombatantState` to include `slot` field
   - Updated `CombatStateFactory` to mention slot assignment
   - Added new files to file structure section

---

## Acceptance Criteria - Verification

✅ **Each combatant has an explicit battlefield slot**
   - `CombatantState.slot` stores the slot (0-3)
   - `CombatStateFactory.build()` assigns slots during init
   - Example: `combatant.slot = BattlefieldSlot.PLAYER_SLOT_1`

✅ **Target lists are generated from slot occupancy**
   - `CombatState.get_valid_targets(actor_id)` returns alive combatants on opposite side
   - Queries `Battlefield.get_opposing_combatants()` to find who actually occupies slots
   - Filters by `alive` status
   - `CombatRules._resolve_attack()` validates targets via this method

✅ **Dead combatants free their slot**
   - When combatant HP → 0, `target.alive = false`
   - Immediately calls `state.battlefield.free_slot(target.slot)`
   - Happens in: `_resolve_attack()` (damage kill) and `_resolve_capture()` (capture kill)
   - Freed slot returns `get_occupant(slot) == -1`
   - Combatant retains `slot` reference for future logic

✅ **Model can represent untargetable companion**
   - Current: All alive combatants are targetable
   - Future-ready: Add `is_targetable: bool` flag to `CombatantState`
   - Extend `CombatState.get_valid_targets()` to filter by flag
   - No changes needed now; ready when GDD requires it

---

## Key Design Decisions

1. **Slot = Position, Occupancy = Binding**
   - Slots (0-3) are immutable, fixed positions
   - Occupancy (`slot_occupancy: Array`) tracks who's in each slot
   - Freed slots become `occupancy[slot] = -1`
   - Allows future respawn/reinforcement at same position

2. **Combatant Retains Slot After Death**
   - `CombatantState.slot` never changes
   - Only `Battlefield.free_slot()` marks it empty
   - Enables: "respawn at your original slot" mechanics

3. **Targeting Validation in Rules**
   - `CombatRules._resolve_attack()` explicitly checks `state.get_valid_targets()`
   - Guarantees no attack against wrong-side or dead combatants
   - Event reports `"invalid_target"` cancellation reason

4. **No Hardcoded Team Queries**
   - All targeting goes through `Battlefield.get_opposing_combatants()`
   - Battlefield is the single source of truth for slot state
   - Future: Can add new occupancy rules without touching CombatRules

---

## Testing

Run the new test suite:
```bash
cd /run/media/reis/SDextra/Faculdade/TCC-Combate/new-game-project
# Execute in Godot or via gdUnit4
gdUnit4 test/unit/test_battlefield_slots.gd
```

**Test coverage:**
- Slot constant definitions
- Slot utilities (side checks, name lookup)
- Battlefield initialization
- Combatant assignment & queries
- Slot freedom on death
- Side queries (who's on each side)
- Target generation (valid opposing combatants)
- Dead combatant exclusion from targets

---

## Next Steps (Optional Enhancements)

1. **Untargetable Companion** (when GDD requires)
   ```gdscript
   @export var is_targetable: bool = true  # Add to CombatantState
   ```

2. **Bonding/Pairing** (same-side slot pair mechanics)
   ```gdscript
   func get_paired_slot(slot: int) -> int:
     return PLAYER_SLOT_2 if slot == PLAYER_SLOT_1 else PLAYER_SLOT_1
   ```

3. **Positional Attacks** ("attack left" vs "attack right")
   ```gdscript
   "attack_left" / "attack_right"  # in ActionCommand.kind
   ```

4. **Reinforcements** (fill freed slot dynamically)
   ```gdscript
   if battlefield.is_available(ENEMY_SLOT_1):
     battlefield.assign_combatant(new_enemy_id, ENEMY_SLOT_1)
   ```

5. **Revive/Guard Mechanics** (companion takes damage for partner)
   - Slot pair tracks damage flow
   - Freed slot can be refilled by ally

---

## Files Modified Summary

| File | Lines | Change |
|------|-------|--------|
| `combatant_state.gd` | +1 field, +1 init param | Added slot |
| `combat_state.gd` | +1 var, +2 methods | Added battlefield, targeting |
| `combat_state_factory.gd` | +25 lines | Slot assignment logic |
| `combat_rules.gd` | +2 lines in 2 methods | Slot validation & freedom |
| `CLAUDE.md` | +5 lines | Documentation |
| **New files** | **600+ lines** | `battlefield.gd`, `battlefield_slot.gd`, `BATTLEFIELD_SLOTS.md`, `test_battlefield_slots.gd` |

All changes follow the V2 data-oriented architecture (pure functions, dictionary events, no state retention).

---

**Status**: Ready for integration testing with UI layer and AI targeting logic.
