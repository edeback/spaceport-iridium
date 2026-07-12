# Space Station Builder – Design Notes Overview

This is a reorganized version of design notes that were previously spread across several scratch files (To Do, Roadmap, Random Notes, Resource notes, Energy, Overview, Science). Content has been grouped by topic rather than by when it was written, and near-duplicate ideas have been merged together. Nothing has been intentionally cut — if something feels oddly specific or unfinished, that's because it was captured as a raw idea in the original notes and preserved as-is.

## Document Map

- **01 – Modules & Station Structure** — the physical station: layers/views, movement types (hallways, turbolifts, teleporters...), storage rooms, life/habitat modules, industrial & combat modules, construction system, truss/support structure.
- **02 – Resources & Economy** — resource types, storage mechanics, energy sources, mining/gathering, markets & trade, money, and early-game balance.
- **03 – Pawns, Jobs & Life** — pawns themselves, the job board/assignment system, scheduling, needs, happiness, and health/sickness.
- **04 – World, Meta & Progression** — research/science, expeditions, external arrivals, foreign relations, roguelite events/crises, and other "outside the station" systems.
- **05 – Engineering & Technical TODO** — code-level refactors, bugs, open architecture questions, and QoL/polish items. This one is aimed at implementation rather than game design.

## Core Concept (as captured so far)

A space station builder/management game. The station is built module by module on a truss/support-structure "skeleton," inhabited by pawns (human or robotic) who do jobs pulled from a shared job board — hauling resources, mining asteroids, constructing modules, tending to their own needs. Two conceptual layers run through a lot of the notes:

- **Module layer** — the buildings themselves, plus the truss that supports them.
- **Transport layer** — hallways, stairs, and turbolifts (not teleporters, which are their own module) that sit "on top of" the module layer and can outlive the module they were originally attached to.

There's also an open idea of letting the player switch between a few different views of the station (module detail vs. transportation cutaway vs. transportation detail) rather than showing everything at once.
