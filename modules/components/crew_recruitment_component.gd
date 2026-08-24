class_name CrewRecruitmentComponent
extends ComponentBase

## Marks a constructed docking bay as the station's crew gateway (WI-07):
## arriving shuttles target the owning module, resigning crew walk here to leave
## (the departure job finds bays through the "crew_recruitment" group), and a
## hire is only possible while at least one of these exists.
##
## **It no longer carries a UI.** The recruitment window used to be a component
## page on this module, which meant the only way to learn that hiring existed was
## to find the docking bay and click it. It is now the Crew panel's `HIRE` tab
## ([HireTab]), which still hires *through* this component - the gate is
## unchanged, only its address is. This component is therefore pure gameplay: it
## reports the bay, and [method request_hire] is what the tab calls.

func ready_constructed() -> void:
	add_to_group(Groups.CREW_RECRUITMENT)

func request_hire(candidate: HireCandidate) -> bool:
	return Global.crew_manager.request_hire(owner_module, candidate)
