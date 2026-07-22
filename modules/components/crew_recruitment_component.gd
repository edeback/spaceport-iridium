class_name CrewRecruitmentComponent
extends ComponentBase

## Marks a constructed docking bay as the station's crew gateway (WI-07):
## the recruitment UI lives here, arriving shuttles target the owning
## module, and resigning crew walk here to leave (Job_LeaveStation finds
## bays through the "crew_recruitment" group).

var override_ui: bool = false

func ready_preview() -> void:
	override_ui = false

func ready_blueprint() -> void:
	override_ui = false

func ready_constructed() -> void:
	override_ui = true
	add_to_group(Groups.CREW_RECRUITMENT)

func request_hire(candidate: HireCandidate) -> bool:
	return Global.crew_manager.request_hire(owner_module, candidate)

func has_ui() -> bool:
	return override_ui

func get_ui() -> ModuleComponentUI:
	var ui: UICrewRecruitment = ui_info_panel_element.instantiate() as UICrewRecruitment
	ui.set_module(owner_module)
	ui.set_recruitment_component(self)
	return ui
