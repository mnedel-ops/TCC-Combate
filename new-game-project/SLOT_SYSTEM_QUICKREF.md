# Slot System - Quick Reference Card

## Core Concepts (30 seconds)

**Slots** = 4 fixed battlefield positions (2 player, 2 enemy)
```
Players:  [SLOT_0] [SLOT_1]
Enemies:  [SLOT_2] [SLOT_3]
```

**Occupancy** = Which combatant is in which slot (or empty if dead)
```
slot_occupancy[0] = -1           # Slot 0 empty (or slot freed)
slot_occupancy[0] = combatant_id # Slot 0 occupied by this combatant
```

**Target Lists** = Generated from occupancy, not hardcoded
```
valid_targets = all_alive_on_opposing_side
```

## API Cheat Sheet

### Initialization
```gdscript
var state = CombatStateFactory.build(database, players, enemies)
# → All combatants assigned slots, battlefield initialized
```

### Queries
```gdscript
state.get_valid_targets(actor_id)                      # Who can I attack?
state.battlefield.get_occupant(slot)                   # Who's in this slot?
state.battlefield.get_combatant_slot(id)               # Where is this combatant?
state.battlefield.get_side_combatants(is_player)       # All on this side?
state.battlefield.get_opposing_combatants(is_player)   # All on opposite side?
state.battlefield.is_occupied(slot)                    # Slot has someone?
state.battlefield.is_available(slot)                   # Slot is empty?
```

### Slot Utilities
```gdscript
BattlefieldSlot.slot_name(slot)                        # "Player Slot 1"
BattlefieldSlot.is_player_slot(slot)                   # true/false
BattlefieldSlot.is_enemy_slot(slot)                    # true/false
BattlefieldSlot.get_side_slots(is_player)              # [0, 1] or [2, 3]
```

### Death & Slot Freedom
```gdscript
# When combatant dies in CombatRules:
target.alive = false
state.battlefield.free_slot(target.slot)
# Now: get_valid_targets() won't include them, slot is empty
```

### Reinforcements (Future)
```gdscript
var new_combatant = CombatantState.new(..., p_slot=BattlefieldSlot.ENEMY_SLOT_1)
state.battlefield.assign_combatant(new_combatant.id, BattlefieldSlot.ENEMY_SLOT_1)
```

## Integration Points

### For UI Layer
```gdscript
# Show combatants in correct positions
for side in [true, false]:
  for slot in BattlefieldSlot.get_side_slots(side):
    var occupant_id = state.battlefield.get_occupant(slot)
    if occupant_id != -1:
      # Draw at position for this slot
```

### For AI Targeting
```gdscript
# Pick random valid target
var targets = state.get_valid_targets(enemy_id)
if not targets.is_empty():
  var target = targets[randi() % targets.size()]
```

### For Attack Resolution
```gdscript
# CombatRules already validates via get_valid_targets()
# If target is dead or wrong-side: event returns "cancelled" with reason
```

## Files to Review

| File | Purpose |
|------|---------|
| [battlefield_slot.gd](battlefield_slot.gd) | Slot constants & helpers |
| [battlefield.gd](battlefield.gd) | Occupancy management (main logic) |
| [combat_state.gd](combat_state.gd) | Targeting convenience methods |
| [combat_state_factory.gd](combat_state_factory.gd) | Initialization |
| [BATTLEFIELD_SLOTS.md](BATTLEFIELD_SLOTS.md) | Full documentation |

## Common Patterns

**Check if side is completely defeated:**
```gdscript
var alive_players = state.get_alive_ids(state.player_ids)
if alive_players.is_empty():
  # Enemy won
```

**Get reinforcement slot:**
```gdscript
var enemy_slots = BattlefieldSlot.get_side_slots(false)
for slot in enemy_slots:
  if state.battlefield.is_available(slot):
    # Use this slot for reinforcement
    return slot
```

**Bonding check (when implemented):**
```gdscript
func has_partner(combatant_id: int) -> bool:
  var slot = state.battlefield.get_combatant_slot(combatant_id)
  var partner_slot = get_pair_slot(slot)  # TODO: implement
  return state.battlefield.is_occupied(partner_slot)
```

## Testing

```gdscript
# Unit tests already written:
test/unit/test_battlefield_slots.gd

# Key scenarios covered:
# ✓ Initialization & slot assignment
# ✓ Occupancy queries
# ✓ Slot freedom on death
# ✓ Target generation
# ✓ Dead combatant exclusion
```

---

**Status**: Ready for UI integration and AI targeting logic. No additional changes needed to core system unless GDD adds new positional mechanics.
