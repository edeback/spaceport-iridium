class_name FactionData
extends Resource

## One power the station has a relationship with (WI-62 §5). Authored as a
## `.tres` under `res://data/factions/` and discovered through [ContentPaths].
##
## Definition only. The standing itself is a number in [FactionStanding], owned by
## [StoryState] and saved with the run - a shared `.tres` survives a scene swap in
## Godot's resource cache, so a standing living here would hand a new game the
## previous run's grudges. That is exactly the bug WI-38's A8 was.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

## The faces this faction's speakers are drawn from, when a `.dialogue` file does
## not name a more specific speaker.
@export var portrait_pool: PortraitPool

## Whether this faction carries a standing at all.
##
## **ARC is listed and not scored**, deliberately. The station's relationship with
## ARC already exists as the tier ladder and the inspection gate; a second number
## for the same relationship would be two places to answer one question, which is
## the "one place per vocabulary" failure this codebase keeps deleting. ARC is
## here so a `.dialogue` file can name it as a *speaker's* faction and so the
## Comms block can show the player who is out there.
@export var scored: bool = true

## Display order in the Comms standing block. Lower first.
@export var sort_order: int = 0
