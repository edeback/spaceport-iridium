## Tile indicator showing placement validity based on rules and collisions.
##
## Displays visual feedback for tile validity during building preview by running all assigned TileCheckRules and updating its visuals accordingly.
## Used by IndicatorManager and PlacementValidator as part of the validation pipeline. [br][br]
##
## Usage: It is recommended to set the TargetPosition to Vector2(0,0) so that the indicator's position aligns with the tile being evaluated. [br][br]
##
## [b]IMPORTANT FOR ISOMETRIC GAMES:[/b] This ShapeCast2D should use [ConvexPolygonShape2D] with explicit
## diamond points, NOT [RectangleShape2D] with skew transformation. When the parent [ManipulationParent]
## rotates (e.g., 90° during manipulation), skewed rectangles create visual distortion due to compound
## transforms (skew + rotation). Polygon shapes rotate uniformly without perspective changes. [br][br]
##
## For detailed explanation and examples, see: [code]docs/v5-0-0/guides/isometric_implementation.mdx[/code][br][br]
##
## See [code]project-architecture.md[/code] for system architecture and building flow documentation.
class_name RuleCheckIndicator
extends ShapeCast2D

## Emitted when validity status changes.
signal valid_changed(is_valid : bool)

const LogLevel = GBDebugSettings.LogLevel


## Sprite showing tile validity status.
@export var validity_sprite: Sprite2D = null

@export_group("Settings")
## Whether to show the indicator visual sprites for players or not.
@export var show_indicators : bool = true :
	set(value):
		if _show_indicators == value:
			return
		_show_indicators = value
		if _show_indicators:
			propagate_call("show")
		else:
			propagate_call("hide")
		_shown_sprite = null
	get:
		return _show_indicators
var _show_indicators : bool = true

## Default display settings for when the rule check indicator is marked valid. [br]
## If unset, will default at runtime. However you should define a valid IndicatorVisualSettings for production games
@export var valid_settings: IndicatorVisualSettings

## Default display settings for when the rule check indicator is marked invalid. [br]
## If unset, will default at runtime. However you should define a valid IndicatorVisualSettings for production games
@export var invalid_settings: IndicatorVisualSettings

## Controls whether extra collision information should be drawn to the viewport for debug
## purposes and contact information printed in output
var _logger : GBLogger

# Cache whether debug drawing should be active to avoid checking each frame
var _debug_draw_enabled: bool = false
var _last_invalid_rule_count: int = -1
var _last_logged_valid: int = -1
var _post_ready_visuals_applied: bool = false

## The rules to validate for whether this tile is valid for placement or not
## All rules must validate true to be valid. Otherwise, failed status will be shown
@export var rules : Array[TileCheckRule] = [] :
	set(value):
		if _rules == value:
			return
		_rules = value
	get:
		return _rules
var _rules : Array[TileCheckRule] = []

var _current_display_settings : IndicatorVisualSettings = null
var current_display_settings : IndicatorVisualSettings = null :
	set(value):
		if value == _current_display_settings:
			return
		_current_display_settings = value
		_update_visuals(_current_display_settings)
	get:
		return _current_display_settings

## The currently showing sprite
@onready var _shown_sprite : Sprite2D = null

## Whether the rules were validated for the area under the rule check indicator in the last test
@export var valid : bool = false :
	set(value):
		if _valid == value:
			return
		_valid = value
		valid_changed.emit(_valid)
	get:
		return _valid
		
var _valid : bool = false

func _init(p_rules : Array[TileCheckRule] = []):
	# Set target_position to zero for proper tile alignment in tests
	target_position = Vector2.ZERO
	
	if valid_settings == null:
		valid_settings = IndicatorVisualSettings.get_valid_default()
	
	if invalid_settings == null:
		invalid_settings = IndicatorVisualSettings.get_invalid_default()
	
	for rule in p_rules:
		add_rule(rule)
		
	valid_changed.connect(_on_valid_changed)
	
	
	
