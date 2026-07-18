Modules should have a list of present pawns so you can go module.get_present() (or something like that) to figure out who is there without looking through every pawn

When pawns wander, pick a random inner node (if it has one) instead of just flipping between the boundary of two modules

Use SelfModulate on crew pawns to give them different colors (at random). They also need names!!

For resources:
Show relationships between resources in the UI

Hunger/Eat should take time. (~1 hr) Allows lingering in the mess hall for a bit.

Pawn issues should be promoted to the alerts section of the pawn screen too

There's Module.size and StructureComponent.size and they need to be aligned but why are they in two different spots?

Trade order screen - show current supplies for validation

Forge
- Needs carbon input storage or else won't run!

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

Animations:
- Don't follow timescale currently
- Can change them via animation.speed_scale = Global.time_manager.speed
- And keep updated via Global.time_manager.speed_changed
- However LinkedDoorState is probably leaking as I get null callbacks even though I clear speed_changed on predelete
- Maybe more important first to not have awaits...

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

Set first two pawns to work 100% of the time, pawns after that can work shifts (as there's a lot to do to start!)


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