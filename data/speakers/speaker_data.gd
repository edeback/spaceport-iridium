class_name SpeakerData
extends Resource

## Who is talking (WI-62 §4). Authored as a `.tres` under `res://data/speakers/`
## and discovered through [ContentPaths].
##
## The character name at the head of a `.dialogue` line is this resource's `id`.
## A line whose character is not a known id falls back to printing that character
## string verbatim with no portrait, which is what lets narration and quick
## authoring work without ceremony.
##
## **An image with no name is a speaker too.** A `SpeakerData` with an empty
## `display_name` and a fixed `portrait` is exactly the brief's "events gain images
## to display" - the balloon already hides its name label when the character is
## empty, so there is no second concept for it.
##
## Definition only. Which face a pool-backed speaker actually got is decided by
## [SpeakerCast], once per conversation.

@export var id: StringName = &""

## The name shown over the line. **Empty means "roll one"** - drawn from
## [NameGenerator] and held for the conversation, which is what a nameless pirate
## or a passing freight broker wants.
@export var display_name: String = ""

## A fixed face. Takes precedence over `portrait_pool`, and is how a recurring
## character (SAI) stays recognisable.
@export var portrait: Texture2D

## A face drawn from a pool, stable for the conversation.
@export var portrait_pool: PortraitPool

## Optional. Ties this speaker to a [FactionData], so the Comms standing block can
## say who the player has been talking to. Purely presentational in v1 - a
## conversation that means to move a standing calls `story.shift_standing`
## explicitly, because "the pirate spoke therefore pirates like you less" is not a
## rule anyone would want applied automatically.
@export var faction: StringName = &""

## Whether this speaker has a face at all.
func has_portrait() -> bool:
	if portrait != null:
		return true
	return portrait_pool != null and not portrait_pool.is_empty()

## The name to print, given a roll for the nameless case. `roll` is passed in
## rather than taken here so [SpeakerCast] owns every source of randomness in one
## place and can be seeded.
func name_for(rolled_name: String) -> String:
	return display_name if not display_name.is_empty() else rolled_name

## The face for `roll`. A fixed portrait ignores the roll entirely.
func portrait_for(roll: int) -> Texture2D:
	if portrait != null:
		return portrait
	if portrait_pool == null:
		return null
	return portrait_pool.texture_at(roll)