func _ready():
	_update_debug_cached_state()
	assert(shape != null, "RuleCheckIndicator %s requires a valid Shape2D assigned to its shape property." % self.name)
	
	# Initialize validity state immediately after _ready() to ensure correct initial state
	# This prevents timing issues where indicator remains at default valid=false 
	# when it should be valid=true (no rules) or properly evaluated (with rules)

	# Ensure default visual settings exist so validity_sprite can be assigned immediately
	if valid_settings == null:
		valid_settings = IndicatorVisualSettings.get_valid_default()
	if invalid_settings == null:
		invalid_settings = IndicatorVisualSettings.get_invalid_default()

	# If a validity_sprite exists, apply the initial visuals now so the sprite has a texture early
	_update_current_display_settings([], valid)

	update_validity_state()

## Per-frame rule processing; indicators always re-evaluate rules every physics frame.
## This keeps visual feedback immediately responsive to dynamic collision or rule state changes.
func _physics_process(_delta: float) -> void:
	update_validity_state()

## Resolve dependencies for the indicator
func resolve_gb_dependencies(p_container : GBCompositionContainer) -> void:
	if p_container == null:
		# Do not crash when tests pass a null container - leave _logger null and let
		# validate_runtime()/get_runtime_issues report the missing logger.
		_logger = null
		return

	_logger = p_container.get_logger()
	_update_debug_cached_state()
	if _debug_draw_enabled:
		queue_redraw()
	# Apply visuals in case tests set textures/sprites after _ready
	# Ensure defaults are present when dependencies are resolved (tests may instantiate indicators and
	# immediately call resolve_gb_dependencies without filling exported resources)
	if valid_settings == null:
		valid_settings = IndicatorVisualSettings.get_valid_default()
	if invalid_settings == null:
		invalid_settings = IndicatorVisualSettings.get_invalid_default()
	_update_current_display_settings([], valid)

## Returns the active tile check rules assigned to this indicator.
func get_rules() -> Array[TileCheckRule]:
	return rules.duplicate()

## Adds rule to indicator and self to indicators array on the rule for all indicator validation checks.[br][br]
## [code]p_rule[/code]: [i]TileCheckRule[/i] - Rule to add to this indicator
func add_rule(p_rule : TileCheckRule):
	rules.append(p_rule)
	p_rule.indicators.append(self)

	# Defer validation until the indicator is inside the tree to avoid collision checks on non-parented nodes
	if is_inside_tree():
		update_validity_state()
	else:
		# Only connect if not already connected to avoid duplicate connection errors
		if not tree_entered.is_connected(_on_tree_entered_validate):
			tree_entered.connect(_on_tree_entered_validate)

func _on_tree_entered_validate():
	update_validity_state()
	
## Gets the tile position that the indicator is currently positioned over.[br][br]
## [code]p_map[/code]: [i]TileMapLayer[/i] - TileMapLayer to convert global position to tile coordinates
func get_tile_position(p_map : TileMapLayer) -> Vector2i:
	if not p_map:
		_logger.log_error( "TileMapLayer is null. Cannot get tile position.")
		return Vector2i.ZERO
		
	var map_local_pos : Vector2 = p_map.to_local(global_position)
	var map_tile : Vector2i = p_map.local_to_map(map_local_pos)
	return map_tile

## Clears reference to self from all rule indicator arrays
func clear():
	for rule in rules:
		if rule != null and is_instance_valid(rule):
			# Safely remove this indicator from the rule's indicators array
			if rule.indicators.has(self):
				rule.indicators.erase(self)
		else:
			# Log warning for invalid rules
			if _logger:
				_logger.log_warning( "Attempted to clear invalid rule reference")
	
	# Clear the rules array
	rules.clear()
	# When rules are cleared the indicator should default to valid again
	valid = true
	_update_current_display_settings([], true)

