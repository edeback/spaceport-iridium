class_name TimeDateCalculator
extends RefCounted
## Handles time conversions and date arithmetic for the game calendar.

var time_scale: TimeScale
var start_date: GameDate
var calendar_structure: CalendarStructure

func _init(p_time_scale: TimeScale = TimeScale.new(), p_start_date: GameDate = null, p_calendar_structure: CalendarStructure = null):
	time_scale = p_time_scale
	start_date = p_start_date
	calendar_structure = p_calendar_structure

# TimeConverter methods
func get_days_from_seconds(p_seconds: float) -> float:
	return p_seconds / time_scale.seconds_per_day

func get_seconds_to_game_units(p_seconds_progressed: float, interval_unit: TimeEnums.Unit) -> float:
	match interval_unit:
		TimeEnums.Unit.SECOND:
			return p_seconds_progressed
		TimeEnums.Unit.MINUTE:
			return p_seconds_progressed / time_scale.seconds_per_minute
		TimeEnums.Unit.HOUR:
			return p_seconds_progressed / time_scale.seconds_per_hour
		TimeEnums.Unit.DAY:
			return get_days_from_seconds(p_seconds_progressed)
		_:
			return 0.0

func get_seconds_to_real_time_units(p_delta: float, interval_unit: TimeEnums.Unit) -> float:
	match interval_unit:
		TimeEnums.Unit.SECOND:
			return p_delta
		TimeEnums.Unit.MINUTE:
			return p_delta / 60
		TimeEnums.Unit.HOUR:
			return p_delta / (60 * 60)
		TimeEnums.Unit.DAY:
			return p_delta / (60 * 60 * 24)
		_:
			return 0.0

func get_seconds_from_date_time(p_date_time: DateTime) -> float:
	var date_secs = get_seconds_from_date(p_date_time.date)
	var hours_secs = get_seconds_from_hours_time(p_date_time.time)
	return date_secs + hours_secs

func get_seconds_from_hours_time(p_time: HoursTime) -> float:
	var hours_seconds = p_time.hours * time_scale.seconds_per_hour
	var minute_seconds = p_time.minutes * time_scale.seconds_per_minute
	return hours_seconds + minute_seconds + p_time.seconds

func get_hours_time_from_seconds(p_game_seconds: float) -> HoursTime:
	var total_seconds = fmod(p_game_seconds, time_scale.seconds_per_day)
	if total_seconds < 0:
		total_seconds += time_scale.seconds_per_day

	var hours: int = floor(total_seconds / (time_scale.minutes_per_hour * time_scale.seconds_per_minute))
	var remaining_seconds_after_hours: float = total_seconds - (hours * time_scale.minutes_per_hour * time_scale.seconds_per_minute)
	var minutes: int = floor(remaining_seconds_after_hours / time_scale.seconds_per_minute)
	var seconds: float = remaining_seconds_after_hours - (minutes * time_scale.seconds_per_minute)

	return HoursTime.new(hours, minutes, seconds)

func get_duration_as_game_seconds(p_duration: GameTimeDuration) -> float:
	var days_secs = p_duration.days * time_scale.seconds_per_day
	var hours_secs = p_duration.hours * time_scale.seconds_per_hour
	var minutes_secs = p_duration.minutes * time_scale.seconds_per_minute
	var total = days_secs + hours_secs + minutes_secs + p_duration.seconds
	return max(total, 0)

func get_seconds_between(p_start_date_time: DateTime, p_end_date_time: DateTime) -> float:
	var start_secs = get_seconds_from_date_time(p_start_date_time)
	var end_secs = get_seconds_from_date_time(p_end_date_time)
	return end_secs - start_secs

func adjust_hours_time(p_time: HoursTime, p_seconds: float) -> void:
	var time_seconds = max(get_seconds_from_hours_time(p_time) + p_seconds, 0)
	var seconds_per_hour = time_scale.seconds_per_hour
	var seconds_per_minute = time_scale.seconds_per_minute
	p_time.hours = int(time_seconds / seconds_per_hour)
	var hours_remainder = fmod(time_seconds, seconds_per_hour)
	p_time.minutes = int(hours_remainder / seconds_per_minute)
	p_time.seconds = fmod(hours_remainder, seconds_per_minute)

# DateCalculator methods
func advance_date_time(p_start_date_time: DateTime, p_advance_seconds: float) -> DateTime:
	var start_time := get_seconds_from_date_time(p_start_date_time)
	var total_seconds := start_time + p_advance_seconds
	var date_time := get_date_time_from_seconds(total_seconds)
	return date_time

func get_date_time_from_seconds(p_seconds: float) -> DateTime:
	var seconds_per_day = time_scale.seconds_per_day
	var days_from_start: int = p_seconds / seconds_per_day
	var seconds_remainder: float = p_seconds - (days_from_start * seconds_per_day)
	
	while seconds_remainder < 0:
		days_from_start -= 1
		seconds_remainder += seconds_per_day
		
	var game_date = adjust_date(start_date, days_from_start)
	var hours_time = get_hours_time_from_seconds(seconds_remainder)
	return DateTime.new(game_date, hours_time)

