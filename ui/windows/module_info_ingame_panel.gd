class_name  ModuleInfoIngamePanel
extends Control

@export var module_name_label: Label
@export var data_tabs: TabContainer
@export var alert_label: Label

var module_viewed: ModuleBase

var component_alerts: Dictionary[ComponentBase, String]

## Durability row (WI-24), built in code so the scene stays untouched. Shows the
## viewed module's integrity bar plus a damaged/broken/breached status line.
var _hp_row: HBoxContainer
var _hp_bar: ProgressBar
var _hp_status: Label

## Environment section (WI-30): one line per nonzero adjacency field on the
## viewed module, built in code and refreshed on fields_changed. Hidden when the
## module sits in no fields.
var _env_section: VBoxContainer

## Friendly names / blurbs for each adjacency effect id (WI-30).
const ENV_LABELS: Dictionary[StringName, String] = {
	&"vibration": "Vibration",
	&"greenery": "Greenery",
	&"maintenance": "Maintenance",
	&"purified_air": "Purified air",
}
const ENV_BLURBS: Dictionary[StringName, String] = {
	&"vibration": "rest & recreation reduced nearby",
	&"greenery": "calming surroundings; better rest",
	&"maintenance": "servicing lowers breakdown chance",
	&"purified_air": "cleaner air",
}

func _ready() -> void:
	_build_hp_row()
	_build_env_section()
	# Live-refresh the bar while the panel is open on the affected module.
	SignalBus.module_damaged.connect(_on_durability_changed)
	SignalBus.module_repaired.connect(_on_durability_changed)
	SignalBus.module_breach_started.connect(_on_breach_changed)
	SignalBus.module_breach_sealed.connect(_on_breach_changed)
	if Global.adjacency_manager != null:
		Global.adjacency_manager.fields_changed.connect(_on_fields_changed)

func _build_hp_row() -> void:
	# module_name_label sits in the header HBox; its grandparent is the VBox that
	# stacks header -> (new HP row) -> tabs.
	var header: Node = module_name_label.get_parent()
	var vbox: Node = header.get_parent()
	_hp_row = HBoxContainer.new()
	var label := Label.new()
	label.text = "Integrity"
	_hp_row.add_child(label)
	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = 1.0
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(120, 12)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_row.add_child(_hp_bar)
	_hp_status = Label.new()
	_hp_status.add_theme_color_override("font_color", Color(0.85, 0.55, 0.2))
	_hp_row.add_child(_hp_status)
	vbox.add_child(_hp_row)
	vbox.move_child(_hp_row, header.get_index() + 1)
	_hp_row.visible = false

## Environment section (WI-30): a titled list slotted just under the HP row.
func _build_env_section() -> void:
	var header: Node = module_name_label.get_parent()
	var vbox: Node = header.get_parent()
	_env_section = VBoxContainer.new()
	var title := Label.new()
	title.text = "Environment"
	title.add_theme_color_override("font_color", Color(0.6, 0.75, 0.6))
	_env_section.add_child(title)
	vbox.add_child(_env_section)
	# Just under the HP row (which itself sits under the header).
	vbox.move_child(_env_section, _hp_row.get_index() + 1)
	_env_section.visible = false

func set_module(module: ModuleBase) -> void:
	if module_viewed != null:
		module_viewed.selected = false
	module_viewed = module
	for child_node: Node in data_tabs.get_children():
		data_tabs.remove_child(child_node)
		child_node.queue_free()
	for component: ComponentBase in component_alerts.keys():
		if is_instance_valid(component):
			component.new_error.disconnect(_on_component_error)
	component_alerts.clear()
	if module_viewed != null:
		module_viewed.selected = true
		module_name_label.text = module.module_data.name
		for component: ComponentBase in module.components:
			component_alerts.set(component, component.last_error)
			component.new_error.connect(_on_component_error)
			if component.has_ui():
				data_tabs.add_child(component.get_ui())
		# Add a local-upgrades tab when this module has any upgrades available.
		if not Global.unlock_manager.get_local_upgrade_catalog(module).is_empty():
			var upgrades_tab := LocalUpgradesTab.new()
			data_tabs.add_child(upgrades_tab)
			upgrades_tab.setup(module)
		# Guard against re-selecting the same module (module_clicked can fire
		# twice on one module): a second connect would push an error.
		if not module_viewed.tree_exiting.is_connected(_on_exit_button_pressed):
			module_viewed.tree_exiting.connect(_on_exit_button_pressed)
	_refresh_hp()
	_refresh_env()
	_refresh_alerts()

