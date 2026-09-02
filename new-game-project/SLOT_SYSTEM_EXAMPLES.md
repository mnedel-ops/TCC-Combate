# Slot System - Usage Examples

Quick reference showing how the slot system works in practice.

## Initialization

```gdscript
# Create combat state with 2 players vs 2 enemies
var database = AlchemonDatabase.new()
var state = CombatStateFactory.build(
  database,
  [species_id_1, species_id_2],  # player team
  [species_id_3, species_id_4]   # enemy team
)

# After build():
# state.combatants[0].slot == BattlefieldSlot.PLAYER_SLOT_1
# state.combatants[1].slot == BattlefieldSlot.PLAYER_SLOT_2
# state.combatants[2].slot == BattlefieldSlot.ENEMY_SLOT_1
# state.combatants[3].slot == BattlefieldSlot.ENEMY_SLOT_2
#
# state.battlefield.get_occupant(BattlefieldSlot.PLAYER_SLOT_1) == 0
# state.battlefield.get_occupant(BattlefieldSlot.PLAYER_SLOT_2) == 1
# state.battlefield.get_occupant(BattlefieldSlot.ENEMY_SLOT_1) == 2
# state.battlefield.get_occupant(BattlefieldSlot.ENEMY_SLOT_2) == 3
```

## Targeting

```gdscript
# Player 0 wants to know valid targets
var valid_targets = state.get_valid_targets(0)
# Returns: [2, 3]  (enemies only, must be alive)

# Enemy 2 wants to know valid targets
var enemy_targets = state.get_valid_targets(2)
# Returns: [0, 1]  (players only, must be alive)

# Query what combatants occupy the opposing side
var opposing = state.battlefield.get_opposing_combatants(true)  # I'm player
# Returns: [2, 3]  (enemies occupying slots)
```

## Executing an Attack

```gdscript
var command = ActionCommand.new(0, "attack", 2, 0)  # P0 attacks E2 with move 0
var result = CombatRules.resolve_action(state, command, database)

if result.kind == "attack_hit":
  # E2 took damage
  # If E2 HP reaches 0:
  #   state.battlefield.free_slot(E2.slot)  # E2.slot = ENEMY_SLOT_1
  #   E2.alive = false
  
  # Now targeting E2 is invalid
  var targets = state.get_valid_targets(0)
  # Returns: [3]  (only E3 now, E2 is dead)
  
  # ENEMY_SLOT_1 is now empty
  assert state.battlefield.get_occupant(BattlefieldSlot.ENEMY_SLOT_1) == -1
```

## Dead Combatant Handling

```gdscript
# After E2 dies (HP → 0 from attack)
var dead_enemy = state.get_combatant(2)
assert dead_enemy.alive == false
assert dead_enemy.slot == BattlefieldSlot.ENEMY_SLOT_1  # Still knows original slot

# Slot is freed
assert state.battlefield.is_occupied(BattlefieldSlot.ENEMY_SLOT_1) == false
assert state.battlefield.is_available(BattlefieldSlot.ENEMY_SLOT_1) == true
assert state.battlefield.get_occupant(BattlefieldSlot.ENEMY_SLOT_1) == -1

# But if reinforcements arrive...
var reinforcement = CombatantState.new(4, species_5, 20, false, BattlefieldSlot.ENEMY_SLOT_1)
state.combatants[4] = reinforcement
state.enemy_ids.append(4)
state.battlefield.assign_combatant(4, BattlefieldSlot.ENEMY_SLOT_1)

# Slot is re-occupied
assert state.battlefield.get_occupant(BattlefieldSlot.ENEMY_SLOT_1) == 4
```

## Invalid Targeting Detection

```gdscript
# Try to target a dead enemy
var dead_target_command = ActionCommand.new(0, "attack", 2, 0)
var result = CombatRules.resolve_action(state, dead_target_command, database)

if result.kind == "cancelled":
  if result.reason == "target_dead":
    print("Target is dead")
  elif result.reason == "invalid_target":
    print("Target not on opposing side (shouldn't happen in normal combat)")
```

## Capture (Also Frees Slot)

```gdscript
var capture_command = ActionCommand.new(0, "capture", 2, 0)
var result = CombatRules._resolve_capture(state, capture_command)

if result.kind == "capture_success":
  # Captured enemy dies and frees slot
  var target = state.get_combatant(2)
  assert target.alive == false
  assert target.hp == 0
  assert state.battlefield.get_occupant(target.slot) == -1
```

## Querying Side Occupancy

```gdscript
# Who's on the player side (occupying slots)?
var player_combatants = state.battlefield.get_side_combatants(true)
# Returns: [0, 1]  (IDs of combatants in player slots)

# Who's on the enemy side?
var enemy_combatants = state.battlefield.get_side_combatants(false)
# Returns: [3]  (ID 2 is dead, freed slot; only 3 remains)

# Get all occupied slots
var occupied = state.battlefield.get_occupied_slots()
# Returns: [0, 1, 3]  (slots 0, 1, 3 are occupied; slot 2 is freed)

# Get occupied slots on a side
var occupied_enemy_slots = state.battlefield.get_occupied_side_slots(false)
# Returns: [3]  (ENEMY_SLOT_2 occupied, ENEMY_SLOT_1 freed)
```

## Slot Utilities

```gdscript
# Get friendly name of slot
var name = BattlefieldSlot.slot_name(BattlefieldSlot.PLAYER_SLOT_1)
# Returns: "Player Slot 1"

# Check which side a slot belongs to
if BattlefieldSlot.is_player_slot(BattlefieldSlot.PLAYER_SLOT_2):
  print("Slot 1 is a player slot")

if BattlefieldSlot.is_enemy_slot(BattlefieldSlot.ENEMY_SLOT_1):
  print("Slot 2 is an enemy slot")

# Get all slots for a side
var player_slots = BattlefieldSlot.get_side_slots(true)
# Returns: [0, 1]

var enemy_slots = BattlefieldSlot.get_side_slots(false)
# Returns: [2, 3]

# Get opposite side slots
var from_player_perspective = BattlefieldSlot.get_opposite_side_slots(true)
# Returns: [2, 3]  (enemy slots)
```

## Future: Untargetable Companion

```gdscript
# When GDD requires:
@export var is_targetable: bool = true

# UI can show it but can't select it
var targetable_enemies = state.get_valid_targets(0)
# Would filter out `is_targetable == false` combatants

# Companion still occupies slot
var slot = state.battlefield.get_combatant_slot(untargetable_id)
# Still returns valid slot; just not targetable

# Companion can still take damage via events (guard mechanics)
```

## Future: Positional Bonding

```gdscript
# Combatants in paired slots (1 & 2) can interact
func get_slot_pair(slot: int) -> int:
  match slot:
    BattlefieldSlot.PLAYER_SLOT_1: return BattlefieldSlot.PLAYER_SLOT_2
    BattlefieldSlot.PLAYER_SLOT_2: return BattlefieldSlot.PLAYER_SLOT_1
    BattlefieldSlot.ENEMY_SLOT_1: return BattlefieldSlot.ENEMY_SLOT_2
    BattlefieldSlot.ENEMY_SLOT_2: return BattlefieldSlot.ENEMY_SLOT_1
  return -1

# Check if pair is complete
var my_slot = combatant.slot
var pair_slot = get_slot_pair(my_slot)
var pair_occupied = state.battlefield.is_occupied(pair_slot)

if pair_occupied:
  # Bonding effects active
  var pair_id = state.battlefield.get_occupant(pair_slot)
  var pair = state.get_combatant(pair_id)
  # Apply bonding buffs
```
