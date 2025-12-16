class_name PawnNeedsTab
extends PanelContainer

@export var health_bar: ProgressBar
@export var sleep_bar: ProgressBar
@export var hunger_bar: ProgressBar
@export var entertainment_bar: ProgressBar
@export var social_bar: ProgressBar

var pawn_needs: PawnNeedsComponent = null

func set_pawn(_pawn: PawnBase) -> void:
	pawn_needs = _pawn.get_component_by_type(PawnNeedsComponent)
	if pawn_needs != null:
		if pawn_needs.has_health_need:
			pawn_needs.health_changed.connect(_on_health_changed)
			health_bar.value = pawn_needs.health_value
		else:
			%HealthContainer.visible = false
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
		if pawn_needs.has_entertainment_need:
			pawn_needs.entertainment_changed.connect(_on_entertainment_changed)
			entertainment_bar.value = pawn_needs.entertainment_value
		else:
			%EntertainmentContainer.visible = false
		if pawn_needs.has_social_need:
			pawn_needs.social_changed.connect(_on_social_changed)
			social_bar.value = pawn_needs.social_value
		else:
			%SocialContainer.visible = false
	else:
		visible = false

func _on_health_changed(new_health: float) -> void:
	health_bar.value = new_health
	
func _on_sleep_changed(new_sleep: float) -> void:
	sleep_bar.value = new_sleep
	
func _on_hunger_changed(new_hunger: float) -> void:
	hunger_bar.value = new_hunger
	
func _on_entertainment_changed(new_entertainment: float) -> void:
	entertainment_bar.value = new_entertainment
	
func _on_social_changed(new_social: float) -> void:
	social_bar.value = new_social
