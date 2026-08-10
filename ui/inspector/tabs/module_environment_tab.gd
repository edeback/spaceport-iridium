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
	refresh()

func _on_fields_changed(module: ModuleBase) -> void:
	if module == _module:
		refresh()

func refresh() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if _module == null or not is_instance_valid(_module) or Global.adjacency_manager == null:
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
