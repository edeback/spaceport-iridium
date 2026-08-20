class_name AsteroidTabSet
extends InspectorTabSet

## The tab set for a mineable body (WI-51). A single-tab set, ported from
## `component_ui_panels/asteroid_info_panel.tscn`.
##
## Covers comets as well as asteroids (WI-61): both are AsteroidBase instances,
## so the only thing that varies is the noun, which comes off the body rather
## than being written here.
##
## Asteroids drift constantly, which is why the old panel repositioned itself
## every frame. Fixing the panel's position is exactly what makes that
## unnecessary - and it also removes the case where the thing you were reading
## slid off the bottom of the screen while you read it.

const TAB_CONTENTS: StringName = &"contents"

var _asteroid: AsteroidBase = null

func kind_label() -> String:
	return subject_name()

func bind(subject: Variant) -> void:
	_asteroid = subject as AsteroidBase
	if _asteroid == null:
		return
	_asteroid.contents_changed.connect(_on_changed)
	# despawning fires before the free, so the panel drops the selection a frame
	# earlier than its validity poll would.
	_asteroid.despawning.connect(_on_gone)

func is_alive() -> bool:
	return _asteroid != null and is_instance_valid(_asteroid)

func camera_target() -> Node2D:
	return _asteroid

## The one place a body becomes a word: [member AsteroidBase.body_name], set
## from its SpaceBodyProfile at spawn.
func subject_name() -> String:
	return _asteroid.body_name if is_alive() else "Asteroid"

## Richness is dropped for a body whose mix carries no variance-bearing
## resource (WI-61) - a comet of ice and carbon yields one fixed quality, so a
## "Rich (72%)" readout there would be describing nothing at all.
func meta_text() -> String:
	if not is_alive():
		return ""
	var remaining: String = "%d / %d chunks" % [_asteroid.cur_resources, _asteroid.max_resources]
	if not _asteroid.has_variable_yield():
		return remaining
	return "%s · %s" % [_asteroid.get_richness_descriptor(), remaining]

## "Designated for mining" is the definition of *selected*, and selected is cyan
## everywhere else in the design - so it is cyan here too (WI-58). It was amber,
## which made a working mining operation read as a problem.
func icon_color() -> Color:
	if not is_alive():
		return Color(0.0, 0.0, 0.0, 0.0)
	return UIPalette.LIVE if _asteroid.designated else UIPalette.tinted(UIPalette.TEXT, 0.5)

func subject_bars() -> Array[Dictionary]:
	if not is_alive() or _asteroid.max_resources <= 0:
		return []
	var fraction: float = float(_asteroid.cur_resources) / float(_asteroid.max_resources)
	return [{
		"label": "Remaining",
		"fraction": fraction,
		"value": "%d" % _asteroid.cur_resources,
		"tint": UIPalette.LIVE,
	}]

## Designating an asteroid is the one thing you do to one, so it is the footer
## action rather than a checkbox buried in the tab. It toggles, so the button
## reports the current state in its label.
func footer_actions() -> Array[Control]:
	if not is_alive():
		return []
	var designate: ActionButton = ActionButton.create(
		"Mining designated" if _asteroid.designated else "Designate for mining",
		ActionButton.Weight.PRIMARY if _asteroid.designated else ActionButton.Weight.SECONDARY)
	designate.pressed.connect(_on_designate_pressed)
	var out: Array[Control] = [designate]
	return out

func _on_designate_pressed() -> void:
	if is_alive():
		_asteroid.designated = not _asteroid.designated
		subject_changed.emit()

func tabs() -> Array[Dictionary]:
	return [{"id": TAB_CONTENTS, "text": "Contents"}]

func make_page(id: StringName) -> Control:
	if id != TAB_CONTENTS or not is_alive():
		return null
	var page := AsteroidContentsTab.new()
	page.set_asteroid(_asteroid)
	return page

func _on_changed() -> void:
	subject_changed.emit()

func _on_gone() -> void:
	subject_lost.emit()
