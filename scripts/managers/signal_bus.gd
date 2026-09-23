extends Node

## Every cross-system event in the game, in one place.
##
## Eleven of these have no listener in the base game and are declared a MOD API
## in the section at the foot of this file (WI-72). Read that before deleting one
## that "nothing uses" - and before adding a signal with no emitter, which is
## what `special_path_connection_added` was until WI-72 removed it.
##
## `tests/unit/test_signal_bus.gd` holds both halves: every signal here is
## emitted somewhere, and every signal is either connected in the base game or
## named in the MOD API list with a sentence saying what it promises.


@warning_ignore("unused_signal")
signal module_added(new_module: ModuleBase)
@warning_ignore("unused_signal")
signal module_removed(removed_module: ModuleBase)
@warning_ignore("unused_signal")
signal module_group_changed(module: ModuleBase)
@warning_ignore("unused_signal")
signal module_path_connection_removed(from: ModuleBase, to: ModuleBase)
@warning_ignore("unused_signal")
signal module_structure_connection_added(from: ModuleBase, to: ModuleBase, distance: float)
@warning_ignore("unused_signal")
signal module_structure_connection_removed(from: ModuleBase, to: ModuleBase)
@warning_ignore("unused_signal")
signal module_selected(selected_module: ModuleBase)
@warning_ignore("unused_signal")
signal global_unlock_changed(unlock: UnlockData)
@warning_ignore("unused_signal")
signal module_upgraded(module: ModuleBase)
@warning_ignore("unused_signal")
signal module_breach_started(module: ModuleBase)
@warning_ignore("unused_signal")
signal module_breach_sealed(module: ModuleBase)
## Module durability (WI-24). damaged fires on every hp loss (amount > 0),
## repaired on every hp gain. Destruction is [signal module_destroyed] in the MOD
## API section below; truss never emits that one - it enters its damaged state
## instead so the station can't split.
@warning_ignore("unused_signal")
signal module_damaged(module: ModuleBase, amount: float)
@warning_ignore("unused_signal")
signal module_repaired(module: ModuleBase, amount: float)
## Pirate raids (WI-32). raid_started fires when a wave spawns (carries its
## strength); raid_ended when the last ship leaves - by payoff, flight, or
## destruction - carrying how the raid resolved so the banner/alerts can react.
## A single ship dying is [signal ship_destroyed], below.
@warning_ignore("unused_signal")
signal raid_started(strength: float)
@warning_ignore("unused_signal")
signal raid_ended(outcome: StringName)
## Raid banner state changed (WI-32): ship count, payoff price, or warning phase
## moved. The raid banner refreshes off this without a full start/end cycle.
@warning_ignore("unused_signal")
signal raid_state_changed
@warning_ignore("unused_signal")
signal pawn_critical_need(pawn: PawnBase, need: StringName)
@warning_ignore("unused_signal")
signal crew_hired(pawn: PawnBase)
## Two pawns just finished a chat (WI-48). `positive` is the verdict they share;
## `delta` is the mean of the two opinion shifts, which can differ per direction.
## Emitted once per chat by the initiating component, never twice.
@warning_ignore("unused_signal")
signal pawns_chatted(a: PawnBase, b: PawnBase, positive: bool, delta: float)
## The recruitment candidate pool changed (WI-22): refreshed on a trader visit
## or a candidate hired. The open recruitment window re-reads on this.
@warning_ignore("unused_signal")
signal hire_candidates_changed
@warning_ignore("unused_signal")
signal crew_resigning(pawn: PawnBase, grace_hours: float)
@warning_ignore("unused_signal")
signal crew_resignation_cancelled(pawn: PawnBase)
## The grace window expired: the decision is final, CrewManager sends them off.
@warning_ignore("unused_signal")
signal crew_resigned(pawn: PawnBase)
## The pawn is actually gone (despawned at the bay or by escape pod).
@warning_ignore("unused_signal")
signal crew_departed(pawn: PawnBase)
## Game over (WI-07/WI-25): carries a player-facing reason so the end screen can
## explain how the run ended (crew abandonment, ARC repossession, ...). "" =
## keep the screen's default text.
@warning_ignore("unused_signal")
signal game_over(reason: String)
## Any economy ledger/loan/toggle state changed (WI-25). The economy page
## refreshes off this while open; charges, skims, and settlement all emit it.
@warning_ignore("unused_signal")
signal economy_changed
## The game world is up and ready to play (WI-18): emitted by Main once the
## starting station has spawned (new game) or SaveManager has applied a pending
## load. A single defined "game ready" moment for systems that need one
## (deterministic tests, loading screens) instead of guessing at boot timing.
@warning_ignore("unused_signal")
signal game_bootstrapped
## Generic station-wide alert text (WI-05). Fifty-odd emit sites, and it stays:
## "something happened, mention it" is the correct interface for most of them,
## a modded system (WI-47) emitting it still gets an alert, and the cheat
## console's "CHEAT: ..." messages are exactly what it is for.
##
## [AlertManager] subscribes and wraps each message as an [AlertData] at
## [constant AlertData.Priority.LOW]; sites that deserve a higher tier were
## migrated deliberately in WI-53 §4 rather than by a mechanical rename.
##
## The typed form a listener should prefer is [signal station_alert_raised], in
## the MOD API section below.
@warning_ignore("unused_signal")
signal station_alert(message: String)
## The live alert set changed in any way - raised, refreshed, acknowledged,
## resolved, aged out or cleared. The feed re-renders off this one signal rather
## than off six.
##
## Distinct from [signal transmissions_changed] even though [AlertManager] owns
## both lists: a LOW alert ageing out must not repaint the Comms panel, and a
## message being read must not repaint the alert feed.
@warning_ignore("unused_signal")
signal alerts_changed
## The transmission log changed (WI-57) - something arrived, or something was
## marked read. One signal for both, because the Comms feed and the console's
## unread badge re-derive from the log either way.
@warning_ignore("unused_signal")
signal transmissions_changed
@warning_ignore("unused_signal")
signal trader_arrived(trader: TraderData)
@warning_ignore("unused_signal")
signal trader_departed(trader: TraderData)
## A mineable body has entered the envelope (WI-63). Emitted beside the LOW
## arrival alert [AsteroidManager] already raises, because an alert is a thing to
## look at and this is a thing to react to. Carries the profile rather than the
## body so a listener can filter on the *kind* - comet, asteroid, a mod's own -
## without reaching into the instance.
@warning_ignore("unused_signal")
signal space_body_arrived(profile: SpaceBodyProfile)
## Goods physically left the station (WI-26): trader sell fulfillment and
## contract deliveries both emit this the moment stock leaves the export bin.
## UnlockManager accumulates it against the current station tier's export goals.
@warning_ignore("unused_signal")
signal resources_exported(resource: ResourceData, amount: int)
## The station tier advanced (WI-26): a passed ARC inspection (or the tier_up
## cheat) bumped UnlockManager.current_tier. The unlock panel re-evaluates
## tier-locked nodes off this; later WIs read current_tier for tier-gated systems.
@warning_ignore("unused_signal")
signal station_tier_changed(new_tier: int)
## Export-goal progress or inspection state changed (WI-26): the tier panel in
## the unlock screen refreshes off this without a full tier-up.
@warning_ignore("unused_signal")
signal station_tier_progress_changed
## The coarse "something about the visitor economy moved" nudge the UI reads
## (count, reputation, arrival or departure) without caring which (WI-33). The
## per-visitor signals are a MOD API and live below.
@warning_ignore("unused_signal")
signal visitors_changed
## The player clicked something in the world - a module footprint, a pawn, a pile
## or an asteroid (WI-74 §3). Emitted by the clicked object itself, so it is live
## for the call; [UIMain] dispatches it by type to the inspector, and a stacked
## module cell still goes through its click cycler. This is how the simulation
## reports a click without naming the HUD: no world object calls
## `Global.ui_main` any more, which is what lets the station run without one.
@warning_ignore("unused_signal")
signal world_object_clicked(object: Node2D)