## Tests each of the TileCheckRules against the indicator.
## Returns all failing rules.[br][br]
## [code]p_rules[/code]: [i]Array[TileCheckRule][/i] - Array of rules to validate against this indicator
func validate_rules(p_rules : Array[TileCheckRule]) -> Array[TileCheckRule]:
	# Build a failing_checker callable that captures this indicator but passes only the rule to the helper
	var failing_checker: Callable = func(rule: TileCheckRule) -> Array:
		return rule.get_failing_indicators([self])

	return RuleCheckIndicatorLogic.validate_rules_from_rules_and_checker(p_rules, failing_checker)

## Updates the visual display of the indicator based on display settings.
## Sets texture and modulate color from the provided settings.[br][br]
## [code]p_display_settings[/code]: [i]IndicatorVisualSettings[/i] - Visual settings to apply to the indicator
func _indicator_debug_enabled() -> bool:
	# Determine whether debug drawing should be enabled.
	# Only enable draw when a GBDebugSettings resource is available and the
	# explicit per-indicator toggle is set. In test environments where
	# debug settings aren't injected, we intentionally skip debug drawing.
	if _logger == null:
		return false

	var settings = _logger.get_debug_settings() if _logger.has_method("get_debug_settings") else null
	if settings == null:
		return false

	# Honor the explicit debug draw toggle on the settings resource
	return bool(settings.draw_rule_check_indicator_debug)

## Returns whether verbose indicator logs should be printed.
## This is stricter than _indicator_debug_enabled: requires explicit toggle or env var.
func _indicator_log_enabled() -> bool:
	if _logger == null:
		return OS.get_environment("GB_INDICATOR_DEBUG") == "1"
	var settings = _logger.get_debug_settings() if _logger else null
	if settings == null:
		return OS.get_environment("GB_INDICATOR_DEBUG") == "1"
	return settings.draw_rule_check_indicator_debug or OS.get_environment("GB_INDICATOR_DEBUG") == "1"

func _update_visuals(p_display_settings : IndicatorVisualSettings) -> Sprite2D:
	# Fail-fast for missing display settings only; if there's no sprite, just skip visuals
	assert(p_display_settings != null, "RuleCheckIndicator: _update_visuals called with null display settings - expected valid_settings or invalid_settings to be assigned")
	if not validity_sprite:
		if _indicator_debug_enabled():
			_logger.log_debug("_update_visuals: validity_sprite is null - skipping visual assignment")
		return

	# Debug logging for visual updates
	if _indicator_debug_enabled():
		var texture_name = p_display_settings.texture.resource_name if p_display_settings.texture else "null"
		_logger.log_debug( "_update_visuals: updating sprite with texture=%s, modulate=%s" % [
			texture_name,
			str(p_display_settings.modulate)
		])

	# Ensure there is always a texture to assign; prefer the provided one, otherwise fall back
	if p_display_settings.texture != null:
		validity_sprite.texture = p_display_settings.texture
	else:
		# If invalid_settings is missing, create defaults rather than silently returning
		if invalid_settings == null:
			invalid_settings = IndicatorVisualSettings.get_invalid_default()
		validity_sprite.texture = invalid_settings.texture

	validity_sprite.modulate = p_display_settings.modulate
	return validity_sprite

## Change the display settings of the indicator's sprite
## based on validity and highest rule visual priority
func _update_current_display_settings(p_display_rules : Array[TileCheckRule], p_is_valid = null):
	# Use passed validity state if provided, otherwise fall back to class property
	var is_valid = p_is_valid if p_is_valid != null else valid
	
	# Debug logging for display settings updates
	if _indicator_debug_enabled():
		_logger.log_debug( "_update_current_display_settings: is_valid=%s, rules_count=%d" % [
			str(is_valid), 
			p_display_rules.size()
		])
	
	if _indicator_debug_enabled():
		_logger.log_debug( "_update_current_display_settings: resolved display settings via helper; is_valid=%s" % [str(is_valid)])

	# Delegate display choice to the pure helper which accepts small pieces of data
	current_display_settings = RuleCheckIndicatorLogic.choose_display_settings(p_display_rules, is_valid, valid_settings, invalid_settings)

