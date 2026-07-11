class_name PawnNeedsComponent
extends PawnComponentBase

@export var percent_critical: float = 5
@export var percent_to_look_for_needs: float = 30

@export var has_health_need: bool = false
@export var health_max: float = 100
@export var health_value: float = 100:
	set(new_health):
		new_health = clampf(new_health, 0, health_max)
		if health_value != new_health:
			health_value = new_health
			health_changed.emit(health_value)
signal health_changed(new_health: float)

@export var has_sleep_need: bool = false
@export var sleep_max: float = 100
@export var sleep_value: float = 100:
	set(new_sleep):
		new_sleep = clampf(new_sleep, 0, sleep_max)
		if sleep_value != new_sleep:
			sleep_value = new_sleep
			sleep_changed.emit(sleep_value)
signal sleep_changed(new_sleep: float)

@export var has_hunger_need: bool = false
@export var hunger_max: float = 100
@export var hunger_value: float = 100:
	set(new_hunger):
		new_hunger = clampf(new_hunger, 0, hunger_max)
		if hunger_value != new_hunger:
			hunger_value = new_hunger
			hunger_changed.emit(hunger_value)
signal hunger_changed(new_hunger: float)
@export var hunger_duration_seconds: float = 600

var _pending_eat_job: Job_Eat = null

@export var has_entertainment_need: bool = false
@export var entertainment_max: float = 100
@export var entertainment_value: float = 100:
	set(new_entertainment):
		new_entertainment = clampf(new_entertainment, 0, entertainment_max)
		if entertainment_value != new_entertainment:
			entertainment_value = new_entertainment
			entertainment_changed.emit(entertainment_value)
signal entertainment_changed(new_entertainment: float)
@export var entertainment_duration_seconds: float = 900

@export var has_social_need: bool = false
@export var social_max: float = 100
@export var social_value: float = 100:
	set(new_social):
		new_social = clampf(new_social, 0, social_max)
		if social_value != new_social:
			social_value = new_social
			social_changed.emit(social_value)
signal social_changed(new_social: float)
@export var social_duration_seconds: float = 1200

func _process(delta: float) -> void:
	if has_hunger_need and hunger_duration_seconds > 0:
		hunger_value -= delta / hunger_duration_seconds * hunger_max
		# Interrupting causes issues since this happens every frame, as if there is no food,
		# the pawn gets locked into trying to eat and can never do things like make more food
		#if hunger_value < percent_critical and _needs_new_eat_job():
			#_pending_eat_job = Job_Eat.new()
			#_pending_eat_job.job_end.connect(finished_eating)
			#owner_pawn.interrupt_with_job(_pending_eat_job)
		if hunger_value < percent_to_look_for_needs and _needs_new_eat_job():
			_pending_eat_job = Job_Eat.new()
			_pending_eat_job.job_end.connect(finished_eating)
			owner_pawn.queue_job(_pending_eat_job) # start when free
	if has_social_need and social_duration_seconds > 0:
		social_value -= delta / social_duration_seconds * social_max
		if social_value < percent_to_look_for_needs:
			pass
	if has_entertainment_need and entertainment_duration_seconds > 0:
		entertainment_value -= delta / entertainment_duration_seconds * entertainment_max
		if entertainment_value < percent_to_look_for_needs:
			pass
			
func _needs_new_eat_job() -> bool:
	return _pending_eat_job == null #or _pending_eat_job.is_finished() or _pending_eat_job.is_failed()
			
func finished_eating() -> void:
	_pending_eat_job = null
