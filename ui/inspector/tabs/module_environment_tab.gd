class_name ModuleEnvironmentTab
extends VBoxContainer

## The adjacency fields a module sits in, and what they do to it (WI-30, moved
## into the inspector by WI-51).
##
## This was a code-injected section between the old module panel's header and its
## tab strip. It is a tab now for the reason the design gives: the subject block
## is for the numbers you should not have to open a tab for, and a list that can
## be four lines long is not one of them.
##
## Fields are **derived, never saved** (standing invariant), so this reads them
## fresh from [AdjacencyManager] on every repaint rather than caching.

## Friendly names / blurbs for each adjacency effect id. An id with no entry
## renders its own capitalised form - a modded field is worth showing badly
## rather than not at all.
const LABELS: Dictionary[StringName, String] = {
	&"vibration": "Vibration",
	&"greenery": "Greenery",
	&"maintenance": "Maintenance",
	&"purified_air": "Purified air",
}
const BLURBS: Dictionary[StringName, String] = {
	&"vibration": "rest & recreation reduced nearby",
	&"greenery": "calming surroundings; better rest",
	&"maintenance": "servicing lowers breakdown chance",
	&"purified_air": "cleaner air",
}

var _module: ModuleBase = null

func setup(module: ModuleBase) -> void:
	_module = module
	name = "Environment"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	if Global.adjacency_manager != null:
		Global.adjacency_manager.fields_changed.connect(_on_fields_changed)
	if Global.heat_manager != null:
		Global.heat_manager.heat_pass_completed.connect(refresh)
	refresh()

func _on_fields_changed(module: ModuleBase) -> void:
	if module == _module:
		refresh()

func refresh() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if _module == null or not is_instance_valid(_module):
		return
	_add_temperature()
	_add_thermostat()
	if Global.adjacency_manager == null:
		return
	var fields: Dictionary[StringName, float] = Global.adjacency_manager.get_all_fields(_module)
	if fields.is_empty():
		add_child(_line("Nothing nearby is affecting this module.", UIPalette.TEXT_SECONDARY))
		return
	for effect_id: StringName in fields:
		var row: ListRow = ListRow.create()
		row.disabled = true
		row.focus_mode = Control.FOCUS_NONE
		add_child(row)
		var blurb: String = BLURBS.get(effect_id, "")
		row.configure(
			LABELS.get(effect_id, String(effect_id).capitalize()),
			blurb,
			_severity(fields[effect_id]).to_upper(),
			UIPalette.Row.AMBER if effect_id == &"vibration" else UIPalette.Row.LIVE)
	# The concrete number, when the module actually rests crew here - a severity
	# word is a hint, "+8%" is an answer.
	var sleep: SleepComponent = _module.get_component_by_type(SleepComponent) as SleepComponent
	if sleep != null:
		var percent: int = int(round((sleep.environment_rest_multiplier() - 1.0) * 100.0))
		if percent != 0:
			add_child(_line("Rest quality: %+d%%" % percent, UIPalette.sign_color(float(percent))))

## Temperature, above the adjacency rows and rendered differently from them on
## purpose (WI-60).
##
## The fields below print a severity word because their level is a propagation
## strength with no units a player could interpret. Temperature is the opposite
## case - degrees Fahrenheit is a unit everyone already owns - so this prints the
## real number, and the band word beside it is the interpretation rather than a
## substitute for it.
func _add_temperature() -> void:
	if Global.heat_manager == null:
		return
	var component: HeatComponent = Global.heat_manager.get_component(_module)
	if component == null:
		# A blueprint or a teardown site has no thermal body. Saying nothing is
		# right: "0°F" would be a lie about a module that has no temperature.
		return
	var temperature: float = component.temperature_f
	var band: HeatMath.Band = HeatMath.band(temperature, HeatMath.ComfortTuning.new())
	# The throttle rides on the temperature row rather than sitting on a line
	# below it. A module with eight tabs has tall chrome, and WI-58's rule is that
	# the page region absorbs the shortfall by scrolling - so on exactly the
	# modules that throttle (forges, refineries: the ones with the most tabs) a
	# separate line lands below the fold, which a screenshot caught. The first row
	# is the only place always visible, so the consequence goes in it.
	var description: String = HeatMath.band_label(band).to_lower()
	var throttle: float = component.throttle_penalty()
	if throttle > 0.0:
		description += " · work rate %+d%%" % int(round(-throttle * 100.0))
	var row: ListRow = ListRow.create()
	row.disabled = true
	row.focus_mode = Control.FOCUS_NONE
	add_child(row)
	# Amber only for the two bands that are actively harming crew - the same
	# "falling vital" category the budget reserves it for, and strictly more
	# urgent than the vibration row beside it that already spends one.
	row.configure("Temperature", description, HeatMath.format_temperature(temperature),
		UIPalette.Row.AMBER if band == HeatMath.Band.FREEZING or band == HeatMath.Band.SCORCHING
			else UIPalette.Row.LIVE)
	# Rest quality is deliberately NOT printed here: it is already printed once at
	# the bottom of this tab as the COMBINED environment multiplier, and
	# temperature is now part of that number. Saying it twice in two framings
	# reads as two separate effects.

## The setpoint on a module that has a thermostat - the Heater, and nothing else
## today (WI-67).
##
## A [Stepper] rather than a readout because it is the one number on this tab the
## player owns, and it commits on release rather than on every step, which is what
## keeps a drag from writing the setpoint forty times. Hidden entirely on the
## ninety-odd modules with no thermostat: a disabled control on every module would
## be ninety wrong affordances to save one conditional.
func _add_thermostat() -> void:
	var emitter: HeatEmitterComponent = _module.get_component_by_type(HeatEmitterComponent) as HeatEmitterComponent
	if emitter == null or not emitter.thermostat_enabled:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	add_child(row)
	var label := Label.new()
	label.text = "Heat to"
	label.theme_type_variation = UIType.META_LINE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var stepper: Stepper = Stepper.create()
	row.add_child(stepper)
	stepper.configure(int(round(emitter.target_temperature_f)),
		int(HeatEmitterComponent.TARGET_MIN_F), int(HeatEmitterComponent.TARGET_MAX_F),
		HeatEmitterComponent.TARGET_STEP_F, false)
	stepper.value_changed.connect(func(value: int) -> void:
		emitter.set_target_temperature(float(value)))
	# Why an aimed heater can be sitting idle. Without this line a player who sets
	# 68 and watches the heat output read zero has no way to tell "satisfied" from
	# "broken", which is the same complaint TEXT_DISABLED exists to answer.
	if emitter.thermostat_holding():
		add_child(_line("At temperature — the heater is idle.", UIPalette.TEXT_SECONDARY))

## Level -> qualitative severity word. The underlying float is a propagation
## strength with no units the player could interpret, so it is never printed.
func _severity(level: float) -> String:
	if level >= 0.5:
		return "high"
	if level >= 0.2:
		return "moderate"
	return "low"

func _line(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = UIType.META_LINE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	return label