## Repaints the integrity bar + status line for the viewed module (WI-24). Hidden
## for previews/blueprints and when no module is selected.
func _refresh_hp() -> void:
	if _hp_row == null:
		return
	if module_viewed == null or not module_viewed.is_complete():
		_hp_row.visible = false
		return
	_hp_row.visible = true
	var frac: float = module_viewed.hp_fraction()
	_hp_bar.value = frac
	var parts: Array[String] = []
	if frac < 1.0:
		parts.append("Damaged")
	if module_viewed.has_breakdown():
		parts.append("Broken down")
	var atmo: AtmosphereComponent = module_viewed.get_atmosphere()
	if atmo != null and atmo.is_breached():
		parts.append("Breached")
	_hp_status.text = " / ".join(parts)

## Repaints the Environment section (WI-30) for the viewed module: one friendly
## line per nonzero field, plus a concrete rest-quality line when the module is a
## sleeping pod. Hidden entirely when the module sits in no fields.
func _refresh_env() -> void:
	if _env_section == null:
		return
	# Drop previous lines (children after the title at index 0).
	for i: int in range(_env_section.get_child_count() - 1, 0, -1):
		var line: Node = _env_section.get_child(i)
		_env_section.remove_child(line)
		line.queue_free()
	if module_viewed == null or Global.adjacency_manager == null:
		_env_section.visible = false
		return
	var fields: Dictionary[StringName, float] = Global.adjacency_manager.get_all_fields(module_viewed)
	if fields.is_empty():
		_env_section.visible = false
		return
	_env_section.visible = true
	for effect_id: StringName in fields:
		var label := Label.new()
		var name_text: String = ENV_LABELS.get(effect_id, String(effect_id).capitalize())
		var blurb: String = ENV_BLURBS.get(effect_id, "")
		label.text = "%s: %s — %s" % [name_text, _env_severity(fields[effect_id]), blurb]
		_env_section.add_child(label)
	# Concrete number when the viewed module actually rests crew here.
	var sleep: SleepComponent = module_viewed.get_component_by_type(SleepComponent) as SleepComponent
	if sleep != null:
		var pct: int = int(round((sleep.environment_rest_multiplier() - 1.0) * 100.0))
		if pct != 0:
			var rest_label := Label.new()
			rest_label.text = "Rest quality: %+d%%" % pct
			_env_section.add_child(rest_label)

## Level -> qualitative severity word for the Environment list.
func _env_severity(level: float) -> String:
	if level >= 0.5:
		return "high"
	if level >= 0.2:
		return "moderate"
	return "low"

func _on_fields_changed(module: ModuleBase) -> void:
	if module == module_viewed:
		_refresh_env()

func _on_durability_changed(module: ModuleBase, _amount: float) -> void:
	if module == module_viewed:
		_refresh_hp()

func _on_breach_changed(module: ModuleBase) -> void:
	if module == module_viewed:
		_refresh_hp()

func _on_component_error(component: ComponentBase, error: String) -> void:
	component_alerts.set(component, error)
	_refresh_alerts()
	
func _refresh_alerts() -> void:
	var concat_alerts: String = ""
	for component: ComponentBase in component_alerts:
		var alert: String = component_alerts[component]
		if alert != "":
			if concat_alerts != "":
				concat_alerts += "\n"
			concat_alerts += alert
	if concat_alerts != "":
		alert_label.visible = true
		alert_label.text = concat_alerts
	else:
		alert_label.visible = false
			


func _on_exit_button_pressed() -> void:
	set_module(null)
	visible = false
