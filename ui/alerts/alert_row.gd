class_name AlertRow
extends ListRow

## One row in the alert feed or the history log (WI-53).
##
## A [ListRow] with the alert vocabulary bolted on: which of the three row
## treatments an alert wears, what its action verb says, and what its meta line
## reads. That mapping lives here rather than in the feed because the history
## flyout renders the same rows and the two must not drift.
##
## A row binds an [AlertRules.Group] rather than an [AlertData], because a
## coalesced family is one row - "6 crew have fallen ill" instead of six rows
## that push the breach off the bottom of the feed.
##
## **One press does everything the row offers**: it acknowledges the alert (which
## for a CRITICAL is what releases the pause) and then follows the route -
## jumping the camera and the inspector to the subject, or opening the mode. That
## is deliberate rather than two controls: the manual test for this item is
## "click the breach alert and the game must resume *and* take me to the module",
## and a row with a separate dismiss button turns that into two clicks under
## time pressure.

## Not `SCENE_PATH`: [ListRow] already declares one for the base widget, and
## GDScript will not let a subclass shadow a parent constant.
const ROW_SCENE_PATH: String = "res://ui/alerts/alert_row.tscn"

## Priority glyphs. Authored SVGs, white-stroked and tinted at use, for the
## reason WI-50 gives: `_draw()` is the one thing headless verification cannot
## see.
const GLYPHS: Dictionary[AlertData.Priority, Texture2D] = {
	AlertData.Priority.LOW: preload("res://ui/icons/alerts/low.svg"),
	AlertData.Priority.HIGH: preload("res://ui/icons/alerts/high.svg"),
	AlertData.Priority.CRITICAL: preload("res://ui/icons/alerts/critical.svg"),
}

## The verb an outstanding critical wears instead of JUMP.
##
## It takes the action slot rather than a suffix on the meta line, because the
## meta line is ellipsed on a 344px readout and the *one* thing a row that
## stopped the game must not lose is how to start it again. The press still does
## both halves - this only changes which half the row advertises, and for a
## frozen game that is the resume.
const RESUME_VERB: String = "Resume ▸"

## The group this row is showing, or null before [method bind].
var group: AlertRules.Group = null

static func create() -> AlertRow:
	return load(ROW_SCENE_PATH).instantiate() as AlertRow

## Paints the row from `row_group`. `history` renders the log's variant: a
## timestamp instead of a live action, and no dismissal affordance, because a
## logged alert has already happened.
func bind(row_group: AlertRules.Group, history: bool = false) -> void:
	group = row_group
	var lead: AlertData = row_group.lead() if row_group != null else null
	if lead == null:
		configure("", "", "", UIPalette.Row.INERT)
		return
	var kind: UIPalette.Row = treatment_of(lead)
	configure(row_group.title(), _meta_for(row_group, lead, history),
		"" if history else _action_for(lead), kind)
	set_icon(GLYPHS.get(lead.priority))
	set_icon_color(UIPalette.row_accent(kind))
	tooltip_text = lead.detail

# --- the mapping ----------------------------------------------------------------

## The row treatment an alert wears.
##
## Amber for anything sticky, which is invariant 5's main consumer and the reason
## the budget is worth keeping elsewhere: alerts are what amber is *for*. Cyan
## for a transient alert that is nonetheless actionable - a docked trader, an
## awaiting-reply hail - because "you could click this" and "something is wrong"
## are different claims and the palette already distinguishes them. Inert for the
## rest.
static func treatment_of(alert: AlertData) -> UIPalette.Row:
	if AlertRules.is_sticky(alert.priority):
		return UIPalette.Row.AMBER
	if AlertRules.is_actionable(alert):
		return UIPalette.Row.LIVE
	return UIPalette.Row.INERT

## The right-aligned verb.
##
## A sticky alert with nowhere to go still says something, because it needs a
## click to leave the feed and a blank slot would read as inert. A LOW one does
## not: it will go on its own.
static func _action_for(alert: AlertData) -> String:
	if AlertRules.is_outstanding(alert):
		return RESUME_VERB
	if alert.has_live_subject():
		return "Jump ▸"
	if alert.route != &"":
		return "Open ▸"
	if AlertRules.is_sticky(alert.priority):
		return "Dismiss ✕"
	return ""

func _meta_for(row_group: AlertRules.Group, lead: AlertData, history: bool) -> String:
	var parts: Array[String] = []
	if history:
		parts.append(lead.stamp())
	if not lead.detail.is_empty():
		parts.append(lead.detail)
	if row_group.is_collapsed():
		parts.append("%d alerts" % row_group.size())
	elif lead.count > 1:
		# The only trace a refreshed repeat leaves - "this is the fourth time".
		parts.append("×%d" % lead.count)
	return " · ".join(parts)
