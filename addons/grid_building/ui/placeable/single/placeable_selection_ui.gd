## Unified UI component for selecting placeable objects and placeable sequences to build.
##
## Provides a tabbed, grid-based interface for selecting placeables and placeable sequences to place in the world.
## Supports folder-based asset loading with [GBAssetResolver] for automatic discovery of content and category tags.
## Integrates with [BuildingSystem] to initiate placement mode when items are selected.
##
## [b]Key Features:[/b]
## [ul]
## - Mixed content grids supporting both individual placeables and sequences
## - Configurable sizing for consistent template height and icon dimensions
## - Variant cycling for sequences through enhanced [PlaceableListEntry] components
## - Automatic asset loading from configured folders
## - Category-based organization with tabs
## [/ul]
##
## [b]Usage:[/b]
## [codeblock]
## var selection_ui = PlaceableSelectionUI.new()
## selection_ui.placeables_folder = "res://my_placeables"
## selection_ui.category_tags_folder = "res://my_categories"
## selection_ui.fixed_template_height = 48
## selection_ui.fixed_icon_size = 40
## [/codeblock]
class_name PlaceableSelectionUI
extends Control

## Emitted when the UI validation state changes.[br]
## [param is_valid] True if the UI is properly configured and ready for use.
signal valid_changed(is_valid : bool)

## System mode state for tracking build mode changes.[br]
## Automatically connects to mode changes to show/hide the UI appropriately.
var _mode_state : ModeState :
	set(value):
		if is_instance_valid(_mode_state):
			_mode_state.mode_changed.disconnect(_on_mode_changed)
			
		_mode_state = value
		
		if is_instance_valid(_mode_state):
			_mode_state.mode_changed.connect(_on_mode_changed)

@export_group("Asset Loading")
## Path to folder containing category tag resources.[br]
## Tags found here are automatically loaded and added to [member category_tags].
@export_dir var category_tags_folder : String = ""

## Path to folder containing placeable resources.[br]
## Placeables found here are automatically loaded and added to [member placeables].
@export_dir var placeables_folder : String = ""

## Path to folder containing placeable sequence resources.[br]
## Sequences found here are automatically loaded and added to [member sequences].
@export_dir var sequences_folder : String = ""

## Category tags to include alongside folder-loaded ones.[br]
## These tags are combined with tags loaded from [member category_tags_folder].
@export var category_tags : Array[CategoricalTag] = []

## Individual placeables to include alongside folder-loaded ones.[br]
## These are displayed in grids alongside sequences. Combined with placeables from [member placeables_folder].
@export var placeables : Array[Placeable] = []

## Placeable sequences to include alongside folder-loaded ones.[br]
## Sequences allow variant cycling within a single grid slot. Combined with sequences from [member sequences_folder].
@export var sequences : Array[PlaceableSequence] = []

@export_group("Display Settings")
## Number of columns for the grid layout.[br]
## Default: 1 (single column list layout).
@export_range(1, 10, 1) var grid_columns : int = 1

## Template scene for individual placeable entries.[br]
## Should be a [PlaceableView] that displays icon and name.
@export var placeable_entry_template : PackedScene

## Template scene for sequence entries with variant cycling.[br]
## Should be a [PlaceableListEntry] that supports cycling through sequence variants.
@export var sequence_entry_template : PackedScene

@export_group("Sizing Settings")
## Fixed height for all templates to prevent resizing when cycling through sequence variants.[br][br]
## When set to a positive value, enforces consistent height for all template entries.[br]
## When set to 0, disables PlaceableSelectionUI-level height enforcement and allows templates to size naturally.[br]
## Note: Individual PlaceableView instances may still enforce their own height via their fixed_view_height property.[br]
## Default: 48 pixels for consistent template sizing.
@export var fixed_template_height : int = 48

## Fixed icon size for all placeable view icons to ensure consistent icon dimensions.[br][br]
## When set to a positive value, enforces both width and height for all icon TextureRects in PlaceableView instances.[br]
## When set to 0, icon sizing is not enforced and will use template defaults.[br]
## Default: 40 pixels for standard icon sizing.
@export var fixed_icon_size : int = 40
			
