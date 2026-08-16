class_name ModuleTabSet
extends InspectorTabSet

## The MODULE tab set (WI-51): what `windows/module_info_ingame_panel.tscn` used
## to be, minus the frame.
##
## The component walk is unchanged - `ModuleBase.components` is scanned,
## `ComponentBase.has_ui()` / `get_ui()` supplies each page, and the seventeen
## component UIs keep their logic. What changes is that the tabs are **ordered
## and named** by [InspectorTabPlan] instead of arriving in scene order under
## their UI's node name, and that the three things the old panel injected between
## the header and the tabs go somewhere better: integrity into the subject block,
## the adjacency fields into an Environment tab, and DECONSTRUCT / DEMOLISH into
## the footer.
##
## Corridors need no special case. They are [ModuleBase] instances on the
## CORRIDOR layer and resolve here with whatever components they carry - usually
## none, which is the empty-strip case the subject block covers.

var _module: ModuleBase = null

## Class name per contributing tab, in walk order, and the component (or null for
## a synthetic tab) that builds its page. Parallel arrays indexed by the `source`
## field [InspectorTabPlan.module_tabs] hands back.
var _keys: Array[String] = []
var _builders: Array[ComponentBase] = []
var _tabs: Array[Dictionary] = []

## Latest error text per component, exactly as the old panel tracked it - a
## component reports its own trouble and the panel aggregates.
var _errors: Dictionary[ComponentBase, String] = {}

func kind_label() -> String:
	return "MODULE"

func bind(subject: Variant) -> void:
	_module = subject as ModuleBase
	if _module == null:
		return
	_module.selected = true
	SignalBus.module_damaged.connect(_on_durability_changed)
	SignalBus.module_repaired.connect(_on_durability_changed)
	SignalBus.module_breach_started.connect(_on_module_event)
	SignalBus.module_breach_sealed.connect(_on_module_event)
	SignalBus.module_upgraded.connect(_on_module_event)
	if Global.adjacency_manager != null:
		Global.adjacency_manager.fields_changed.connect(_on_fields_changed)
	for component: ComponentBase in _module.components:
		_errors[component] = component.last_error
		component.new_error.connect(_on_component_error)
	var construction: ConstructionComponent = _construction()
	if construction != null:
		# Finishing construction changes both the tab set (the Build tab retires)
		# and the footer (the demolition actions arrive), so it is the one state
		# change that has to rebuild everything.
		construction.state_changed.connect(_on_construction_state_changed)
	_gather()

func _exit_tree() -> void:
	# The shader tint and the selection brackets are driven off `selected`, so it
	# has to come off when the set does - including when the panel swaps kinds
	# rather than deselecting.
	if _module != null and is_instance_valid(_module):
		_module.selected = false

func is_alive() -> bool:
	return _module != null and is_instance_valid(_module)

func camera_target() -> Node2D:
	return _module

# --- subject block -------------------------------------------------------------

func subject_name() -> String:
	if not is_alive() or _module.module_data == null:
		return "Module"
	return _module.module_data.name

## Location, crew occupancy and haul priority - the three numbers the design puts
## in front of the tabs. Haul priority is surfaced here on purpose: Stores (WI-56)
## is where it is edited in bulk, but you can *see* it from a selection.
func meta_text() -> String:
	if not is_alive():
		return ""
	var parts: Array[String] = ["Cell %d,%d" % [_module.module_cell.x, _module.module_cell.y]]
	var workspace: WorkspaceComponent = _module.get_component_by_type(WorkspaceComponent) as WorkspaceComponent
	if workspace != null:
		var assigned: int = workspace.get_assigned().size()
		if workspace.max_workers > 0:
			parts.append("Crew %d/%d" % [assigned, workspace.max_workers])
		else:
			parts.append("Crew %d" % assigned)
	var storage: StorageComponent = _module.get_component_by_type(StorageComponent) as StorageComponent
	if storage != null:
		parts.append("Haul %+d" % storage.priority)
	if not _module.is_complete():
		parts.append("Under construction")
	return " · ".join(parts)

## Damage, breakdown and breach, then whatever the components are complaining
## about. One amber line: the design budgets amber, and four separate warnings
## competing for attention is how a budget gets spent.
func status_text() -> String:
	if not is_alive():
		return ""
	var parts: Array[String] = []
	if _module.is_complete():
		if _module.hp_fraction() < 1.0:
			parts.append("Damaged")
		if _module.has_breakdown():
			parts.append("Broken down")
		var atmosphere: AtmosphereComponent = _module.get_atmosphere()
		if atmosphere != null and atmosphere.is_breached():
			parts.append("Breached")
	for component: ComponentBase in _errors:
		var error: String = _errors[component]
		# Deduplicated: two components on one module routinely report the same
		# cause ("No power!" from both a consumer and a processor), and amber is a
		# budget - the same sentence twice spends it for nothing.
		if not error.is_empty() and not parts.has(error):
			parts.append(error)
	return " / ".join(parts)

func icon_color() -> Color:
	if not is_alive():
		return Color(0.0, 0.0, 0.0, 0.0)
	if not _module.is_complete():
		return UIPalette.tinted(UIPalette.LIVE, 0.5)
	return UIPalette.tinted(UIPalette.GROWTH, 0.7)

func icon_texture() -> Texture2D:
	if not is_alive() or _module.module_data == null:
		return null
	return _module.module_data.icon

