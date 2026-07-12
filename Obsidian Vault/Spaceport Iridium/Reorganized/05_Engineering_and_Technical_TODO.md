# Engineering & Technical TODO

This one's implementation-focused rather than game-design-focused — refactors, bugs, and open architecture questions.

## Active / Current Work

- Support pathfinding to an arbitrary position, not just to a `Node2D` — and, relatedly, pathfinding to a specific path index *inside* a module.
- Rework `action_pathtotarget` to be more general-purpose.
- Add a general edge-data concept for special traversal cases (teleporters, etc.).
- Separate path *movement* from path *following* so an external force (e.g. a turbolift cab) can own a pawn's position directly — possibly by making the pawn a child of the cab while riding, with the cab informing each passenger when it reaches a floor.
- Fix modules being able to block placement of other modules, and add a visual indicator when that's happening.
- Floating objects in space with their own inventory, for recovering scrap/deconstruction materials.

## Systems Rework

- Power system shouldn't need to run every frame.
- Job system refactor:
  - More generic jobs/actions rather than one-off job classes.
  - A system for chaining jobs/actions together and/or preempting a chain mid-way.
  - Priority boost for job categories that represent finishing something already in progress (e.g. completing a building).
  - Consider replacing flat integer priority with a utility function (distance + wants/needs + time since posted, etc.), picking the highest-utility job each time — flagged as potentially expensive if evaluated every frame, so needs a cheaper trigger than that.
  - Consider splitting the single job board into per-category queues so specific job types can be found/filtered quickly.
- Reduce reliance on `_process()` where possible.

## Transportation / Pathfinding Fixes

- Fix how module connections (doors, placement) work — probably belongs on the structure component instead of its current home.
- Add a speed multiplier per "terrain" type (mainly for turbolifts).
- Support disabling a turbolift door (or stairwell) to skip specific floors; likely wants one master turbolift-system panel instead of configuring each module individually.
- Build a turbolift-specific UI: select every module in a shaft together, toggle floors on/off, set car count, choose a dispatch strategy.
- Improve forced pathfinding rechecks to also trigger on a vertex *group* change, not only on module add/remove.

## Job System Bugs / Open Questions

- Should `cancel()` always call `end_job()` internally, rather than leaving that to the caller?
- Should `JobManager` call `cancel()` before removing a job from the board, instead of calling `end_job()` directly?

## Pawn Inventory Design Question

- Pawn inventory needs to register its held storage with the relevant `ResourceData` for tracking purposes, and unregister when the pawn is destroyed.
- Open question: should this be merged/overlapped with `StorageComponent`, or is keeping them as two separate lists on `Resource` simpler and fine as-is?

## Architecture Questions

- Is a dedicated Pawn Layer actually needed, given pawns already get reparented constantly (between layer canvases, etc.)?
- Should `SignalBus` emits be deferred?

## Rendering / Visual QoL

- Truss should render invisible when it's behind another module.
- Tiles need "solid" vs. "sparse" rendering (sparse when 2+ sides are open) — possibly needs to be tracked per-side rather than as one flag per tile.
- Modules should show an "exterior" shell when not hovered, and reveal the interior (with pawns visible) on hover.
- Colorize modules so different types are easier to visually distinguish.
- Establish a consistent shape language for similar module parts.
- Show blocked cells during placement mode, per active layer.
- Blinking "no path" indicator for modules disconnected from the rest of the station.

## General QoL

- Show a description of an asteroid's resource contents.
- Mass-sell option at the docking bay.
- Re-validate placement when a module is flipped during placement, instead of trusting the prior check.
- Hallway sprite selection should check for an actual connection, not just whether a neighbor exists.
- Support clicking a cell multiple times to cycle through stacked nodes on it (important for corridors + stairs/turbolift + module/truss occupying the same cell).
- Let players remove a stored-item *option* from the docking bay config without destroying whatever's currently stored — let it sell off naturally instead.
- Minimap.
- "Current job" display on the pawn info UI.
