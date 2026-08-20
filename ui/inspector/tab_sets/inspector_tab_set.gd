class_name InspectorTabSet
extends Node

## What one kind of selected thing puts in the inspector (WI-51).
##
## [InspectorPanel] owns the surface - the frame, the header, the subject block,
## the tab strip, the page region and the footer. A tab set owns the *answers*:
## what the thing is called, what its meta line says, which tabs it has and what
## each page contains. Swapping selection kinds is swapping one of these, which
## is why five panels collapsed into one.
##
## It is a [Node] rather than a [RefCounted] so its signal connections die with
## it: every set watches something (a module's components, a pawn's schedule, a
## shaft's floors) and a set that outlived its connections would repaint a panel
## showing a different subject. The panel adds it as a child and frees it on the
## next selection.
##
## Subclasses override the reporting methods. The defaults are all "nothing to
## say", so a set only writes the parts it actually has - and a set that reports
## nothing still renders a legible panel rather than erroring.

## The subject went away - freed, mined out, collected, fired, merged. The panel
## drops the selection. Emitted rather than acted on directly, because clearing
## the selection also clears brackets and the header, which is the panel's job.
signal subject_lost

## The subject block (name, meta line, status, bars) and the footer need
## repainting. Cheap by design: repainting the block is a handful of label
## assignments, so a set is free to emit this on any change rather than working
## out which field moved.
signal subject_changed

## The tab strip's shape changed - a component finished building, a shaft gained
## a floor. The panel rebuilds the strip and keeps the selected tab if it
## survives.
signal tabs_changed

## The header caption, after `SELECTED · `. It is how the player knows the tab
## strip changed under them.
func kind_label() -> String:
	return "Selection"

## Takes the subject. Called once, before the panel reads anything else.
func bind(_subject: Variant) -> void:
	pass

## False once the subject is gone. The panel checks this rather than trusting
## [signal subject_lost] alone, because a subject can be freed between a
## deferred signal and the handler that reads it.
func is_alive() -> bool:
	return false

## The node the camera should travel to when something asks to jump to this
## selection (WI-53's alerts, WI-56's roster rows). Null when the subject has no
## position - which nothing does today, but a future set might.
func camera_target() -> Node2D:
	return null

# --- subject block -------------------------------------------------------------

func subject_name() -> String:
	return ""

## The line under the name: the numbers you should not have to open a tab for.
func meta_text() -> String:
	return ""

## An amber line under the meta line - a component error, a breach, a resignation
## notice. Empty for a subject with nothing wrong.
func status_text() -> String:
	return ""

## The subject block's icon tint. A fully transparent colour hides the icon.
func icon_color() -> Color:
	return Color(0.0, 0.0, 0.0, 0.0)

## Artwork drawn over the tint, when the subject has any. Modules carry one on
## their [ModuleData]; crew, asteroids and piles do not, and read as a tinted
## square rather than as a missing image.
func icon_texture() -> Texture2D:
	return null

## Bars that belong above the tabs rather than inside one, as
## `{label: String, fraction: float, value: String, tint: Color}`. Module
## integrity is the motivating case: it is the thing you look at first, so
## putting it behind a tab would bury it.
func subject_bars() -> Array[Dictionary]:
	return []

## Controls for the footer, rebuilt whenever the subject block is. The panel
## takes ownership and frees them on the next repaint, so a set must build fresh
## ones rather than handing back the same instances.
func footer_actions() -> Array[Control]:
	return []

# --- tabs ----------------------------------------------------------------------

## Tab definitions in strip order, in the shape [TabStrip.set_tabs] takes. An
## empty list is legal and renders as a bare rule - a truss or a plain corridor
## has nothing to put in a tab and says so through the subject block instead.
func tabs() -> Array[Dictionary]:
	return []

## Builds the page for `id`. The panel caches the result until the selection
## changes, so this runs once per tab per selection and a page is free to be
## expensive.
func make_page(_id: StringName) -> Control:
	return null