## Whether category tab titles should be visible for manual category selection.[br]
## When false, tabs are hidden and only grid content is shown.
@export var show_category_tab_names : bool = true

## Whether to hide the selection UI when an item is selected.[br]
## When true, the UI automatically hides after the user selects a placeable or sequence.
@export var hide_ui_on_selection : bool = false

@export_group("Internal Nodes")
## Root control node for showing and hiding the entire UI.
@export var ui_root : Control

## Tab container that handles category-based organization.[br]
## Each tab represents a category tag and contains a grid of matching placeables/sequences.
@export var tab_container : TabContainer

## Context providing access to building system and other grid building systems.
var _systems_context : GBSystemsContext
## Shared logic for placeable selection behavior.
var _logic := PlaceableSelectionLogic.new()

func _ready():
	_validate_basic_components()
	_load_assets()
	_validate_required_templates()  # Validate templates after we know what content we have
	
	hidden.connect(_on_hidden)
	clear()
	_setup_tabs()
	
## Called by GBChildInjector to resolve dependencies on the UI.[br][br]
## [code]p_container[/code]: [i]GBCompositionContainer[/i] - Container with system dependencies and configuration
func resolve_gb_dependencies(p_container : GBCompositionContainer) -> void:
	_systems_context = p_container.get_systems_context()
	_mode_state = p_container.get_mode_state()

## Load assets using GBAssetResolver for both placeables and sequences
func _load_assets() -> void:
	# Load category tags from folder and combine with exported ones
	var folder_category_tags = GBAssetResolver.load_category_tags(category_tags_folder, [])
	category_tags.append_array(folder_category_tags)
	
	# Load both content types simultaneously
	var folder_placeables = GBAssetResolver.load_placeables(placeables_folder, [])
	placeables.append_array(folder_placeables)
	
	var folder_sequences = GBAssetResolver.load_placeable_sequences(sequences_folder, [])
	sequences.append_array(folder_sequences)

## Rebuild the UI after changing content type or assets at runtime
func rebuild() -> void:
	_load_assets()
	_validate_required_templates()  # Re-validate templates after reloading assets
	clear()
	_setup_tabs()

# Clear existing tabs
func clear():
	for tab in tab_container.get_children():
		tab.queue_free()

## Generate tabs for each category and populate each tab with content in unified grid layout
func _setup_tabs():
	# One tab per category
	var actual_tab_index: int = 0  # Track actual tab index (may differ from tag_index if some categories are empty)
	
	for tag_index in range(0, category_tags.size(), 1):
		var tag = category_tags[tag_index]
		
		# Get both content types with matching tags
		var matched_placeables : Array[Placeable] = _get_placeables_with_tag(tag)
		var matched_sequences : Array[PlaceableSequence] = _get_sequences_with_tag(tag)
		
		# Create mixed content grid if any content found
		var unified_grid : GridContainer
		if matched_placeables.size() > 0 or matched_sequences.size() > 0:
			unified_grid = _create_mixed_content_grid(matched_placeables, matched_sequences)
		
		if unified_grid:
			unified_grid.name = tag.display_name
			tab_container.add_child(unified_grid)
			tab_container.set_tab_icon(actual_tab_index, tag.icon)
			actual_tab_index += 1  # Only increment when we actually created a tab
		
		if not show_category_tab_names:
			# Hide tab names
			tab_container.set_tab_title(tag_index, "")
		
# Returns all placeables that have the matching tag resource
func _get_placeables_with_tag(tag : Resource) -> Array[Placeable]:
	var matched : Array[Placeable] = []
	
	for placeable in placeables:
		if placeable == null:
			push_warning("Null placeable in selection ui arrays. Skipping invalid entry.")
			continue
		
		for p_tag in placeable.tags:
			if p_tag == tag:
				matched.append(placeable)
	
	return matched

# Returns all sequences that have the matching tag resource
func _get_sequences_with_tag(tag : Resource) -> Array[PlaceableSequence]:
	var matched : Array[PlaceableSequence] = []
	
	for sequence in sequences:
		if sequence == null:
			push_error("Null sequence in selection ui arrays. Reassign or remove it.")
			continue
		
		# Check if ANY contained placeable has the tag
		var sequence_matches := false
		for placeable in sequence.placeables:
			if placeable and placeable.tags.has(tag):
				sequence_matches = true
				break
		if sequence_matches:
			matched.append(sequence)
	
	return matched
		
