# Pawns, Jobs & Life

## Pawns

- Pawns exist at a location and can move from place to place.
- Can hold item(s) — likely wants a carrying capacity, which implies items eventually needing weight/encumbrance values.
- Modules will need max-occupancy numbers.
- Pawns could be human or robotic (mining drones are an existing example of "robotic pawns" doing a specific job).
- UI should show a pawn's current job.
- Pawns have traits that affect which jobs they do and how they do them.
- Pawns have skills which impact how well they do their jobs. These skills improve as they do their jobs.
- Pawns have assigned roles perhaps? (Scientist, doctor, security officer?)
- Pawns that experience low moods for long periods drop other tasks to feel better or suffer mental breaks if they can't

## Job Board / Assignment

- Modules that need something post a notice to a shared job board with a priority — e.g. a processor missing an input posts with priority scaled to how empty its storage is.
- A module can post more than one notice at once so it doesn't fill up painfully slowly, though it may be worth waiting until the first notice is claimed before posting more, so the board doesn't get spammed.
- Idea for replacing flat priority with a **utility function** combining distance, pawn wants/needs, and time since the job was posted — then pawns just pick the highest-utility job available. Caveat: this could be expensive to evaluate every frame if not careful (see **05 – Engineering** for the implementation-level version of this concern).
- Job categories that represent finishing something already in progress (e.g. completing a building under construction) should get a priority boost over starting something new.

## Scheduling

- Default to two shifts per day covering full-time station operation.
- Some number of "hours" (24, or possibly fewer — full 24-hour granularity may not be necessary) to schedule against; default split is roughly 12 hours working, 12 hours off (sleep, eat, etc.).
- Pawns can be given a default job assignment: if that workspace is running (powered, has input materials, etc.) they'll work there, and otherwise fall back to picking up whatever's available.
- "Flex" assignments also possible — a pawn with no specific default just picks up any available job (or a more general assignment like "hauling").

## Needs & Life Buildings

Life-related jobs pawns need to perform: sleeping, eating/drinking, socializing.

These are served by dedicated modules: Dining Hall, Greenhouses/Hydroponics Bay/Algae Vats, Sleeping Quarters, Recreation Modules, and the Promenade as a general social hub.

## Happiness

- Happiness is a melding of a pawn's other stats rather than one thing tracked on its own.
- Can also be directly affected by specific situational modifiers — e.g. a penalty for "doing menial work" when a pawn could be doing something more advanced, or a boost from "feeling great" via mood-enhancing additives in food.
- Open item: ambient environmental effects like noise/vibration from processing units may need to factor into happiness (or health) as well.

## Health & Sickness

- External pawns (arriving from ships, etc.) can bring sickness onto the station.
- Illness spreads to nearby pawns based on an infectiousness value, tracked via a `DiseaseData` resource.
- Treated by a Medical Bay module.
- Stasis Pods - pawns can be placed in stasis where time doesn't pass