func get_last_hours_time_as_date_time(hours_time: HoursTime, current_date_time: DateTime) -> DateTime:
	var tested_hours_time_secs = get_seconds_from_hours_time(hours_time)
	var current_hours_time_secs = get_seconds_from_hours_time(current_date_time.time)
	var date_for_last_time: GameDate
	
	if tested_hours_time_secs <= current_hours_time_secs:
		date_for_last_time = current_date_time.date
	else:
		date_for_last_time = get_previous_date(current_date_time.date)
		
	return DateTime.new(date_for_last_time, hours_time)

func get_last_hours_time_as_secs(hours_time: HoursTime, current_date_time: DateTime) -> float:
	var last_date_time = get_last_hours_time_as_date_time(hours_time, current_date_time)
	return get_seconds_from_date_time(last_date_time)

func get_previous_date(p_start_date: GameDate) -> GameDate:
	if p_start_date.day == 1:
		if p_start_date.month == 1:
			var last_year_num = p_start_date.year - 1
			var game_year = calendar_structure.get_game_year(last_year_num)
			var months = game_year.months.size()
			var month: GameMonth = game_year.months[months - 1]
			return GameDate.new(month.days, months, p_start_date.year - 1)
		else:
			var month_index = p_start_date.month - 1
			var game_year = calendar_structure.get_game_year(p_start_date.year)
			var month: GameMonth = game_year.months[month_index - 1]
			return GameDate.new(month.days, month_index, p_start_date.year)
	else:
		return GameDate.new(p_start_date.day - 1, p_start_date.month, p_start_date.year)

func get_next_day(p_start_date: GameDate) -> GameDate:
	var game_year = calendar_structure.get_game_year(p_start_date.year)
	var game_month = calendar_structure.get_game_month(p_start_date)

	if p_start_date.day == game_month.days && p_start_date.month == game_year.months.size():
		return GameDate.new(1, 1, p_start_date.year + 1)
		
	if p_start_date.day == game_month.days:
		return GameDate.new(1, p_start_date.month + 1, p_start_date.year)
	
	return GameDate.new(p_start_date.day + 1, p_start_date.month, p_start_date.year)

## Gets a DateTime that is the next day from the current day, optionally at a p_desired_time during that date (like a day start time)
func get_next_date_time(p_current : DateTime, p_desired_time : HoursTime = null) -> DateTime:
	var next_day : GameDate = get_next_day(p_current.date)
	var new_time : HoursTime = p_desired_time if p_desired_time != null else p_current.time
	var next_dt := DateTime.new(next_day, new_time)
	return next_dt

func get_day_number(p_date: GameDate) -> int:
	return get_days_between(start_date, p_date)

func get_days_between(p_start_date: GameDate, p_end_date: GameDate) -> int:
	var total_days: int = 0
	for year_number in range(p_start_date.year, p_end_date.year + 1):
		var game_year: GameYear = calendar_structure.get_game_year(year_number)
		total_days += game_year.get_days_count()
	var days_in_year_before_start_date = calendar_structure.get_days_into_year(p_start_date)
	var days_in_year_after_end_date = calendar_structure.get_days_until_end_of_year(p_end_date)
	return total_days - (days_in_year_before_start_date + days_in_year_after_end_date)

func get_months_between(p_start_date: GameDate, p_end_date: GameDate) -> int:
	var months_between_dates = 0
	for year_number in range(p_start_date.year, p_end_date.year + 1):
		var game_year: GameYear = calendar_structure.get_game_year(year_number)
		months_between_dates += game_year.months.size()
		if year_number == p_start_date.year:
			months_between_dates -= p_start_date.month
		if year_number == p_end_date.year:
			months_between_dates += (p_end_date.month - game_year.months.size())
	return months_between_dates

func get_seconds_from_date(p_game_date: GameDate) -> float:
	var days = get_days_between(start_date, p_game_date)
	return days * time_scale.seconds_per_day

func get_date_from_seconds(p_seconds: float) -> GameDate:
	var seconds_per_day = time_scale.seconds_per_day
	var days = int(p_seconds / seconds_per_day)
	if p_seconds < 0:
		days -= 1
	return adjust_date(start_date, days)

func adjust_date(p_date: GameDate, p_days_change: int) -> GameDate:
	var date_adjustment = DateAdjustment.new(p_date, p_days_change, calendar_structure)
	return date_adjustment.calculate_adjusted()

func get_days_before_start_of_year(p_year_num: int) -> int:
	var year_number = start_date.year
	var days_to_start = 0
	while year_number < p_year_num:
		days_to_start += calendar_structure.get_game_year(year_number).get_days_count()
		year_number += 1
	return days_to_start
