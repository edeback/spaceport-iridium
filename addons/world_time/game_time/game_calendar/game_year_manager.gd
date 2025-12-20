# filepath: addons/world_time/game_time/game_year_manager.gd
class_name GameYearManager
extends Resource

@export var years: Array[GameYear] = []

func get_game_year(year_number: int, start_date: GameDate) -> GameYear:
    if years.is_empty():
        push_error("No years in calendar.")
        return null

    var remainder = (year_number - start_date.year) % years.size()
    return years[remainder]

func get_game_month(date: GameDate) -> GameMonth:
    var year = get_game_year(date.year, GameDate.new(1, 1, 1))  # Example start date
    return year.months[date.month - 1]