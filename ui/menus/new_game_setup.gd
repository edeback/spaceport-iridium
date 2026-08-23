class_name NewGameSetup
extends Control

## The New Game setup screen (WI-59): name the station, pick the two crew it
## opens with, choose a difficulty. Built in code as a child of [MainMenu], the
## same way [SettingsMenu] and [SaveLoadMenu] are, and like them it only ever
## *reports* the player's choices - through start_requested - because staging
## values onto Global and swapping the scene is the menu's job, in one place.
##
## Deliberately outside the console design system. `test_ui_theme.gd`'s
## OVERRIDE_EXEMPT list starts with `res://ui/menus/` because the whole menu
## layer predates WI-49, so the hand-typed sizes below are legal *here
## specifically* and this screen must not start pulling in ConsolePanel /
## ReadoutPanel / UIMetrics. Colours still come from UIPalette, as the rest of
## the menus already do.
##
## The candidate pool is rolled by a bare [CandidateRoller]: there is no
## CrewManager in this scene (no managers at all), which is the whole reason the
## roll was extracted from it.

## How many candidates stand in the pool. Big enough that picking two is a real
## choice, small enough to read without scrolling.
const POOL_SIZE: int = 6
const POOL_COLUMNS: int = 3
## Longest station name accepted. The minimap header this feeds is a fixed-width
## readout whose Label has no overrun behaviour, so an unbounded name would widen
## the whole right column rather than ellipsing (and giving it an overrun mode
## would collapse it instead - WI-53).
const MAX_STATION_NAME: int = 24

const CARD_SIZE: Vector2 = Vector2(228, 0)
const PANEL_SIZE: Vector2 = Vector2(768, 0)

signal start_requested(difficulty_id: StringName, station_name: String,
		crew: Array[HireCandidate], skip_onboarding: bool)
signal closed

var _roller := CandidateRoller.new()
## The candidates on offer, by slot. A re-roll replaces one entry in place.
var _pool: Array[HireCandidate] = []
## Slot indices the player has picked, in pick order - so a card can show which
## of the two it is, and so the order survives a re-roll of either.
var _picks: Array[int] = []
var _difficulty_id: StringName = DifficultyData.DEFAULT_ID

var _name_edit: LineEdit
var _pool_grid: GridContainer
var _pick_count: Label
var _difficulty_detail: Label
var _difficulty_group: ButtonGroup
## id -> its toggle, so re-opening the screen can put the buttons back where
## _reset() puts the underlying choice. Without this the pressed toggle and
## _difficulty_id disagree the second time the screen is opened.
var _difficulty_buttons: Dictionary[StringName, Button] = {}
var _begin: Button
## "Skip Onboarding" (WI-63 §7). Default **off**: a first-time player who does
## not read the checkbox gets the tutorial, which is the failure mode that costs
## them nothing.
var _skip_onboarding: CheckBox

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	_reset()

## Opens on a fresh pool: a player who backed out to the main menu and came back
## is starting the decision over, and stale picks pointing into an old pool would
## be the only state on this screen that could lie.
func open() -> void:
	visible = true
	_reset()

func close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

# --- shell --------------------------------------------------------------------

func _build_shell() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "New Game"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	_build_station_row(vbox)
	vbox.add_child(_divider())
	_build_crew_section(vbox)
	vbox.add_child(_divider())
	_build_difficulty_section(vbox)
	vbox.add_child(_divider())
	_build_footer(vbox)

func _divider() -> Control:
	var line := ColorRect.new()
	line.color = UIPalette.DIVIDER
	line.custom_minimum_size = Vector2(0, 1)
	return line

func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UIPalette.TEXT_EMPHASIS)
	return label

# --- station name -------------------------------------------------------------

func _build_station_row(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_heading("Station name"))

	_name_edit = LineEdit.new()
	_name_edit.max_length = MAX_STATION_NAME
	# Empty is a legal answer, not a blocked one: it falls back to this same name,
	# which is why Begin never has to gate on the field.
	_name_edit.placeholder_text = Global.DEFAULT_STATION_NAME
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name_edit)
	parent.add_child(row)

	var note := Label.new()
	note.text = "Shown on the station map, and used as the default save name."
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", UIPalette.TEXT_META)
	parent.add_child(note)

# --- crew ---------------------------------------------------------------------

