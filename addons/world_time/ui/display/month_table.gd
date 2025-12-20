@tool
class_name MonthTable
extends Tree
## Shows the month calendar in a table fashion

@export var time_state : TimeState :
	set(value):
		if time_state != null && time_state.date_changed.is_connected(_on_date_changed):
			time_state.date_changed.disconnect(_on_date_changed)
			
		time_state = value
		
		if time_state != null && not time_state.date_changed.is_connected(_on_date_changed):
			time_state.date_changed.connect(_on_date_changed)
			
@export var settings : MonthTableSettings

var shown_year : int

## Month index number that represents the position of the month in the array
var month_idx : int

## Resource representing the current month number
var game_month : GameMonth :
	set(value):
		game_month = value
		refresh()

var root : TreeItem
var week_items : Array[TreeItem]

## Day number (not index) of the first day of the week
var _first_day_week_index : int


## Sets up the table based on the current game month
func refresh():
	clear()
	setup()

func clear():
	super()
	week_items = []

func _init(p_time_state : TimeState = null, p_settings : MonthTableSettings = null) -> void:
	time_state = p_time_state
	settings = p_settings

## Defines the time properties for this table UI
func set_table_time(p_shown_year : int, p_month_idx : int):
	shown_year = p_shown_year
	month_idx = p_month_idx
	
func setup():
	name = game_month.display_name
	root = create_item()
	hide_root = true
	
	_first_day_week_index = time_state.calendar.get_day_of_week_index(
		GameDate.new(1, month_idx + 1, time_state.date_time.date.year)
		)
		
	_setup_columns()
	_setup_weeks(game_month, _first_day_week_index)
	_setup_days(game_month.days, _first_day_week_index)
	var current_date = time_state.date_time.date
	var current_month = time_state.calendar.get_game_month(current_date)
	
	# Highlight the current day if needed
	if shown_year == current_date.year && current_date.month == month_idx + 1:
		highlight_day(current_date.day)
		
func clear_highlight(p_day : int):
	var index = p_day - 1
	var week = get_week(index)
	var column = get_column(index)
	var week_item = week_items[week]
	week_item.clear_custom_bg_color(column)

## Highlights a day on the calendar
func highlight_day(p_day : int):
	var index = p_day - 1
	var week = get_week(index)
	var column = get_column(index)
	var week_item = week_items[week]
	week_item.set_custom_bg_color(column, settings.current_day_bg_color)
	
## Gets the column number corresponding to a day on the table
func get_column(p_day : int) -> int:
	return (p_day + _first_day_week_index) % columns

func get_week(p_day : int) -> int:
	var days_with_offset = p_day + _first_day_week_index
	var week : int = ceil(days_with_offset / columns as float)
	return week

func _setup_columns():
	columns = time_state.calendar.get_days_per_week()
	
	for column in columns:
		var title = settings.column_titles[column]
		set_column_title(column, title)

## Creates the week tree items and assigns them to the week items array
func _setup_weeks(p_game_month : GameMonth, p_day_of_week_offset : int):
	var total_days_for_week_items = p_game_month.days + (p_day_of_week_offset % columns)
	var weeks = ceil(total_days_for_week_items as float / columns) # Remainder offset just encase int value passed is positive

	for week in weeks:
		var week_item : TreeItem = root.create_child(week)
		week_items.append(week_item)
		
func _setup_days(p_days : int, p_day_of_week_offsets : int):
	
	for day_idx in p_days:
		var day = day_idx + 1
		var setup_date = GameDate.new(day, month_idx + 1, time_state.date_time.date.year)
		var column_position = time_state.calendar.get_day_of_week_index(setup_date)
		var week_idx = (day_idx + p_day_of_week_offsets) / columns
		var week_item = week_items[week_idx]
		var day_text : String = str(day)
		week_item.set_text(column_position, day_text)
		
		var event_day : EventDay = time_state.calendar.get_event_day(setup_date)
		
		if event_day != null:
			if event_day.icon != null:
				week_item.set_icon(column_position, event_day.icon)
			
			var wrapped_event_day_text = settings.event_day_number_text % day
			
			if settings.append_event_day_titles:
				week_item.set_text(column_position, "%s %s" % [wrapped_event_day_text, event_day.display_name])
			else:
				week_item.set_text(column_position, settings.event_day_number_text % day)
			
			week_item.set_tooltip_text(column_position, event_day.get_tooltip())

## Updates the month whenever the date changes
func _on_date_changed(event : DateChangeEvent):
	var new_month : GameMonth = time_state.calendar.get_game_month(event.new)
	
	if event.old.year == shown_year && event.old.month == month_idx + 1:
		clear_highlight(event.old.day)
	
	if event.new.year == shown_year && event.new.month == month_idx + 1:
		highlight_day(event.new.day)
