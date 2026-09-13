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
## the header and the tabs go somewhere better: the adjacency fields into the
## Status tab, and integrity and DECONSTRUCT / DEMOLISH into the Upkeep tab - its
## page and its footer row - since the inverted inspector keeps the identity strip
## to the vital (2026-09-13). Integrity is still on the strip, as `INT 88%` on the
## meta line.
##
## WI-64 folded three of the resulting tabs into one. Power, Air and the
## synthetic Environment page are now sections of a single Status tab; the plan
## decides which sources fold and in what order, [ModuleStatusTab] stacks them,
## and the component UIs themselves are untouched.
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

## Location, crew occupancy, haul priority and integrity - the numbers the design
## puts in front of the tabs. Haul priority is surfaced here on purpose: Stores
## (WI-56) is where it is edited in bulk, but you can *see* it from a selection.
## Integrity is here because it is the thing you look at first on a module you
## just clicked after a raid; its bar is on the Upkeep tab.
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
	# The module's OWN bin, not the first StorageComponent the walk finds: every
	# module also carries construction's, which sits at +100 and is not what the
	# player is being told about here. A screenshot caught this reading "Haul
	# +100" on a refinery the Stores panel had at +1 (WI-65).
	#
	# And nothing at all for an export-only bin: OUTPUT implies the floor, so a
	# number there would imply a lever that does not exist.
	var storage: StorageComponent = _haulable_storage()
	if storage != null and StoresModel.priority_editable(storage):
		parts.append("Haul %+d" % storage.priority)
	if _module.is_complete():
		parts.append("Int %d%%" % roundi(_module.hp_fraction() * 100.0))
	else:
		parts.append("Under construction")
	return " · ".join(parts)

## The module's own storage - the one whose priority the player sets - skipping
## construction's material bin.
func _haulable_storage() -> StorageComponent:
	for component: ComponentBase in _module.components:
		var storage := component as StorageComponent
		if storage != null and not storage.construction_storage:
			return storage
	return null

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

## DECONSTRUCT recovers materials; DEMOLISH does not. Both are destructive, so
## both are outline-only - [ActionButton] is where that invariant is enforced, so
## asking for the weight is all this has to do. They hang under the Upkeep page,
## never on the identity strip (2026-09-13).
##
## Shown only for a finished module, which is the same gate the construction tab
## used: a blueprint is cancelled by right-clicking it, and offering "deconstruct"
## on something not yet constructed would be a nonsense action.
func page_footer(id: StringName) -> Control:
	if id != InspectorTabPlan.TAB_UPKEEP or not is_alive():
		return null
	var construction: ConstructionComponent = _construction()
	if construction == null or construction.current_state != ConstructionComponent.ConstructionState.Built:
		return null
	var out: Array[Control] = []
	var deconstruct: ActionButton = ActionButton.create("Deconstruct", ActionButton.Weight.DESTRUCTIVE)
	deconstruct.tooltip_text = "Take the module apart and recover its materials."
	deconstruct.pressed.connect(construction.start_deconstruction)
	out.append(deconstruct)
	var demolish: ActionButton = ActionButton.create("Demolish", ActionButton.Weight.DESTRUCTIVE)
	demolish.tooltip_text = "Remove the module immediately. Its materials are lost."
	demolish.pressed.connect(_on_demolish)
	out.append(demolish)
	return action_row(out)

func _on_demolish() -> void:
	if is_alive():
		Global.world_manager.remove_module(_module)

# --- tabs ----------------------------------------------------------------------

func tabs() -> Array[Dictionary]:
	return _tabs

func make_page(id: StringName) -> Control:
	if id == InspectorTabPlan.TAB_STATUS:
		return _make_status_page(_sources_for(id))
	return _make_source_page(_source_for(id))

## Power, air and the surroundings stacked into one page (WI-64).
##
## The sections are the same pages the three separate tabs used to be - nothing
## is re-rendered here, and a component UI that declines to build itself simply
## contributes no section. Returns null if every source declined, which drops the
## tab rather than leaving an empty one.
func _make_status_page(indices: Array[int]) -> Control:
	var sections: Array[Dictionary] = []
	for index: int in indices:
		var content: Control = _make_source_page(index)
		if content == null:
			continue
		sections.append({
			"heading": InspectorTabPlan.status_heading(_keys[index]),
			"content": content,
		})
	if sections.is_empty():
		return null
	var page := ModuleStatusTab.new()
	page.setup(sections)
	return page

