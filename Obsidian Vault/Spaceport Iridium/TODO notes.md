Modules should have a list of present pawns so you can go module.get_present() (or something like that) to figure out who is there without looking through every pawn

Use SelfModulate on crew pawns to give them different colors (at random). They also need names!!

For resources:
Show relationships between resources in the UI

Hunger/Eat should take time. (~1 hr) Allows lingering in the mess hall for a bit.

Pawn issues should be promoted to the alerts section of the pawn screen too

There's Module.size and StructureComponent.size and they need to be aligned but why are they in two different spots?

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