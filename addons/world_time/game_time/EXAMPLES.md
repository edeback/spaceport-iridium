
## How to send out an event or perform code when the game month changes

```gdscript 
class_name DateChangeMonitor
extends Node

@export var time_state: TimeStateLogic

func _ready() -> void:
    if not time_state:
        push_error("TimeStateLogic not set in DateChangeMonitor")
        return
    
    time_state.date_changed.connect(_on_date_changed)

func _on_date_changed(event: DateChangeEvent) -> void:
    if event.old and event.new and event.old.month != event.new.month:
        # TODO: Add month change response here
        pass
```

## Time skip during a pause menu?

Call go_to_next_day on GameTimeSystem manually from your code. This could be on the button click that confirms finishing the day and starting the new one.

```class_name DayController
extends Node

@export var game_time_system: GameTimeSystem

func _ready() -> void:
    if not game_time_system:
        push_error("GameTimeSystem not set in DayController")
        return

# Example function to advance to next day
func advance_day() -> void:
    # Call go_to_next_day with no specific start time
    game_time_system.go_to_next_day()
    
    # OR call with a specific start time (e.g., 6 AM)
    # var morning_time = HoursTime.new(6, 0)  # 6:00 AM
    # game_time_system.go_to_next_day(morning_time)
```