## Creates a mixed content grid containing both placeables and sequences
func _create_mixed_content_grid(placeables_for_tag : Array[Placeable], sequences_for_tag : Array[PlaceableSequence]) -> GridContainer:
	# Create grid container programmatically
	var grid := GridContainer.new()
	grid.columns = grid_columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	
	# Add individual placeables first
	for placeable in placeables_for_tag:
		# Only check template if we actually have placeables to add
		assert(placeable_entry_template != null, "PlaceableSelectionUI: placeable_entry_template is required but not assigned")
		var entry_node : Node = placeable_entry_template.instantiate()
		var entry : PlaceableView = entry_node as PlaceableView
		if entry:
			entry.placeable = placeable
			entry.placeable_selected.connect(_on_placeable_selected)
			# Apply fixed icon size if specified
			if fixed_icon_size > 0:
				entry.fixed_icon_size = fixed_icon_size
			# Enforce fixed height to prevent cycling resize
			_enforce_template_height(entry)
		grid.add_child(entry_node)
	
	# Add sequences after placeables
	for sequence in sequences_for_tag:
		# Only check template if we actually have sequences to add
		assert(sequence_entry_template != null, "PlaceableSelectionUI: sequence_entry_template is required but not assigned")
		var entry_node : Node = sequence_entry_template.instantiate()
		var entry : PlaceableListEntry = entry_node as PlaceableListEntry
		if entry:
			entry.sequence = sequence
			entry.selected.connect(_on_sequence_entry_selected)
			entry.variant_changed.connect(_on_sequence_variant_changed)
			# Enforce fixed height to prevent cycling resize
			_enforce_template_height(entry)
		grid.add_child(entry_node)
	
	return grid

func _on_placeable_selected(p_placeable : Placeable):
	_get_building_system().enter_build_mode(p_placeable)
	
	if hide_ui_on_selection:
		ui_root.hide()

func _on_sequence_entry_selected(entry : PlaceableListEntry):
	var active_placeable : Placeable = entry.get_active_placeable()
	if active_placeable:
		_get_building_system().enter_build_mode(active_placeable)
		
		if hide_ui_on_selection:
			ui_root.hide()

func _on_sequence_variant_changed(entry : PlaceableListEntry, variant_index : int):
	# Optional: Handle variant change events for additional functionality
	pass

## Adds placeable options to the UI and updates the corresponding visuals.[br][br]
## [code]new_placeables[/code]: [i]Array[Placeable][/i] - Array of new placeable resources to add to the UI
func add_placeables(new_placeables : Array[Placeable]):
	for new_p in new_placeables:
		if(not placeables.has(new_p)):
			# Add it since it's not already in the UI
			placeables.append(new_p)
			
			# Add it to each matching category
			for i in range(0, category_tags.size(), 1):
				if(new_p.tags.has(category_tags[i])):
					var cat_item_list : ItemList = tab_container.get_child(i) as ItemList
					cat_item_list.add_item(new_p.display_name, new_p.texture)
			
	
## Removes placeable options from the UI and updates the corresponding visuals.[br][br]
## [code]rem_placeables[/code]: [i]Array[Placeable][/i] - Array of placeable resources to remove from the UI
func remove_placeables(rem_placeables : Array[Placeable]):
	for rem_p in rem_placeables:
		if(placeables.has(rem_p)):
			# Remove matching from the placeables array
			placeables.erase(rem_p)
			
			# Remove it from each matching category
			for i in range(0, category_tags.size(), 1):
				if(rem_p.tags.has(category_tags[i])):
					var cat_item_list : ItemList = tab_container.get_child(i) as ItemList
					
					for list_i in range(0, cat_item_list.item_count, 1):
						if(cat_item_list.get_item_text(list_i) == rem_p.display_name && cat_item_list.get_item_icon(list_i) == rem_p.texture):
							# Match so remove
							cat_item_list.remove_item(list_i)
							
