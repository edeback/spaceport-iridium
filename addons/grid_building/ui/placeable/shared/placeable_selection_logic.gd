## Shared logic for placeable selection style UIs (grid or sequence list variants)
## Provides dependency resolution, mode visibility toggling, validation helpers.
class_name PlaceableSelectionLogic
extends GBInjectable

signal valid_changed(is_valid: bool)

var _mode_state: ModeState
var _systems_context: GBSystemsContext
var _building_system: BuildingSystem

## Sources injectable dependencies from the p_container so that this GBInjectable
## can operate at runtime
func resolve_gb_dependencies(p_container: GBCompositionContainer) -> bool:
	_systems_context = p_container.get_systems_context()
	_building_system = _systems_context.get_building_system()
	# Guard against duplicate signal connections
	if not _systems_context.building_system_changed.is_connected(_on_building_system_changed):
		_systems_context.building_system_changed.connect(_on_building_system_changed)
	_mode_state = p_container.get_mode_state()
	return true

## Validates the injection depenendicies of this GBInjectable
func get_runtime_issues() -> Array[String]:
	var issues : Array[String] = []
	
	if _mode_state == null:
		issues.append("[mode_state] not set.")
	if _systems_context == null:
		issues.append("[_systems_context] not set.")
	if _building_system == null:
		issues.append("[_building_system] not set")
		
	if issues.size() > 0:
		issues.append("One or more dependencies failed to inject on PlaceableSelectionLogic. Did resolve_gb_dependencies run successfully?")
		
	return issues

func set_mode_state(p_mode_state: ModeState) -> void:
	_mode_state = p_mode_state

func get_building_system() -> BuildingSystem:
	return _building_system

func validate_basic() -> Array[String]:
	return GBValidation.check_not_null(self, ["_building_system"])

func handle_ui_hidden(ui_root: Control) -> void:
	if _mode_state and _mode_state.current == GBEnums.Mode.BUILD:
		_mode_state.current = GBEnums.Mode.OFF

func handle_mode_changed(p_mode: GBEnums.Mode, ui_root: Control) -> void:
	match p_mode:
		GBEnums.Mode.BUILD:
			ui_root.show()
		_:
			ui_root.hide()

func _on_building_system_changed(p_system: BuildingSystem) -> void:
	_building_system = p_system