func _build_crew_section(parent: Node) -> void:
	var header := HBoxContainer.new()
	var heading: Label = _heading("Founding crew")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_pick_count = Label.new()
	_pick_count.add_theme_font_size_override("font_size", 12)
	header.add_child(_pick_count)
	parent.add_child(header)

	var note := Label.new()
	note.text = "Pick %d. Re-roll any card as often as you like - but a higher-skilled recruit draws a bigger wage, every cycle, forever." % CrewManager.STARTING_CREW
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", UIPalette.TEXT_META)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(note)

	_pool_grid = GridContainer.new()
	_pool_grid.columns = POOL_COLUMNS
	_pool_grid.add_theme_constant_override("h_separation", 8)
	_pool_grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(_pool_grid)

## Rebuilds every card. Cheap at six cards, and one render path means a re-roll
## and a selection can't drift into showing different things.
func _rebuild_pool() -> void:
	for child: Node in _pool_grid.get_children():
		# Unparent before freeing: this can run twice in one frame (build then
		# open), and queue_free alone would leave the stale cards on screen for
		# the rest of it - a visibly doubled grid.
		_pool_grid.remove_child(child)
		child.queue_free()
	for index: int in _pool.size():
		_pool_grid.add_child(_build_card(index))
	_update_pick_state()