## Run setup checks on the UI to ensure proper setup.
## Returns validation issues found during setup checks.[br][br]
## [code]return[/code]: [i]Array[String][/i] - List of validation issues (empty if valid)
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	issues.append_array(GBValidation.check_not_null(self, ["_systems_context"]))
	issues.append_array(GBValidation.check_not_null(self, ["tab_container", "ui_root"]))
	
	# Smart template validation - only check templates we actually need
	var has_placeables = placeables.size() > 0
	var has_sequences = sequences.size() > 0
	
	if has_placeables and placeable_entry_template == null:
		issues.append("placeable_entry_template is required when placeables are present but not assigned")
	
	if has_sequences and sequence_entry_template == null:
		issues.append("sequence_entry_template is required when sequences are present but not assigned")
	
	# Make sure each placeable has a tag in the category tags
	for placeable in placeables:
		var at_least_one_category = false
		
		for category in placeable.tags:
			if category_tags.has(category):
				at_least_one_category = true
				
		if not at_least_one_category:
			issues.append("Placeable " + placeable.display_name + " has no matching categories with the Placeable Selection UI and will not be selectable.")
	
	return issues

func _on_mode_changed(p_mode : GBEnums.Mode):
	_logic.handle_mode_changed(p_mode, ui_root)

## When hidden, if in build mode, automatically switch to off mode
func _on_hidden():
	_logic.handle_ui_hidden(ui_root)

## Get the current building system from systems context
## Validates basic required components are properly assigned
func _validate_basic_components() -> void:
	assert(tab_container != null, "PlaceableSelectionUI: tab_container node reference is required but not assigned")
	assert(ui_root != null, "PlaceableSelectionUI: ui_root node reference is required but not assigned")

## Validates only the templates that are needed based on loaded content
func _validate_required_templates() -> void:
	var has_placeables = placeables.size() > 0
	var has_sequences = sequences.size() > 0
	
	# Only validate placeable template if we have placeables
	if has_placeables and placeable_entry_template == null:
		push_error("PlaceableSelectionUI: placeable_entry_template is required when placeables are present but not assigned")
	
	# Only validate sequence template if we have sequences
	if has_sequences and sequence_entry_template == null:
		push_error("PlaceableSelectionUI: sequence_entry_template is required when sequences are present but not assigned")

func _get_building_system() -> BuildingSystem:
	return _systems_context.get_building_system() if _systems_context else null

## Enforces fixed height for consistent template sizing when fixed_template_height > 0.[br]
## When fixed_template_height is 0, height enforcement is disabled at the PlaceableSelectionUI level.
func _enforce_template_height(template_entry: Control) -> void:
	if template_entry and fixed_template_height > 0:
		template_entry.custom_minimum_size.y = fixed_template_height
		template_entry.size.y = fixed_template_height
		template_entry.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		# Also constrain any TextureRect children to prevent icon expansion
		_constrain_template_icons(template_entry)
	else:
		# When height enforcement is disabled, reset to natural sizing
		template_entry.custom_minimum_size.y = 0
		template_entry.size_flags_vertical = Control.SIZE_EXPAND_FILL

## Constrains icon/image elements within templates to prevent height expansion
func _constrain_template_icons(template_entry: Control) -> void:
	# Find and constrain TextureRect nodes (used for icons)
	var texture_rects = _find_nodes_by_type(template_entry, "TextureRect")
	for texture_rect in texture_rects:
		var tex_rect = texture_rect as TextureRect
		if tex_rect and (tex_rect.name == "Icon" or "icon" in tex_rect.name.to_lower()):
			# Ensure icons don't expand beyond their minimum size
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			# Constrain the icon height
			if tex_rect.custom_minimum_size.y > fixed_template_height - 8: # Leave some padding
				tex_rect.custom_minimum_size.y = fixed_template_height - 8

## Recursively finds all nodes of a specific type within a parent node
func _find_nodes_by_type(parent: Node, type_name: String) -> Array[Node]:
	var found_nodes: Array[Node] = []
	
	if parent.get_class() == type_name:
		found_nodes.append(parent)
	
	for child in parent.get_children():
		found_nodes.append_array(_find_nodes_by_type(child, type_name))
	
	return found_nodes
