class_name CalendarDisplay
extends Container
## Displaying the individual days in the month

signal shown_year_changed(year : int)

## Shared context to access the runtime TimeStateLogic object
@export var time_state : TimeState
		
@export var year_spin_box : SpinBox :
	set(value):
		if year_spin_box != null:
			year_spin_box.value_changed.disconnect(_on_year_box_value_changed)
			
		year_spin_box = value
		
		if year_spin_box != null:
			call_deferred(refresh.get_method())
			year_spin_box.value_changed.connect(_on_year_box_value_changed)
	
@export var tab_container : TabContainer
@export var month_table_template : PackedScene
			
## Triggers the UI to switch visibility for showing / hiding when the action name is pressed [br][br]
## (Set in ProjectSettings -> InputMap)
@export var toggle_action : StringName = "calendar"

## Whether to automatically switch to the current month and year on date change
@export var auto_switch_to_current_date = false

## The year that the calendar display is showing.
## When changed, refreshes the UI for the new year.
var shown_year : int :
	set(value):
		if shown_year == value:
			return
			
		shown_year = value
		shown_year_changed.emit(shown_year)

func _init(p_time_context : TimeState = null, p_tab_container : TabContainer = null, p_month_table_template : PackedScene = null):
	if p_time_context != null:
		time_state = p_time_context
		
	if p_tab_container:
		tab_container = p_tab_container
		
	if p_month_table_template:
		month_table_template = p_month_table_template

func _ready():
	# Initialize the year based on the cached TimeStateLogic
	shown_year = time_state.date_time.date.year
	
	if year_spin_box != null:
		year_spin_box.value = shown_year
		
	shown_year_changed.connect(_on_shown_year_changed)
	time_state.date_changed.connect(_on_date_changed)

func refresh():
	clear()
	setup_tabs(shown_year)
	
func clear():
	for child in tab_container.get_children():
		child.free()

## Creates a tab for each month in the current game year
func setup_tabs(p_shown_year : int):
	var current_date = time_state.date_time.date
	var game_year : GameYear = time_state.calendar.get_game_year(p_shown_year)
	
	for month_idx in game_year.months.size():
		var month_table : MonthTable = month_table_template.instantiate()
		month_table.time_state = time_state
		tab_container.add_child(month_table)
		month_table.set_table_time(p_shown_year, month_idx)
		var game_month = game_year.months[month_idx]
		month_table.game_month = game_month
		
	tab_container.current_tab = current_date.month - 1
		
# Shows container if hidden, hides if showing
func toggle_display():
	if visible:
		hide()
	else:
		show()

## Jump to showing the current month in the calendar
func go_to_current_month():
	shown_year = time_state.date_time.date.year
	tab_container.current_tab = time_state.date_time.date.month - 1

func _on_year_box_value_changed(p_value : int):
	shown_year = p_value

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		toggle_display()

func _on_date_changed(event : DateChangeEvent):
	if auto_switch_to_current_date and event.new.year != shown_year:
		shown_year = event.new.year
		if year_spin_box != null:
			year_spin_box.value = shown_year

		tab_container.current_tab = event.new.month - 1

func _on_shown_year_changed(p_year : int):
	refresh() # Show year in the UI
	
	if year_spin_box != null:
		year_spin_box.value = p_year