## The page one source contributes - a component's own UI, or a tab this set
## synthesises. Shared by the single-source tabs and by the Status fold, which is
## why the synthetic Environment page is built here rather than inside the fold.
func _make_source_page(index: int) -> Control:
	if index < 0 or index >= _keys.size():
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
		InspectorTabPlan.SYNTHETIC_UPKEEP:
			var upkeep := ModuleUpkeepTab.new()
			upkeep.setup(_module)
			return upkeep
	return null

func _source_for(id: StringName) -> int:
	for tab: Dictionary in _tabs:
		if StringName(tab["id"]) == id:
			return int(tab["source"])
	return -1

## Every source behind a tab, which is more than one only for the Status fold.
func _sources_for(id: StringName) -> Array[int]:
	for tab: Dictionary in _tabs:
		if StringName(tab["id"]) == id:
			var sources: Array = tab.get("sources", [])
			var out: Array[int] = []
			for source: int in sources:
				out.append(source)
			return out
	return []

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
		_keys.append(InspectorTabPlan.resolve_key(_class_chain_of(component)))
		_builders.append(component)
	# Environment covers the adjacency fields AND the module's temperature (WI-60).
	# The gate used to ask only about fields, which was right when fields were the
	# tab's whole content - but every module now has a thermal body, so a module
	# sitting in no field at all still has something to report. Without the second
	# clause the temperature is unreachable in the UI for most of the station.
	#
	# Still gathered as its own key after WI-64: the fold happens in the plan, and
	# a gate here that asked "does this module need a Status tab?" would be the
	# plan's rule reimplemented in the panel.
	var has_fields: bool = Global.adjacency_manager != null \
		and not Global.adjacency_manager.get_all_fields(_module).is_empty()
	var has_heat: bool = Global.heat_manager != null \
		and Global.heat_manager.get_component(_module) != null
	if has_fields or has_heat:
		_keys.append(InspectorTabPlan.SYNTHETIC_ENVIRONMENT)
		_builders.append(null)
	# Upkeep is about a standing hull, so it arrives when the module is finished -
	# the moment the Build tab retires and the demolition pair becomes legal.
	if _module.is_complete():
		_keys.append(InspectorTabPlan.SYNTHETIC_UPKEEP)
		_builders.append(null)
	if Global.unlock_manager != null \
			and not Global.unlock_manager.get_local_upgrade_catalog(_module).is_empty():
		_keys.append(InspectorTabPlan.SYNTHETIC_UPGRADES)
		_builders.append(null)
	_tabs = InspectorTabPlan.module_tabs(_keys)

## The component's own `class_name` and those of its base scripts, most-derived
## first - which is what [method InspectorTabPlan.resolve_key] keys on.
##
## The **chain** rather than just the leaf, because a component that subclasses
## another and inherits its `get_ui()` produces that base's page and belongs
## under that base's tab. Walking it here rather than in the plan keeps the plan
## free of [Script] - it is pure, and a chain of strings is what a test can hand
## it.
##
## Falls back to the script's file name for a script with no global class, so a
## nameless component still gets a stable tab id rather than sharing "" with
## every other nameless one.
static func _class_chain_of(component: ComponentBase) -> Array[String]:
	var out: Array[String] = []
	var script: Script = component.get_script() as Script
	while script != null:
		var global: StringName = script.get_global_name()
		if global != &"":
			out.append(String(global))
		elif out.is_empty():
			# Only the leaf is worth naming by file: an anonymous script part-way
			# up a chain is not something any table is keyed on.
			out.append(script.resource_path.get_file().get_basename())
		script = script.get_base_script()
	if out.is_empty():
		out.append(component.name)
	return out

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
	# The Environment section appears the moment a field reaches this module and
	# retires when the last one leaves - which since WI-64 usually repaints the
	# Status tab in place rather than adding or removing a tab, because a module
	# with power or air already had one.
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