# --- MOD API (WI-72) ----------------------------------------------------------
#
# Nothing in the base game listens to the eleven signals below. That is not the
# same as dead: each announces something a mod would plausibly want to hang off -
# a ship blown up, a contract offered, a visitor arrived - and each is emitted on
# the one code path that owns the event, so a listener cannot miss an occurrence
# or see a duplicate.
#
# They are therefore a PROMISE, and the sentence on each one is the promise: when
# it fires, what it carries, and what it does NOT cover. Changing a signature here
# breaks mods silently, because a connect() survives an arity change and only
# errors at emit time. Add to the list rather than repurposing an entry.
#
# A base-game listener may appear on any of these later; that is fine and needs no
# change here - the list says "no vanilla listener is required", not "none is
# allowed". What must not happen is one of them quietly losing its emitter:
# test_signal_bus.gd fails on a signal nothing emits, which is how the twelfth
# member of this list, `special_path_connection_added`, was found and deleted.

## A non-truss module hit 0 HP and is about to be torn down (WI-24). Fires from
## [method ModuleBase._on_hp_zero], immediately BEFORE remove_module, so the
## module is still whole and still in the tree when a listener sees it - which is
## the one frame in which salvage or a last reading can be taken off it.
##
## Destruction only. Deconstruction and a plain removal do not emit this, so
## listen for [signal module_removed] if "the module is gone" is the question
## (WI-71 F27, where an alert resolved on the wrong one of the two).
@warning_ignore("unused_signal")
signal module_destroyed(module: ModuleBase)