## Finds the rule with highest visual priority among failing rules.
## Returns the rule with the highest visual priority that has fail_visual_settings defined.[br][br]
## [code]p_rules[/code]: [i]Array[TileCheckRule][/i] - Array of rules to check for highest priority
func _find_highest_rule_with_visual_settings(p_rules : Array[TileCheckRule]) -> TileCheckRule:
	var selected_rule : TileCheckRule = null
	var selected_priority = null
	
	# Find the highest priority failing rule with fail visual settings
	for rule in p_rules:
		if rule.fail_visual_settings == null:
			continue
					
		if(selected_priority == null || rule.visual_priority > selected_priority):
			selected_rule = rule
			selected_priority = rule.visual_priority
			
	return selected_rule

## Draws debug visuals for collision contact points only.
func _draw():
	# Fast exit if debug draw is disabled
	if !_debug_draw_enabled:
		return

	# Only show debug visuals when there are actual collisions
	if collision_result.is_empty():
		return

	# Visual constants for debug drawing - scale to shape size
	var shape_bounds := shape.get_rect() if shape else Rect2(0, 0, 16, 16)
	var tile_size := min(shape_bounds.size.x, shape_bounds.size.y)
	# Read tuning values from debug settings when available, otherwise fall back to constants
	var collision_min_radius := _debug_setting_float_or(2.0, "indicator_collision_point_min_radius")
	var collision_scale := _debug_setting_float_or(0.15, "indicator_collision_point_scale")
	var connection_min_width := _debug_setting_float_or(1.0, "indicator_connection_line_min_width")
	var connection_scale := _debug_setting_float_or(0.05, "indicator_connection_line_scale")
	var collision_point_radius := max(collision_min_radius, tile_size * collision_scale)
	var connection_line_width := max(connection_min_width, tile_size * connection_scale)

	# Draw each collision contact point with connections
	for i in range(collision_result.size()):
		var contact = collision_result[i]
		var local_contact_point: Vector2 = to_local(contact.point)

		# Colors can be tuned via debug settings; fall back to constants
		var connection_color := _debug_setting_color_or(Color.ORANGE, "indicator_connection_line_color")
		var collision_color := _debug_setting_color_or(Color.RED, "indicator_collision_point_color")
		var outline_color := _debug_setting_color_or(Color.WHITE, "indicator_outline_color")

		# Draw connection line from indicator center to collision point
		draw_line(Vector2.ZERO, local_contact_point, connection_color, connection_line_width)

		# Draw collision point with outline for visibility
		draw_circle(local_contact_point, collision_point_radius + 1, outline_color)
		draw_circle(local_contact_point, collision_point_radius, collision_color)

		# Draw collision index number for multiple collisions
		if collision_result.size() > 1:
			var marker_radius := max(1.0, collision_point_radius * 0.3)  # Scale marker to collision point
			var text_offset := Vector2(-collision_point_radius * 0.5, collision_point_radius * 0.5)
			draw_circle(local_contact_point + text_offset, marker_radius, Color.WHITE)

## Get current state information for debugging
func get_debug_info() -> Dictionary:
	return {
		"valid": valid,
		"rules_count": rules.size(),
		"validity_sprite": "null" if not validity_sprite else validity_sprite.name,
		"current_display_settings": "null" if not current_display_settings else current_display_settings.resource_name,
		"valid_settings": "null" if not valid_settings else valid_settings.resource_name,
		"invalid_settings": "null" if not invalid_settings else invalid_settings.resource_name
	}

func validate_runtime() -> bool:
	# Avoid hard assertion - tests may construct indicators without a logger.
	if _logger == null:
		# If logger is not resolved, report the issue but do not crash.
		var issues = get_runtime_issues()
		return issues.is_empty()

	trace_runtime_if_enabled()
	var issues = get_runtime_issues()
	_logger.log_issues(issues)
	return issues.is_empty()

