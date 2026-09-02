# Battlefield Slot System

## Overview

The slot system provides a stable foundation for combat mechanics by assigning each combatant an explicit position on the battlefield. This enables:

- **Consistent targeting**: Target lists are generated from slot occupancy, not assumptions about who exists
- **Positional rules**: Future bonding, companion mechanics, and positioning-based rules can anchor to slots
- **Untargetable companions**: The model naturally supports companions who occupy a slot but aren't targetable
- **Slot freedom on death**: Dead combatants free their slot for future mechanics (respawn, reinforcements, etc.)

## Architecture

### BattlefieldSlot (Constants)
Defines 4 fixed battlefield positions:

```gdscript
const PLAYER_SLOT_1 := 0
const PLAYER_SLOT_2 := 1
const ENEMY_SLOT_1 := 2
const ENEMY_SLOT_2 := 3
```

Each side has exactly 2 slots. The enum itself is immutable; only occupancy changes.

### Battlefield (Class)
Manages slot occupancy: which combatant occupies which slot, or whether a slot is empty/freed.

**Key methods:**
- `assign_combatant(combatant_id, slot)` – Bind a combatant to a slot (init-time)
- `get_occupant(slot) -> int` – Who occupies this slot? (returns -1 if empty/freed)
- `get_combatant_slot(combatant_id) -> int` – Which slot does this combatant occupy? (returns -1 if not found)
- `free_slot(slot)` – Combatant died; clear occupancy (slot association remains for logic)
- `get_side_combatants(is_player) -> Array[int]` – All combatants currently occupying slots on a side
- `get_opposing_combatants(is_player) -> Array[int]` – All combatants on the opposite side

**Example:**
```gdscript
var battlefield = Battlefield.new()
battlefield.assign_combatant(combatant_id=0, slot=BattlefieldSlot.PLAYER_SLOT_1)
# Later, when combatant 0 dies:
battlefield.free_slot(BattlefieldSlot.PLAYER_SLOT_1)  # Now slot is empty, but still exists
```

### CombatState Integration
`CombatState` now owns a `Battlefield` instance and provides convenience methods:

```gdscript
var battlefield: Battlefield  # Owns slot state

func get_alive_opposing_combatants(is_player: bool) -> Array[int]
  # Returns IDs of alive combatants on the opposing side (occupying slots)

func get_valid_targets(actor_id: int) -> Array[int]
  # Returns all valid targets from actor's perspective
  # = alive combatants on the opposite side
```

### CombatantState Update
Each combatant now has an explicit slot assignment:

```gdscript
@export var slot: int = -1  # BattlefieldSlot.* or -1 if unassigned
```

Set during initialization by `CombatStateFactory`.

## Initialization Flow

`CombatStateFactory.build()` now:
1. Creates `CombatState` (which initializes `Battlefield`)
2. For each player combatant, assigns the next available player slot (0, then 1)
3. For each enemy combatant, assigns the next available enemy slot (2, then 3)
4. Logs warnings if more than 2 combatants per side (can't fit)

```gdscript
var state = CombatStateFactory.build(database, [1, 2], [3, 4])
# Result:
# - Combatant 0 (species 1, player) -> slot 0
# - Combatant 1 (species 2, player) -> slot 1
# - Combatant 2 (species 3, enemy) -> slot 2
# - Combatant 3 (species 4, enemy) -> slot 3
```

## Combat Rules Integration

### Targeting
`_resolve_attack()` now validates that the target is:
1. Alive
2. Actually on the opposing side (via `state.get_valid_targets()`)

If targeting fails, the action is cancelled with reason `"invalid_target"`.

### Death & Slot Freedom
When a combatant dies (HP → 0):
- `CombatantState.alive` is set to `false`
- **Their slot is freed** via `state.battlefield.free_slot(target.slot)`

This happens in both:
- `_resolve_attack()` (when damage kills)
- `_resolve_capture()` (when capture succeeds)

Freeing a slot means:
- `battlefield.get_occupant(slot)` returns `-1`
- The combatant still retains `combatant_state.slot` for reference (slot association)
- Future logic can detect the freed slot and act on it

**Example:**
```gdscript
# Combatant at enemy slot 1 dies
target.alive = false
state.battlefield.free_slot(target.slot)  # Frees ENEMY_SLOT_1

# Later, we want to spawn a reinforcement in that slot:
var reinforcement = CombatantState.new(..., p_slot=ENEMY_SLOT_1)
state.battlefield.assign_combatant(reinforcement.id, ENEMY_SLOT_1)
```

## Untargetable Companions (Future-Proof)

The model naturally supports companions who occupy a slot but aren't targetable:

**Option A: Companion flag**
```gdscript
@export var is_targetable: bool = true
```

Then in `CombatRules.get_valid_targets()`:
```gdscript
func get_valid_targets_including_untargetable(actor_id: int) -> Array[int]:
  var opposing := state.get_alive_opposing_combatants(actor_id.is_player)
  return opposing.filter(func(id): return state.get_combatant(id).is_targetable)
```

**Option B: Battlefield query**
```gdscript
# Battlefield tracks targetable slots separately
func get_targetable_slots(is_player: bool) -> Array[int]:
  return get_occupied_side_slots(is_player).filter(func(slot):
    return not is_untargetable_slot(slot))
```

For now, all alive combatants are targetable. Add the flag when GDD requires it.

## Testing Slot Logic

Key scenarios to verify:

1. **Initialization**: All combatants have assigned slots; battlefield matches
   ```gdscript
   var state = CombatStateFactory.build(db, [1, 2], [3, 4])
   assert state.get_combatant(0).slot == BattlefieldSlot.PLAYER_SLOT_1
   assert state.battlefield.get_occupant(BattlefieldSlot.PLAYER_SLOT_1) == 0
   ```

2. **Target generation**: Valid targets = alive combatants on opposite side
   ```gdscript
   var targets = state.get_valid_targets(0)  # player attacks
   assert 2 in targets and 3 in targets  # enemies are valid
   assert 1 not in targets  # other player is invalid
   ```

3. **Slot freedom on death**: Dead combatant frees slot, slot can be reused
   ```gdscript
   # Attack kills enemy at slot 2
   CombatRules._resolve_attack(state, command, db)
   assert state.battlefield.get_occupant(BattlefieldSlot.ENEMY_SLOT_1) == -1
   
   # Reinforcement can take that slot
   state.battlefield.assign_combatant(new_enemy_id, BattlefieldSlot.ENEMY_SLOT_1)
   assert state.battlefield.get_occupant(BattlefieldSlot.ENEMY_SLOT_1) == new_enemy_id
   ```

4. **Target validation**: Targeting a dead combatant or wrong-side combatant is cancelled
   ```gdscript
   var command = ActionCommand.new(0, "attack", 1, 0)  # player targets player
   var result = CombatRules.resolve_action(state, command, db)
   assert result.kind == "cancelled"
   assert result.reason == "invalid_target"
   ```

## Future Extensions

This foundation enables:

- **Bonding mechanics**: Companion in slot 1 boosts companion in slot 2
- **Positional attacks**: "Attack left" vs "attack right"
- **Reinforcements**: Defeated combatant leaves empty slot; replacement fills it
- **Revive mechanics**: Resurrect at the vacated slot
- **Guard mechanics**: Companion takes damage meant for another in same slot-pair
- **Fleeing from slot**: Track which combatant fled and why
