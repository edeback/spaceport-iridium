# WI-13 — Random Events v1

## Goal
The event-card framework: data-driven events that trigger on a schedule/conditions, present a choice card (or fire silently), and apply effects. Ships with a starter set exercising each effect type: market shock, ARC profit levy, drifting salvage cluster, and a morale event. Pirates/crises build on this later (Phase 3).

## Design
- **`EventData` (Resource):** id, title, body text, icon, weight, min_cycle (earliest occurrence), cooldown_cycles, `conditions: Array[EventCondition]` (Resource subclasses: MinCredits, MinCrew, HasModuleTag — same pattern as `UnlockEffect`), `choices: Array[EventChoice]` (label, `effects: Array[EventEffect]`, optional cost). Zero choices = notification-only event, effects auto-apply.
- **`EventEffect` subclasses v1:** `MarketSupplyShock` (resource id, multiplier, duration hours), `CreditDelta` (can be negative — the ARC levy), `SpawnSalvage` (spawn N ResourcePiles/asteroids with bonus contents in space), `HappinessModifier` (all crew, value, duration — plugs into WI-05 modifier list).
- **`EventManager`:** on `cycle_changed` (plus a mid-cycle random hour), rolls against a paced budget (e.g. one event per 1–2 cycles, weight-based selection among eligible events). Emits `event_triggered(event)`.
- **UI:** modal event card (title, body, choice buttons; pause-on-open — call TimeManager pause, restore prior speed on close). Notification-only events go to the alerts strip instead.
- **Market shock support:** MarketManager needs temporary supply modifiers: `apply_supply_modifier(resource, mult, hours)` — affects `default_market_supply` used in drift/pricing, with expiry via hour ticks.

## Files to touch
- **New:** `scripts/managers/event_manager.gd` (+ Global slot + main.tscn)
- **New:** `data/events/event_data.gd`, `event_condition.gd` (+ subclasses), `event_effect.gd` (+ subclasses), `event_choice.gd`; `data/events/*.tres` starter set (4–6 events)
- **New:** `ui/windows/event_card.gd/.tscn`
- `market_manager.gd` — supply modifiers with expiry
- `pawns/pawn_needs_component.gd` — station-wide happiness modifier entry point (via CrewManager roster from WI-07)
- `scripts/managers/signal_bus.gd` — `event_triggered`
- `scripts/managers/time_manager.gd` — no change (hooks exist)
- WI-03 followup: EventManager save (cooldowns, active timed effects with remaining duration, pending unshown event)

## Implementation order
1. Data types + EventManager selection/pacing + debug console/keybind to force-fire a specific event.
2. Event card UI with pause semantics.
3. Effects: CreditDelta → MarketSupplyShock (incl. MarketManager work) → SpawnSalvage → HappinessModifier.
4. Starter events + conditions.
5. Save section.

## Edge cases
- Event fires while another card is open → queue, show sequentially.
- Choice with a cost the player can't afford → button disabled with reason (every event must keep ≥1 always-available choice — validate at load, warn otherwise).
- Timed effects (shock, happiness) expiring across save/load → durations saved as remaining hours.
- SpawnSalvage while AsteroidManager is at its 15-asteroid cap → salvage spawns independent of that cap (piles, not asteroids, when possible).
- CreditDelta below zero credits → acceptable, debt will need to be paid off and contributes to game over flow (unable to hire new pawns)
- Event rolls while paused → EventManager runs on sim ticks, so it can't (verify).
- All events on cooldown/ineligible → roll is a no-op, no error.

## Verification
1. Debug-fire each starter event: card opens (game pauses), each choice's effects verifiably land (credits change; market price of the shocked resource jumps and decays back after the duration; salvage appears and is collectible; crew happiness dips and recovers).
2. Natural pacing: run 10 cycles at 4× → event count within expected band, no repeats within cooldown.
3. Two events forced simultaneously → sequential cards, no overlap.
4. Save/load with an active market shock at half-duration → shock resumes and expires on time.
5. Ineligible conditions respected (levy event requires min credits; set credits low → never fires).
