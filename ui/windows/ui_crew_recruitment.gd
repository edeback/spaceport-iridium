class_name UICrewRecruitment
extends ModuleComponentUI

@export var status_label: Label
@export var recruit_button: Button

var recruitment_component: CrewRecruitmentComponent

func set_recruitment_component(component: CrewRecruitmentComponent) -> void:
	name = component.name
	recruitment_component = component
	recruit_button.pressed.connect(_on_recruit_pressed)
	_refresh()

func _process(_delta: float) -> void:
	# Credits, capacity, and pending arrivals change from many places;
	# polling is cheap and only runs while the panel is open.
	_refresh()

func _refresh() -> void:
	var manager: CrewManager = Global.crew_manager
	if manager == null:
		return
	recruit_button.text = "Recruit crew (%d cr)" % manager.hire_cost
	var reason: String = manager.hire_block_reason()
	recruit_button.disabled = reason != ""
	var status: String = "Crew %d / %d beds" % [manager.crew_count(), manager.sleep_capacity()]
	if manager.pending_hire_count() > 0:
		status += ", %d arriving" % manager.pending_hire_count()
	if reason != "":
		status += " — " + reason
	status_label.text = status

func _on_recruit_pressed() -> void:
	recruitment_component.request_hire()
	_refresh()
