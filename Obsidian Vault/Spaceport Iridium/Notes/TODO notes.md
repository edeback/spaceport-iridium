Run a test of actual vs mockup, list deviations (if any).

StringNames are cropping back up, should move them to a consts file again.

Hire moves to Crew tab from docking bay

R&D -> "Tech" (early game isn't research, it's bought)

Modules should have a list of present pawns so you can go module.get_present() (or something like that) to figure out who is there without looking through every pawn

When pawns wander, pick a random inner node (if it has one) instead of just flipping between the boundary of two modules
- They now pick a "stand" target so maybe that's good enough?

For resources:
Show relationships between resources in the UI
Give them categories? So ore can be shown together, tier one/two/three materials etc


Pawn issues should be promoted to the alerts section of the pawn screen too

Officers?
- Promote pawns to certain positions
- Get bonuses to certain skills or for certain modules

Transient visitors SHOULD save - both ARC inspection as well as tourists

ctrl should also show pawn names, and should probably be cleaned up for modules as well (currently messy/confusing)

Starting main UI flow - select 2 (or more?) pawns from a pool of candidates to start with (instead of starting completely randomly)

Traits - something more general, like "quality" plus condition (flat/mult, attribute)?

visitor_pawn looks for recruitment component instead of docking bay to leave
- Maybe add recruitment component to teleporter too?

Conveyor module needs door

Battery improvements (upgrades, actual usefulness)

UI_main close_esc_claim - maybe have a stack system where each thing that needs esc registers it first, then it does it in opposite order?

Get capacitators on power_consumption_components working and move shields/weapons to use that.

Trade order screen - show current supplies for validation

Salvage? Derelicts drifting in that can be deconstructed for resources

Ice should get quality and that should matter for ice purifier
Introduce comets which are asteroids except mostly ice and some carbon

Spread slow ticks around? Make even slower ticks? Ideally don't do heavy lifting all in one frame, even if "slow". Option: Global.time_manager.register_slow_tick(self).connect(...) and then time manager can batch those that connect to different frames? Probably won't break things?

Processor_component: in try_deposit_outputs() any excess should get dumped into a pile in the room. Full storage should stop a new job from starting, however.

Station "Prestige"
- Instead of "level"
- Equivalent to "stars" in SimTower
- Or "Milestones" like in City Skylines
- **"Class I" -> "Class V" Station**
	- When you gain a level, "ARC has granted you a Class II Station Charter"
- Also consider scale words
	- Outpost, Station, Port, Hub, Metropolis
		- Harder to connect many words to scale, though, and not having "Spaceport" be the final tier (which it wouldn't, "port" isn't a very large word) would negate some of the idea of "Spaceport Iridium"
	- Outpost, Waystation, Station, Complex, Spaceport

Station name!
- Give your station a name at the start
- Then display it with station scale word (above) somewhere like the top of the minimap
	- Name: Alpha -> "Outpost Alpha", "Station Alpha", etc

Room info at a glance
- For example, show that it is iron ore being processed and how much time

Starting module should have (almost) everything needed for first 2 pawns
- Sleeping quarters?
- Eating quarters?
	- Or maybe pawns will "eat" even without a mess hall if there is food available? very wasteful!

Happiness modifiers don't persist saving:
- "misery driven purely by _happiness modifiers_ doesn't survive save/load (modifiers are transient by design since WI-05), so a pending resignation whose cause was a modifier cancels on load as "recovered." Real need-driven misery persists correctly."

Arrivals pick a specific bay that gets saved and then looked up in a fragile way - they probably can just grab whatever bay there is, doesn't really matter where they arrive. This also solves for having two bays, hiring from one and then deleting it (crew_manager)

Possibly shuttle upgrade: Starts at the planet position (and layer - background space) at 0 scale. Slowly scales up as arrives. Would likely need some tricky math to determine where it "appears" to be due to parallax - should be more aligned to front as it gets closer

For trader screen
- Create rows like other screen so better UI can be made
- Putting values in buy zeros out sell and vice versa (like other UI)
- When buying something that wasn't on the order sheet, make sure it ends up in the storage so it can actually be exported

For events:
- have event options that are only valid when certain things are true (like having a module) so the player knows they _could_ have done something

Build more detailed traders (types, buy/sell multipliers, etc)

Factory!
- For steel, future things too
Ore refiner:
- "Any" as an option? 

- **New modules pack** — Magscoop, Hydrogen Fuel Cells, Smelter/Polymer/Electronics factories as buildables (ProcessorComponent + recipes — mostly data work), Promenade, Holodeck.

Events:
- Minimum time between events (now is pure random, should be semi-random)




Have Fable "interview me" about the game and update the design document
Also create more Work Items for the next batch of tasks



|       |                            |                                                                    |
| ----- | -------------------------- | ------------------------------------------------------------------ |
| ==G== | ==Ground truth==           | ==Point it at what already exists. Let it read everything first.== |
| ==O== | ==Outcome, not orders==    | ==Say what done looks like. "Better" is not a goal.==              |
| ==A== | ==Autonomy over the path== | ==Tell it what you want. Not how to get there.==                   |
| ==L== | ==Loop in proof==          | ==Make it verify the work and check in before big decisions.==     |
Goal prompt:
Here is [the thing you already have] in this folder. New goal: [what you want it to become — say it as a clear result you can check]. First, read everything here and map what it does today. Then turn my goal into specific, testable criteria. If anything is fuzzy, interview me one question at a time until it's clear. Check the criteria with me before you build anything. Figure out the best way to get there yourself. I'm not going to give you the steps. Then make the changes one at a time. After each one, prove it works — open it, test it, run it — and show me the before and after. Check in with me before any big or hard-to-undo decision.

Meta prompt:
have a project for you, but I'm not ready to brief you. So interview me first. Ask me one question at a time, in plain language. You're trying to learn four things: G — What I already have. Files, a folder, a site, a system, a doc. Get the location, then read all of it yourself before asking anything it could answer for you. O — What I want it to become. Push past vague answers. If I say "better," ask what better looks like and how we'd both know it happened. Turn my answers into specific, testable criteria. A — What's mine vs. yours. Find out which decisions I actually care about. Anything I don't claim is your call. L — What proof I need. Ask how I want it verified when you're done: opened live, tested with real data, before and after. Keep the interview short. Five to seven questions, then stop. Make reasonable calls on the small stuff yourself. Then write everything back to me as one master prompt: the ground truth, the goal with its testable criteria, what you'll decide on your own, and how you'll prove it works. Show it to me. When I approve it, execute it, and check in with me before any big or hard-to-undo decision.

Simple prompt:
Look at my code, think of what I want to accomplish and suggest improvements,

Prompt for work items:

I'd like to create a new Work Item.
Goal: etc etc
Please write out a Work Item similar to those already created (Goal, Design, Files to Touch, Implementation Order, Edge Cases, Verification) and place it in the Work Items folder. If there is a part of the design that is unclear or needs elaboration, come up with some options and ask me which one to use.