func _build_card(index: int) -> Control:
	var candidate: HireCandidate = _pool[index]
	var pick_position: int = _picks.find(index)
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.add_theme_stylebox_override("panel", _card_style(pick_position >= 0))

	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)

	var name_label := Label.new()
	name_label.text = candidate.pawn_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", UIPalette.TEXT_EMPHASIS)
	box.add_child(name_label)

	box.add_child(_traits_row(candidate))

	var skills_label := Label.new()
	skills_label.text = candidate.skills_line()
	skills_label.add_theme_font_size_override("font_size", 12)
	skills_label.add_theme_color_override("font_color", UIPalette.TEXT)
	skills_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(skills_label)

	# The wage is the whole trade-off of an unlimited re-roll, so it is on the
	# card rather than discovered on the first payday: a candidate's rolled price
	# IS their salary for the rest of the game (EconomyManager.wage_for).
	var wage_label := Label.new()
	wage_label.text = "%d cr / cycle" % EconomyManager.wage_for(candidate.price, EconomyManager.DEFAULT_WAGE_FRACTION)
	wage_label.add_theme_font_size_override("font_size", 11)
	wage_label.add_theme_color_override("font_color", UIPalette.TEXT_META)
	box.add_child(wage_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	var select := Button.new()
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if pick_position >= 0:
		select.text = "Picked %d" % (pick_position + 1)
	else:
		# A third pick would have to silently evict one of the first two, so the
		# rest of the pool locks at capacity - and each locked button says why on
		# itself rather than just greying out, or four dead controls are left for
		# the player to explain to themselves.
		select.disabled = _picks.size() >= CrewManager.STARTING_CREW
		select.text = "Deselect first" if select.disabled else "Select"
	select.pressed.connect(_on_card_toggled.bind(index))
	actions.add_child(select)

	var reroll := Button.new()
	reroll.text = "⟳"
	reroll.tooltip_text = "Roll a different recruit"
	reroll.custom_minimum_size = Vector2(34, 0)
	reroll.pressed.connect(_on_reroll_pressed.bind(index))
	actions.add_child(reroll)
	box.add_child(actions)
	return card

## Hoverable trait names, or a plain note when the candidate rolled none. The
## row itself is [TraitChips], shared with the in-game recruitment window; this
## screen only says what it should look like and what "no traits" reads as.
func _traits_row(candidate: HireCandidate) -> Control:
	var traits: Array[TraitData] = candidate.trait_data()
	if traits.is_empty():
		var none := Label.new()
		none.text = "No traits"
		none.add_theme_font_size_override("font_size", 12)
		none.add_theme_color_override("font_color", UIPalette.TEXT_META)
		return none
	return TraitChips.build(traits, UIPalette.LIVE_BRIGHT, &"", 12)

func _card_style(picked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UIPalette.PANEL
	style.set_border_width_all(1)
	style.border_color = UIPalette.LIVE if picked else UIPalette.CONTROL_BORDER
	if picked:
		style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	return style

func _on_card_toggled(index: int) -> void:
	var at: int = _picks.find(index)
	if at >= 0:
		_picks.remove_at(at)
	elif _picks.size() < CrewManager.STARTING_CREW:
		_picks.append(index)
	_rebuild_pool()

## Replaces one card's occupant. A picked slot STAYS picked: "roll this pick
## until I like it" is the whole point of the button, and dropping the selection
## on every press would make that miserable. The pick indexes the slot, not the
## candidate, so nothing needs re-pointing.
func _on_reroll_pressed(index: int) -> void:
	_pool[index] = _roller.roll()
	_rebuild_pool()

func _update_pick_state() -> void:
	var picked: int = _picks.size()
	var required: int = CrewManager.STARTING_CREW
	_pick_count.text = "%d / %d picked" % [picked, required]
	_pick_count.add_theme_color_override("font_color",
		UIPalette.LIVE_BRIGHT if picked == required else UIPalette.TEXT_META)
	if _begin == null:
		return
	var short: int = required - picked
	_begin.disabled = short > 0
	# A blocked action names its blocker on its own control, not only in a
	# tooltip - borrowed from the console's rules on merit, not by obligation.
	_begin.text = "Begin" if short <= 0 else "Pick %d more crew" % short

# --- difficulty (moved here from MainMenu, WI-37) -----------------------------

func _build_difficulty_section(parent: Node) -> void:
	var levels: Array[DifficultyData] = DifficultyData.all()
	if levels.is_empty():
		# No data/difficulty/ at all: keep New Game working (Global falls back to
		# neutral values) rather than stranding the player on a dead screen.
		var searched := PackedStringArray(ContentPaths.roots_for(ContentPaths.DIFFICULTY))
		push_warning("No DifficultyData found in " + ", ".join(searched)
				+ " - New Game will run at default settings")
		return

	parent.add_child(_heading("Difficulty"))
	var note := Label.new()
	note.text = "Fixed for the whole game and can't be changed later."
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", UIPalette.TEXT_META)
	parent.add_child(note)

	# One toggle per level, easiest first, with the selected level's own words
	# below. Both lines are read off the .tres - never authored beside it - so a
	# balance tweak can't leave this screen describing the old numbers.
	_difficulty_group = ButtonGroup.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for difficulty: DifficultyData in levels:
		var button := Button.new()
		button.text = difficulty.display_name
		button.toggle_mode = true
		button.button_group = _difficulty_group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 34)
		button.button_pressed = difficulty.id == _difficulty_id
		button.pressed.connect(_on_difficulty_pressed.bind(difficulty))
		row.add_child(button)
		_difficulty_buttons[difficulty.id] = button
	parent.add_child(row)

	_difficulty_detail = Label.new()
	_difficulty_detail.add_theme_font_size_override("font_size", 12)
	_difficulty_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_difficulty_detail.custom_minimum_size = Vector2(0, 40)
	parent.add_child(_difficulty_detail)

func _on_difficulty_pressed(difficulty: DifficultyData) -> void:
	_difficulty_id = difficulty.id
	_show_difficulty_detail(difficulty)

func _show_difficulty_detail(difficulty: DifficultyData) -> void:
	if _difficulty_detail == null or difficulty == null:
		return
	_difficulty_detail.text = "%s\n%s" % [difficulty.description, difficulty.effect_summary()]
	_difficulty_detail.add_theme_color_override("font_color", UIPalette.TEXT)

# --- footer -------------------------------------------------------------------

func _build_footer(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(120, 38)
	back.pressed.connect(close)
	row.add_child(back)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_skip_onboarding = CheckBox.new()
	_skip_onboarding.text = "Skip Onboarding"
	_skip_onboarding.tooltip_text = ("Start without SAI's introduction and without"
		+ " the contextual advisories. Both stay replayable from the console's AIDE panel.")
	_skip_onboarding.add_theme_color_override("font_color", UIPalette.TEXT)
	row.add_child(_skip_onboarding)

	_begin = Button.new()
	_begin.custom_minimum_size = Vector2(200, 38)
	_begin.pressed.connect(_on_begin_pressed)
	row.add_child(_begin)
	parent.add_child(row)

func _on_begin_pressed() -> void:
	if _picks.size() != CrewManager.STARTING_CREW:
		return
	var crew: Array[HireCandidate] = []
	for index: int in _picks:
		crew.append(_pool[index])
	start_requested.emit(_difficulty_id, _name_edit.text, crew,
		_skip_onboarding != null and _skip_onboarding.button_pressed)

# --- state --------------------------------------------------------------------

func _reset() -> void:
	_pool.clear()
	_picks.clear()
	for i: int in POOL_SIZE:
		_pool.append(_roller.roll())
	if _name_edit != null:
		_name_edit.text = ""
	_difficulty_id = DifficultyData.DEFAULT_ID
	if _skip_onboarding != null:
		_skip_onboarding.button_pressed = false
	if _difficulty_buttons.has(_difficulty_id):
		_difficulty_buttons[_difficulty_id].button_pressed = true
	_show_difficulty_detail(DifficultyData.resolve(_difficulty_id))
	_rebuild_pool()