## Integrity, and only integrity. It moved out of the tab strip into the subject
## block because it is the thing you look at first on a module you just clicked
## after a raid, and a bar behind a tab is a bar nobody checks.
func subject_bars() -> Array[Dictionary]:
	if not is_alive() or not _module.is_complete():
		return []
	var fraction: float = _module.hp_fraction()
	return [{
		"label": "Integrity",
		"fraction": fraction,
		"value": "%d%%" % int(round(fraction * 100.0)),
		# Through the palette's threshold, not `< 1.0` (WI-58): a module one point
		# down from full is not a falling vital, and amber that fires on every
		# scratch stops meaning "look at this now" anywhere else.
		"tint": UIPalette.gauge_tint(fraction),
	}]

## DECONSTRUCT recovers materials; DEMOLISH does not. Both are destructive, so
## both are outline-only - [ActionButton] is where that invariant is enforced, so
## asking for the weight is all this has to do.
##
## Shown only for a finished module, which is the same gate the construction tab
## used: a blueprint is cancelled by right-clicking it, and offering "deconstruct"
## on something not yet constructed would be a nonsense action.
func footer_actions() -> Array[Control]:
	if not is_alive():
		return []
	var construction: ConstructionComponent = _construction()
	if construction == null or construction.current_state != ConstructionComponent.ConstructionState.Built:
		return []
	var out: Array[Control] = []
	var deconstruct: ActionButton = ActionButton.create("Deconstruct", ActionButton.Weight.DESTRUCTIVE)
	deconstruct.tooltip_text = "Take the module apart and recover its materials."
	deconstruct.pressed.connect(construction.start_deconstruction)
	out.append(deconstruct)
	var demolish: ActionButton = ActionButton.create("Demolish", ActionButton.Weight.DESTRUCTIVE)
	demolish.tooltip_text = "Remove the module immediately. Its materials are lost."
	demolish.pressed.connect(_on_demolish)
	out.append(demolish)
	return out

func _on_demolish() -> void:
	if is_alive():
		Global.world_manager.remove_module(_module)

# --- tabs ----------------------------------------------------------------------

func tabs() -> Array[Dictionary]:
	return _tabs

func make_page(id: StringName) -> Control:
	var index: int = _source_for(id)
	if index < 0:
		return null
	var component: ComponentBase = _builders[index]
	if component != null:
		return component.get_ui() if is_instance_valid(component) else null
	match _keys[index]:
		InspectorTabPlan.SYNTHETIC_ENVIRONMENT:
			var environment := ModuleEnvironmentTab.new()
			environment.setup(_module)
			return environment
		InspectorTabPlan.SYNTHETIC_UPGRADES:
			var upgrades := LocalUpgradesTab.new()
			upgrades.setup(_module)
			return upgrades
	return null

func _source_for(id: StringName) -> int:
	for tab: Dictionary in _tabs:
		if StringName(tab["id"]) == id:
			return int(tab["source"])
	return -1

## Re-derives the tab set from the module's current state. Cheap, and called on
## anything that can change the set's shape rather than being worked out per
## trigger - a component that just finished building, an upgrade catalogue that
## just unlocked, a field that just reached this module.
func _gather() -> void:
	_keys.clear()
	_builders.clear()
	if not is_alive():
		_tabs = []
		return
	for component: ComponentBase in _module.components:
		if not is_instance_valid(component) or not component.has_ui():
			continue
		_keys.append(_class_name_of(component))
		_builders.append(component)
	# Environment covers the adjacency fields AND the module's temperature (WI-60).
	# The gate used to ask only about fields, which was right when fields were the
	# tab's whole content - but every module now has a thermal body, so a module
	# sitting in no field at all still has something to report. Without the second
	# clause the temperature is unreachable in the UI for most of the station.
	var has_fields: bool = Global.adjacency_manager != null \
		and not Global.adjacency_manager.get_all_fields(_module).is_empty()
	var has_heat: bool = Global.heat_manager != null \
		and Global.heat_manager.get_component(_module) != null
	if has_fields or has_heat:
		_keys.append(InspectorTabPlan.SYNTHETIC_ENVIRONMENT)
		_builders.append(null)
	if Global.unlock_manager != null \
			and not Global.unlock_manager.get_local_upgrade_catalog(_module).is_empty():
		_keys.append(InspectorTabPlan.SYNTHETIC_UPGRADES)
		_builders.append(null)
	_tabs = InspectorTabPlan.module_tabs(_keys)

## The component's own `class_name`, which is what [InspectorTabPlan] keys on.
## Falls back to the script's file name for a script with no global class, so a
## nameless component still gets a stable tab id rather than sharing "" with
## every other nameless one.
static func _class_name_of(component: ComponentBase) -> String:
	var script: Script = component.get_script() as Script
	if script == null:
		return component.name
	var global: StringName = script.get_global_name()
	if global != &"":
		return String(global)
	return script.resource_path.get_file().get_basename()

# --- signals -------------------------------------------------------------------

func _on_durability_changed(module: ModuleBase, _amount: float) -> void:
	if module == _module:
		subject_changed.emit()

func _on_module_event(module: ModuleBase) -> void:
	if module != _module:
		return
	# An upgrade can unlock the next tier or exhaust the catalogue, and a breach
	# changes the status line - repaint both halves and let the strip keep its
	# selection if the shape did not actually move.
	_gather()
	tabs_changed.emit()
	subject_changed.emit()

func _on_fields_changed(module: ModuleBase) -> void:
	if module != _module:
		return
	# The Environment tab appears the moment a field reaches this module and
	# retires when the last one leaves.
	_gather()
	tabs_changed.emit()

func _on_construction_state_changed(_state: ConstructionComponent.ConstructionState) -> void:
	_gather()
	tabs_changed.emit()
	subject_changed.emit()

func _on_component_error(component: ComponentBase, error: String) -> void:
	_errors[component] = error
	subject_changed.emit()

func _construction() -> ConstructionComponent:
	if not is_alive():
		return null
	return _module.get_component_by_type(ConstructionComponent) as ConstructionComponent
