# World, Meta & Progression

## Research & Science

- Progression is intended to lean mostly on purchasable **licensing rights** rather than a classic tech tree — e.g. buying access from an org like "NeoNeutrino Labs." These unlock new modules and upgrades to existing ones (extra robots for a mining bay, better module efficiency, replacing human workers with AI on certain jobs).
- A dedicated **Science Lab** module could still exist for more unique, experiment-driven research outside the licensing system.
- **Observatory / Astrometrics** module: spots incoming danger (pirates, solar storms) early, and separately produces ongoing science/research data.
- Science output could also come from **experiments** or from **expeditions** (see below) — including recovering resources/data from destroyed pirate ships.

## Excursions & Expeditions

Sending a crew out from the station to acquire resources (or, per Research & Science, research data) from elsewhere — asteroids, wrecks, points of interest. Likely requires a module to unlock, which makes it more of a mid/late-game option than an early-game safety net (see the balance notes in **02 – Resources & Economy**).

## External Arrivals

- Ships travel from a planet to the station — implies the system needs an actual planet present, and probably a `LocationData` resource describing it. Could be shown visually approaching (zooming in as it nears the station, and vice versa on departure).
- People can also teleport in directly from the planet.
- Smaller ships arrive via the Shuttle Docking Bay.
- Larger ships arrive via a Cargo Port — conceptually similar to how *Cities: Skylines* separates road, rail, sea, and air connections, each bringing in different scales of traffic.

## Foreign Relations

Ability to communicate and deal with other stations/planets in the system — negotiating, trading, or otherwise interacting diplomatically. Other stations can also simply be trade partners (see **02 – Resources & Economy**).

## Travel

Ability to warp the entire station to a new system.

## Roguelite Elements

- **Random events** — presented as event cards with a choice of responses/solutions.
- **Crises** — larger, "endgame"-scale problems (comparable to the crisis system in *Starsector*) that build up over time and are visible coming before they hit.

## World Features

- A large asteroid the player can build the station around/into.

## Meta UI

- A minimap for navigating the whole station at a glance, similar to *SimTower*.
- A visible clock showing the current day ("cycle") and hour.
- Time controls: pause, fast-forward, slow down.

## Original Roadmap Notes (worth checking against current implementation)

These were captured early on and may already be substantially built — flagged here just so nothing gets silently dropped:
- Core job board (modules post notices with priority).
- Core pawn behavior (exist, move between locations, carry items).
- Basic module-to-module walkway/navigation so pawns can path between modules.
- Docking bay serving as the required external "source" location other systems connect to.