## Highly verbose logging of the RuleCheckIndicator during runtime. Will only process if GBLogger is set to Trace verbosity (very high!)
func trace_runtime_if_enabled() -> void:
	# Debug logging for setup (logger decides verbosity). Skip if logger missing.
	if _logger == null:
		return
	if not _logger.has_method("is_trace_enabled"):
		return
	if _logger.is_trace_enabled():
		_logger.log_trace("_ready: validity_sprite=%s, valid_settings=%s, invalid_settings=%s" % [
			"null" if not validity_sprite else validity_sprite.name,
			"null" if not valid_settings else valid_settings.resource_name,
			"null" if not invalid_settings else invalid_settings.resource_name
		])

## Gets issues with the indicator in the scene
## Runtime-time validations: checks useful during gameplay/runtime
## [return] Array[String] - Returns array of issues found
func get_runtime_issues() -> Array[String]:
	# Start with editor-time issues so runtime includes all authoring checks
	var issues : Array[String] = get_editor_issues()

	# Runtime-only validations
	if rules.size() <= 0:
		# Avoid duplicating the shape check (editor already adds it)
		issues.append("%s has no rules to evaluate" % self)

	# Logger is expected to be injected before runtime validation
	if _logger == null:
		issues.append("%s: Logger not resolved. Call resolve_gb_dependencies(container) before using in scene/test." % self)

	return issues


## Editor-time validations: checks useful in the editor / scene authoring
## Returns array of issues found
func get_editor_issues() -> Array[String]:
	var issues : Array[String] = []

	# Visual assets/settings that should be assigned for proper authoring
	if valid_settings == null:
		issues.append("%s: valid_settings is not assigned")
	if invalid_settings == null:
		issues.append("%s: invalid_settings is not assigned")
	if validity_sprite == null:
		issues.append("%s: No validity_sprite is assigned. It's needed for showing visual sprites for the RuleCheckIndicator")

	# If indicators are shown at runtime, a sprite should be provided for editor previews
	if show_indicators and validity_sprite == null:
		issues.append("%s: show_indicators is true but validity_sprite is not assigned")

	# Reuse shape check for editor as well
	issues.append_array(GBValidation.check_not_null(self, ["shape"]))

	return issues

func _on_debug_settings_changed() -> void:
	_update_debug_cached_state()
	
	# Request a redraw once when settings flip to enabled
	if _debug_draw_enabled:
		queue_redraw()

# Recompute whether debug drawing should be enabled
func _update_debug_cached_state() -> void:
	_debug_draw_enabled = false
	if _logger == null:
		return
	var settings := _logger.get_debug_settings() if _logger.has_method("get_debug_settings") else null
	if settings == null:
		return
	# Only enable debug draw when the explicit toggle on settings is true
	_debug_draw_enabled = bool(settings.draw_rule_check_indicator_debug)

## Update the validity of the rule check indicator by validating all rules attached
func update_validity_state() -> bool:
	if rules.size() == 0:
		valid = true  # No rules means valid by default
		return valid
	
	valid = validate_rules(rules).size() == 0
	return valid
	
## Immediately force shapecast update
## and a check for the validity of each rule given the new shapecast state
func force_validity_evaluation() -> bool:
	force_shapecast_update()
	return update_validity_state()

## Callback when validity changes
func _on_valid_changed(is_valid : bool):
	_update_current_display_settings([], is_valid)

## Helpers to read debug tuning values from GBDebugSettings (if available).
func _debug_setting_float_or(default_value: float, getter_name: String) -> float:
	if _logger == null:
		return default_value
	var settings := _logger.get_debug_settings() if _logger.has_method("get_debug_settings") else null
	if settings == null:
		return default_value
	# Try to read the exported property dynamically; get() returns null if missing
	var val = settings.get(getter_name)
	if val == null:
		return default_value
	return float(val)

## Helpers to read debug tuning values from GBDebugSettings (if available).
func _debug_setting_color_or(default_value: Color, getter_name: String) -> Color:
	if _logger == null:
		return default_value
	var settings := _logger.get_debug_settings() if _logger.has_method("get_debug_settings") else null
	if settings == null:
		return default_value
	var val = settings.get(getter_name)
	if val == null:
		return default_value
	return val as Color