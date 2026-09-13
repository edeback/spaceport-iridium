class_name InspectorTabSet
extends Node

## What one kind of selected thing puts in the inspector (WI-51).
##
## [InspectorPanel] owns the surface - the identity strip, the tab rail, the
## detail box and the footer row under an open page. A tab set owns the
## *answers*: what the thing is called, what its meta line says, which tabs it
## has, what each page contains and what sits under it. Swapping selection kinds
## is swapping one of these, which is why five panels collapsed into one.
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
##
## **Since the inversion (2026-09-13) there is no subject footer and no subject
## bars.** The identity strip carries the icon, the name, the meta line and the
## amber status line, and nothing else but centre-camera and deselect - the design
## keeps it to the vital. What used to sit in the footer moved into the tab it
## belongs to, through [method page_footer]: FIRE beside the wage on Job,
## DECONSTRUCT / DEMOLISH under Upkeep, DESIGNATE under an asteroid's Contents.
## Integrity became a number on the meta line and a bar on Upkeep.

## The subject went away - freed, mined out, collected, fired, merged. The panel
## drops the selection. Emitted rather than acted on directly, because clearing
## the selection also clears brackets, which is the panel's job.
signal subject_lost

## The identity strip and the open page's footer need repainting. Cheap by
## design: repainting them is a handful of label assignments, so a set is free to
## emit this on any change rather than working out which field moved.
signal subject_changed

## The tab rail's shape changed - a component finished building, a shaft gained
## a floor. The panel rebuilds the rail and keeps the open tab if it survives.
signal tabs_changed

## Takes the subject. Called once, before the panel reads anything else.
func bind(_subject: Variant) -> void:
	pass

## False once the subject is gone. The panel checks this rather than trusting
## [signal subject_lost] alone, because a subject can be freed between a
## deferred signal and the handler that reads it.
func is_alive() -> bool:
	return false

## The node the camera should travel to when something asks to jump to this
## selection - the strip's centre button, WI-53's alerts, WI-56's roster rows.
## Null when the subject has no position - which nothing does today, but a future
## set might.
func camera_target() -> Node2D:
	return null

# --- identity strip ------------------------------------------------------------

func subject_name() -> String:
	return ""

## The line under the name: the numbers you should not have to open a tab for.
func meta_text() -> String:
	return ""

## An amber line under the meta line - a component error, a breach, a resignation
## notice. Empty for a subject with nothing wrong.
func status_text() -> String:
	return ""

## The icon's tint. A fully transparent colour leaves the frame empty.
func icon_color() -> Color:
	return Color(0.0, 0.0, 0.0, 0.0)

## Artwork drawn over the tint, when the subject has any. Modules carry one on
## their [ModuleData]; crew, asteroids and piles do not, and read as a tinted
## square rather than as a missing image.
func icon_texture() -> Texture2D:
	return null

# --- tabs ----------------------------------------------------------------------

## Tab definitions in rail order, in the shape [TabStrip.set_tabs] takes. An empty
## list is legal and hides the rail - a plain corridor with nothing to put in a
## tab says what it is through the identity strip alone.
func tabs() -> Array[Dictionary]:
	return []

## Builds the page for `id`. The panel caches the result until the selection
## changes, so this runs once per tab per selection and a page is free to be
## expensive.
func make_page(_id: StringName) -> Control:
	return null

## The row under the open page `id`, below a divider, or null for none.
##
## Rebuilt whenever the identity strip is, so it reports live state (a toggle's
## label, a wage that just switched on) without the page having to listen for it.
## The panel takes ownership and frees it on the next repaint - a set must build
## a fresh row every call rather than handing back the same instance.
func page_footer(_id: StringName) -> Control:
	return null

## A right-aligned row of buttons, which is what most footers are. Static so a
## set whose footer is only actions does not rebuild the same HBox by hand.
static func action_row(actions: Array[Control]) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Actions"
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	for action: Control in actions:
		row.add_child(action)
	return row

## Makes a page fit the inspector regardless of how it was authored.
##
## The component UIs (and the pawn tabs) are [PanelContainer]s that used to sit
## inside a [TabContainer], so each draws its own surface. Stacked inside the
## inspector's surface that reads as a box in a box, and there are seventeen of
## them plus whatever a mod supplies - so the flattening happens once, here,
## rather than as an edit to every one of them.
##
## It lives on the page-factory contract rather than on [InspectorPanel] because
## two things need it: the panel, on the page it is handed, and WI-64's
## [ModuleStatusTab], on each page it stacks inside one page. Putting it on the
## panel made `inspector_panel -> module_tab_set -> module_status_tab ->
## inspector_panel` a cycle, and a static call across a `class_name` cycle
## resolves at runtime but reports "Static function not found" from the editor's
## parse pass. Here nothing points back.
static func flatten_page(page: Control) -> void:
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var container := page as PanelContainer
	if container != null:
		container.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
