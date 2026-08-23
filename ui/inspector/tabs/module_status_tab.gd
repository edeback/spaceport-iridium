class_name ModuleStatusTab
extends VBoxContainer

## The module's live condition, in one tab (WI-64): power, air, and the
## surroundings, stacked as sections instead of spread over three tabs.
##
## This owns no content of its own. Power comes from the generation or draw
## component's own UI, Air from [AtmosphereComponentUI], and the surroundings
## from [ModuleEnvironmentTab] - the same three pages as before, unedited. What
## this adds is the stacking: a heading per section, the section order, and the
## flattening that keeps a page authored as its own [PanelContainer] from drawing
## a box inside the inspector's box.
##
## Which sources fold in here and in what order is [InspectorTabPlan]'s rule, not
## this class's - the plan is where "which tabs" lives and it is the half that
## has a test suite. This is handed a finished list.

## A section that is on its own in the tab prints no heading.
##
## A heading disambiguates one block from the next, and there is nothing to
## disambiguate a lone block from. It matters more than it sounds: a truss and a
## bare corridor carry Environment and nothing else, so the common case for the
## whole station is a single section, and "STATUS ▸ ENVIRONMENT" over one line of
## temperature is a header for a header.
const MIN_SECTIONS_FOR_HEADINGS: int = 2

## `sections` is `[{heading: String, content: Control}, …]` in the order they
## stack. A null or freed `content` is skipped rather than reserving an empty
## heading - a component UI is free to decline to build itself.
func setup(sections: Array[Dictionary]) -> void:
	name = "Status"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UIMetrics.SECTION_GAP)
	var headed: bool = sections.size() >= MIN_SECTIONS_FOR_HEADINGS
	# Consecutive sections that share a heading print it once. Only a module
	# carrying both a generator and a draw hits this, which no vanilla module
	# does - but two "POWER" rules stacked with one line between them would read
	# as a rendering fault rather than as two components, and the alternative
	# (numbering them "Power 2") is the tab-strip noise this whole tab is undoing.
	var previous: String = ""
	for section: Dictionary in sections:
		var content: Control = section.get("content") as Control
		if content == null or not is_instance_valid(content):
			continue
		var heading: String = String(section.get("heading", ""))
		var block := VBoxContainer.new()
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Tight inside a section, [constant UIMetrics.SECTION_GAP] between them -
		# which is what makes the heading read as belonging to the block under it.
		block.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
		add_child(block)
		if headed and not heading.is_empty() and heading != previous:
			block.add_child(SectionLabel.create(heading))
		previous = heading
		InspectorTabSet.flatten_page(content)
		block.add_child(content)
