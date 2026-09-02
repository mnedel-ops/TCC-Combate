# CLAUDE.md — Godot Combat System

## Overview
- **Engine**: Godot 4.6 | **Language**: GDScript
- **Game**: Alchemons (creature-capture RPG)
- **Scope**: 2v2 simultaneous turn-based combat, speed ordering, capture/item systems
- **Status**: V2 refactor (data-oriented) live alongside V1 production code

## Conventions

**Code**: Static typing mandatory • Composition > inheritance • "Call down, signal up" (parent→child methods, child→parent signals) • Never edit `.tscn` files • `.duplicate()` Resources before runtime mutation • Immutable value objects (CombatState, ActionCommand)

**Naming**: `snake_case` files/vars/methods • `PascalCase` nodes • `UPPER_SNAKE_CASE` constants • `_prefix` private • `is_`/`has_` booleans

## Core Classes (V2 Data-Oriented)

| Class | Role |
|-------|------|
| **CombatState** | Single source of truth: `combatants`, `player_ids`, `enemy_ids`, `turn_order_ids`, `pending_actions`, `phase`, `round_number`, `battlefield` |
| **ActionCommand** | Immutable value object: `actor_id`, `kind` ("attack"\|"item"\|"capture"\|"flee"), `target_id`, `attack_index` |
| **CombatantState** | Battle state per creature: `id`, `species_id`, `slot`, `current_hp`, `max_hp`, `initiative`, `alive` |
| **CombatRules** | Pure rules engine—all static methods taking `state: CombatState` + `database: AlchemonDatabase`. Returns event Dictionaries. `roll_initiative()`, `resolve_action()`, `_resolve_attack()`, `_resolve_item()`, `_resolve_capture()` |
| **CombatStateFactory** | Initializes `CombatState` with combatants; assigns slots (2 per side) |
| **Battlefield** | Manages slot occupancy: 4 positions (2 player, 2 enemy). Tracks which combatant occupies which slot; frees slots on death. |
| **BattlefieldSlot** | Constants: `PLAYER_SLOT_1`, `PLAYER_SLOT_2`, `ENEMY_SLOT_1`, `ENEMY_SLOT_2`. Utility: `slot_name()`, `is_player_slot()`, `get_side_slots()` |
| **CombatControllerStates** | FSM: phases = `"selecting_actions" → "resolving_round" → "combat_over"` |
| **CombatEvent** | Event log entry describing action outcome |
| **AlchemonDatabase** | Lookup: `get_by_id(species_id)` → `AlchemonSheet` (species template, immutable—`.duplicate()` before mutation) |


## Combat Flow

1. `CombatStateFactory` creates `CombatState`
2. `CombatRules.roll_initiative()` → populates `turn_order_ids`
3. Each round:
   - `selecting_actions`: Players/AI queue `ActionCommand` 
   - `resolving_round`: For each ID in `turn_order_ids`, call `CombatRules.resolve_action()` → get event → update UI
   - Check victory → if yes, `combat_over`

## File Structure

```
├── combat_rules.gd              # Rules engine (static methods, pure)
├── combat_state.gd              # State container (immutable after init)
├── action_command.gd            # Action value object
├── combatant_state.gd           # Per-creature battle state
├── combat_state_factory.gd      # State initialization + slot assignment
├── battlefield.gd               # Slot occupancy management
├── battlefield_slot.gd          # Slot constants & utilities
├── combat_controller_states.gd  # Phase FSM
├── combat_event.gd              # Event log entry
├── combat_states_ui.gd          # UI presentation
├── combat_refactored.tscn       # Main scene (V2)
├── BATTLEFIELD_SLOTS.md         # Slot system documentation
├── Alchemons/                   # Database: AlchemonDataBase.gd, AlchemonSheet.gd, *.tres
├── Attack/                      # AttackData.gd, *.tres
├── prototype/v1/                # Legacy V1 (still in production)
└── test/unit/test_combat_rules.gd
```

## Critical Constraints

1. **Never edit `.tscn` files** – read-only
2. **IDs not references** – store `int` IDs, resolve names via `AlchemonDatabase` at display time
3. **`.duplicate()` Resources** before runtime mutation (AlchemonSheet, AttackData)
4. **Immutable by design** – CombatState/ActionCommand created whole, then read
5. **Static rules** – CombatRules has no context; everything passed in
6. **Events as results** – `resolve_action()` returns `Dictionary` events; UI reacts
7. **Tests pending** – current tests expect `TransitionResult`/`end_round` API (not yet in `combat_rules.gd`)

## Constants (CombatRules)

```gdscript
const MISS_CHANCE := 1.0 / 6.0
const FLEE_CHANCE := 5.0 / 6.0
const CAPTURE_CHANCE := 2.0 / 6.0
const ITEM_HEAL_AMOUNT := 6
const CRIT_ROLL_MAX := 20
const CRIT_MULTIPLIER := 1.5
```
