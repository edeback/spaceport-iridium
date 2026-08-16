class_name TraitChips
extends RefCounted

## One hoverable label per trait, each carrying its own `.tres` description as a
## tooltip (WI-59). A trait name is jargon until you know what it does, and both
## places a player reads a candidate's traits - the New Game setup screen and the
## in-game recruitment window - owe them the explanation.
##
## Styling is passed in, never named here: the two callers sit on opposite sides
## of the console design system (the recruitment window takes a [UIType]
## variation, the menus hand-type a size because `ui/menus/` predates the system
## and is exempt), and a shared widget that picked one would force the other to
## break its own layer's rule. What IS shared is the part that can drift: one
## label per trait, the separator, the tooltip, and the mouse filter.

## Builds the row. `traits` must be non-empty - the two callers disagree about
## what "no traits" should read as (the setup screen says so, the recruitment
## window omits the line), so that decision stays with them.
##
## `type_variation` and `font_size` are alternatives: pass a variation on the
## console, a size in the menus, neither if the caller styles the labels itself.
static func build(traits: Array[TraitData], color: Color,
		type_variation: StringName = &"", font_size: int = 0) -> HFlowContainer:
	# Flow rather than a plain HBox: two long trait names on a narrow card have
	# to be free to wrap onto a second line instead of widening their container.
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 0)
	row.add_theme_constant_override("v_separation", 0)
	for index: int in traits.size():
		var trait_data: TraitData = traits[index]
		var last: bool = index == traits.size() - 1
		var label := Label.new()
		# The separator rides on the label so the hover target is exactly the
		# trait's own name plus its comma, never the gap between two of them.
		label.text = trait_data.display_name + ("" if last else ",")
		if type_variation != &"":
			label.theme_type_variation = type_variation
		if font_size > 0:
			label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", color)
		# A Label defaults to MOUSE_FILTER_IGNORE, which means it never receives
		# the hover and the tooltip below is silently dead. Nothing about the
		# code looks wrong when this is missing - only a real hover shows it.
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.tooltip_text = trait_data.description if trait_data.description != "" else trait_data.display_name
		row.add_child(label)
		if not last:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(4, 0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(gap)
	return row
