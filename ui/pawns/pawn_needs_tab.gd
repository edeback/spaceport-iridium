class_name PawnNeedsTab
extends PanelContainer

@export var health_bar: ProgressBar
@export var sleep_bar: ProgressBar
@export var hunger_bar: ProgressBar
@export var recreation_bar: ProgressBar
@export var happiness_bar: ProgressBar

var pawn_needs: PawnNeedsComponent = null
var pawn_health: PawnHealthComponent = null

func set_pawn(_pawn: PawnBase) -> void:
	pawn_needs = _pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	pawn_health = _pawn.get_component_by_type(PawnHealthComponent) as PawnHealthComponent
	if pawn_needs == null and pawn_health == null:
		visible = false
		return
	# Health lives in its own component (WI-05) - row shown iff it exists.
	if pawn_health != null:
		pawn_health.health_changed.connect(_on_health_changed)
		health_bar.value = pawn_health.health_value
	else:
		%HealthContainer.visible = false
	if pawn_needs != null:
		if pawn_needs.has_sleep_need:
			pawn_needs.sleep_changed.connect(_on_sleep_changed)
			sleep_bar.value = pawn_needs.sleep_value
		else:
			%SleepContainer.visible = false
		if pawn_needs.has_hunger_need:
			pawn_needs.hunger_changed.connect(_on_hunger_changed)
			hunger_bar.value = pawn_needs.hunger_value
		else:
			%HungerContainer.visible = false
		if pawn_needs.has_recreation_need:
			pawn_needs.recreation_changed.connect(_on_recreation_changed)
			recreation_bar.value = pawn_needs.recreation_value
		else:
			%RecreationContainer.visible = false
		pawn_needs.happiness_changed.connect(_on_happiness_changed)
		happiness_bar.value = pawn_needs.happiness * 100.0
	else:
		%SleepContainer.visible = false
		%HungerContainer.visible = false
		%RecreationContainer.visible = false
		%HappinessContainer.visible = false

func _on_health_changed(new_health: float) -> void:
	health_bar.value = new_health

func _on_sleep_changed(new_sleep: float) -> void:
	sleep_bar.value = new_sleep

func _on_hunger_changed(new_hunger: float) -> void:
	hunger_bar.value = new_hunger

func _on_recreation_changed(new_recreation: float) -> void:
	recreation_bar.value = new_recreation

func _on_happiness_changed(new_happiness: float) -> void:
	happiness_bar.value = new_happiness * 100.0