## A pirate ship hit 0 HP (WI-32), emitted the instant before it frees, so
## salvage drops and kill counters hang off one place. The node is valid for the
## duration of the call and not afterwards.
@warning_ignore("unused_signal")
signal ship_destroyed(ship: Node2D)

## A pawn's skill crossed into a new level (WI-22). `new_level` is the level just
## reached, so a listener never has to diff. Emitted once per level, including
## when a single xp award carries a pawn through more than one.
@warning_ignore("unused_signal")
signal pawn_skill_leveled(pawn: PawnBase, skill: StringName, new_level: int)

## A classified alert was raised or refreshed (WI-53) - the typed form of
## [signal station_alert], carrying a severity, a title/detail split, and the
## pawn or module it is about. Emitted by [AlertManager] for *every* alert,
## including the ones the legacy signal wrapped, so a listener only needs one of
## the two. A repeat of a live alert refreshes its row and emits again.
@warning_ignore("unused_signal")
signal station_alert_raised(alert: AlertData)

## A random event fired (WI-13/WI-62), after its conditions passed and its
## mutations ran. Fires for a notification event with no dialogue lines too - the
## event happened either way, and whether the player was interrupted is a
## property of what its author wrote rather than of the event.
@warning_ignore("unused_signal")
signal event_triggered(event: EventData)

## A contract appeared on the board (WI-14). Offered, not accepted: the player
## may well never take it, and an offer that expires unaccepted emits nothing
## further.
@warning_ignore("unused_signal")
signal contract_offered(contract: ContractData)

## The player took the contract on. From here exactly one of
## [signal contract_completed] and [signal contract_failed] always follows.
@warning_ignore("unused_signal")
signal contract_accepted(contract: ContractData)

## Every deliverable met and the reward paid.
@warning_ignore("unused_signal")
signal contract_completed(contract: ContractData)

## The deadline passed with the contract unfulfilled, and its penalty applied.
@warning_ignore("unused_signal")
signal contract_failed(contract: ContractData)

## A guest disembarked and is now a pawn on the station (WI-33). Visitors carry
## needs and disease but no schedule, skills or suit, so a listener that treats
## every pawn alike must check [member PawnBase.is_visitor].
@warning_ignore("unused_signal")
signal visitor_arrived(pawn: PawnBase)

## A guest walked back out, carrying whether they left satisfied - the same
## verdict that moved the station's reputation. The pawn is despawning, so
## anything a listener wants off it must be read during the call.
@warning_ignore("unused_signal")
signal visitor_departed(pawn: PawnBase, happy: bool)
