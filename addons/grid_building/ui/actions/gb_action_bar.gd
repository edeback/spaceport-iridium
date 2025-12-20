## NOTE: Script now expected to be attached to the internal Buttons HBox inside a PanelContainer wrapper.
## Root PanelContainer provides background; this HBox preserves previous API assumptions.
class_name GBActionBar
extends HBoxContainer

var _mode_state: ModeState


func resolve_gb_dependencies(p_container: GBCompositionContainer) -> void:
	_mode_state = p_container.get_mode_state()
