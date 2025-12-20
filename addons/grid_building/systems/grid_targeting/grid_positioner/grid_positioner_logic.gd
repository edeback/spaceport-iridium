## Static utility class for GridPositioner logic (visibility and decision helpers).
##
## This class contains static functions for computing visibility decisions
## and diagnostic traces, making them easily unit testable without requiring
## a full GridPositioner2D instance.
##
## All functions are pure and depend only on their input parameters.
class_name GridPositionerLogic
extends RefCounted

const ProjectionMethod = GBEnums.ProjectionMethod
const RecenterDecision = {
	NONE = 0,
	LAST_SHOWN = 1,
	MOUSE_CURSOR = 2,
	VIEW_CENTER = 3,
}

static func proj_method_to_string(p_method: GBEnums.ProjectionMethod) -> String:
	return GBEnums.projection_method_to_string(p_method)

## Computes whether the positioner should be visible based on mode and settings.
##
## Visibility is determined by the following priority order:
## 1. [b]Mode-based visibility:[/b] OFF mode respects [code]remain_active_in_off_mode[/code], INFO mode is always hidden
## 2. [b]Recent allowed input:[/b] If mouse input was recently allowed, show positioner
## 3. [b]Cached mouse world override:[/b] If mouse world position exists and mouse input enabled, show positioner (overrides hide_on_handled)
## 4. [b]Hide on handled:[/b] If mouse input enabled + hide_on_handled=true + input blocked, hide positioner
## 5. [b]Default:[/b] Show positioner for active modes (BUILD, MOVE, etc.)
##
## [b]Hide on handled behavior:[/b]
## - Only applies when [code]targeting_settings.enable_mouse_input[/code] is [code]true[/code]
## - When mouse input is disabled, [code]hide_on_handled[/code] setting is ignored
## - Cached mouse world position takes precedence over hide_on_handled logic
##
## [param mode] The current building mode (GBEnums.Mode)
## [param targeting_settings] The targeting settings object
## [param last_mouse_input_status] Dictionary with last mouse input gate status
## [param has_mouse_world] Whether cached mouse world position exists
## [return] True if the positioner should be visible
static func should_be_visible(mode: GBEnums.Mode, targeting_settings: GridTargetingSettings, last_mouse_input_status: GBMouseInputStatus, has_mouse_world: bool) -> bool:
	match mode:
		GBEnums.Mode.OFF:
			# Respect remain_active_in_off_mode setting
			return targeting_settings != null and targeting_settings.remain_active_in_off_mode
		_:
			# If mouse input was recently allowed (we handled an InputEvent), always show
			if last_mouse_input_status != null and last_mouse_input_status.allowed:
				return true
			
			# Cached mouse world takes precedence over hide_on_handled blocking
			# This ensures retention behavior when we have valid cached position
			if has_mouse_world and targeting_settings and targeting_settings.enable_mouse_input:
				return true
			
			# hide_on_handled check comes after cached mouse world override
			# Only hide if input is blocked AND we don't have cached mouse world
			if targeting_settings != null and targeting_settings.hide_on_handled and targeting_settings.enable_mouse_input:
				if last_mouse_input_status != null and not last_mouse_input_status.allowed:
					return false

			return true

## Computes visibility for a specific mode value.
## [param mode] The mode to check
## [param targeting_settings] The targeting settings
## [return] True if visible in this mode
static func should_be_visible_for_mode(mode: GBEnums.Mode, targeting_settings: GridTargetingSettings) -> bool:
	match mode:
		GBEnums.Mode.OFF:
			return targeting_settings != null and targeting_settings.remain_active_in_off_mode
		GBEnums.Mode.INFO:
			return false
		_:
			return true

## Returns whether the positioner is considered active for the given mode/settings.
static func is_positioner_active(mode: GBEnums.Mode, targeting_settings: GridTargetingSettings) -> bool:
	if mode == GBEnums.Mode.OFF:
		return targeting_settings != null and targeting_settings.remain_active_in_off_mode
	return true

## Mouse follow allowed gate
static func is_mouse_follow_allowed(mode: GBEnums.Mode, targeting_settings: GridTargetingSettings, input_ready: bool) -> bool:
	if not input_ready:
		return false
	if targeting_settings == null:
		return false
	if not targeting_settings.enable_mouse_input:
		return false
	# For mode OFF, remain_active_in_off_mode controls movement
	if mode == GBEnums.Mode.OFF and not targeting_settings.remain_active_in_off_mode:
		return false
	return true

## Builds a diagnostic trace string for visibility decisions.
## [param mode_state] The mode state object (can be null)
## [param targeting_settings] The targeting settings (can be null)
## [param last_mouse_input_status] Last mouse input status dict
## [param has_mouse_world] Whether cached mouse world exists
## [return] Formatted trace string
static func visibility_decision_trace(mode_state: ModeState, targeting_settings: GridTargetingSettings, last_mouse_input_status: GBMouseInputStatus, has_mouse_world: bool) -> String:
	var mode_val: String = GBEnums.mode_to_string(mode_state.current) if mode_state != null else "<none>"
	var last_allowed: String = str(last_mouse_input_status != null and last_mouse_input_status.allowed)
	var mouse_enabled: String = str(targeting_settings.enable_mouse_input) if targeting_settings != null else "<n/a>"
	var computed_should: String = str(should_be_visible(mode_state.current if mode_state else GBEnums.Mode.OFF, targeting_settings, last_mouse_input_status, has_mouse_world))
	return "mode=%s, last_mouse_allowed=%s, has_mouse_world=%s, mouse_enabled=%s, computed_should=%s" \
		% [mode_val, last_allowed, str(has_mouse_world), mouse_enabled, computed_should]

## Event-driven visibility decision helper.
## Returns a MouseEventVisibilityResult with `apply=true` when the positioner
## visibility should be changed because of an InputEvent (mouse motion) and
## `visible` indicating the target visibility. Reason is a short string for
## diagnostics.
static func visibility_on_mouse_event(mode: GBEnums.Mode, targeting_settings: GridTargetingSettings, input_allowed: bool):
	var res = MouseEventVisibilityResult.new()
	# If settings don't enable mouse input or hide-on-handled is false, do nothing
	if targeting_settings == null:
		return res
	if not targeting_settings.enable_mouse_input:
		return res
	if not targeting_settings.hide_on_handled:
		return res

	# If gate blocked, hide until a new allowed event arrives
	if not input_allowed:
		res.apply = true
		res.visible = false
		res.reason = "mouse_gate:blocked"
		return res

	# If gate allowed, event handled -> show
	if input_allowed:
		res.apply = true
		res.visible = true
		res.reason = "mouse_event:allowed"
		return res

	return res

## Per-tick visibility decision helper used by GridPositioner2D._process.
## It centralizes the behavior where, even when continuous follow without events
## is disabled, we keep the positioner visible if recent mouse input was allowed
## or a cached mouse world exists. Only applies when hide_on_handled is true.
static func visibility_on_process_tick(mode: GBEnums.Mode, targeting_settings: GridTargetingSettings, input_ready: bool, last_mouse_input_status: GBMouseInputStatus, has_mouse_world: bool) -> MouseEventVisibilityResult:
	var res := MouseEventVisibilityResult.new()
	# Settings must exist and hide_on_handled must be true for visibility gating to matter
	if targeting_settings == null:
		return res
	if not targeting_settings.hide_on_handled:
		return res

	# Mouse follow allowed acts as the same guard used in the node implementation
	if not is_mouse_follow_allowed(mode, targeting_settings, input_ready):
		return res


	# When continuous follow is off, retain visibility if recently driven by mouse
	if last_mouse_input_status != null and last_mouse_input_status.allowed:
		res.apply = true
		res.visible = true
		res.reason = "retain_from_last_mouse_allowed"
		return res
	
	# Only show for cached mouse world if hide_on_handled is not actively blocking
	# This allows retention from cached mouse position unless actively being hidden
	if has_mouse_world and targeting_settings.enable_mouse_input:
		res.apply = true
		res.visible = true
		res.reason = "retain_from_cached_mouse_world"
		return res

	return res

## Per-tick reconciliation: if computed visibility differs from current, request an update.
## This ensures that when no event has fired yet (e.g., on scene load), the positioner is
## set to the expected visibility derived from mode/settings.
static func visibility_reconcile(mode: GBEnums.Mode, targeting_settings: GridTargetingSettings, current_visible: bool, last_mouse_input_status: GBMouseInputStatus, has_mouse_world: bool) -> MouseEventVisibilityResult:
	var res := MouseEventVisibilityResult.new()
	
	# Check if current visibility state might be the result of hide_on_handled logic
	var is_hide_on_handled_active := targeting_settings != null and targeting_settings.hide_on_handled and targeting_settings.enable_mouse_input
	var last_mouse_blocked := last_mouse_input_status != null and not last_mouse_input_status.allowed
	var might_be_hidden_by_handled := is_hide_on_handled_active and last_mouse_blocked and not current_visible
	
	# If this might be a valid hide_on_handled state, don't reconcile
	if might_be_hidden_by_handled:
		return res
	
	# For hide_on_handled mode, if mouse was blocked, we should stay hidden regardless of other factors
	if is_hide_on_handled_active and last_mouse_blocked:
		# If we're currently visible but should be hidden due to blocked mouse, apply the hidden state
		if current_visible:
			res.apply = true
			res.visible = false
			res.reason = "reconcile_hide_on_handled"
		return res
	
	var target_should := should_be_visible(mode, targeting_settings, last_mouse_input_status, has_mouse_world)
	if target_should != current_visible:
		res.apply = true
		res.visible = target_should
		res.reason = "reconcile_should_be_visible"
	return res

## Decide how to recenter on enable based on policy and available context.
## Returns a RecenterDecision enum value indicating the preferred action.
## Policy mapping:
## - NONE -> NONE
## - LAST_SHOWN -> LAST_SHOWN if cached; else MOUSE_CURSOR if mouse enabled; else VIEW_CENTER
## - VIEW_CENTER -> VIEW_CENTER
## - MOUSE_CURSOR -> MOUSE_CURSOR if cached or (mouse enabled and viewport available); else VIEW_CENTER
static func recenter_on_enable_decision(policy: int, has_cached_mouse_world: bool, mouse_input_enabled: bool, viewport_available: bool) -> int:
	match policy:
		GridTargetingSettings.RecenterOnEnablePolicy.NONE:
			return RecenterDecision.NONE
		GridTargetingSettings.RecenterOnEnablePolicy.LAST_SHOWN:
			if has_cached_mouse_world:
				return RecenterDecision.LAST_SHOWN
			if mouse_input_enabled:
				return RecenterDecision.MOUSE_CURSOR
			return RecenterDecision.VIEW_CENTER
		GridTargetingSettings.RecenterOnEnablePolicy.VIEW_CENTER:
			return RecenterDecision.VIEW_CENTER
		GridTargetingSettings.RecenterOnEnablePolicy.MOUSE_CURSOR:
			if has_cached_mouse_world:
				return RecenterDecision.MOUSE_CURSOR
			if mouse_input_enabled and viewport_available:
				return RecenterDecision.MOUSE_CURSOR
			return RecenterDecision.VIEW_CENTER
		_:
			return RecenterDecision.NONE

## Keyboard helper: compute tile delta from a key event and actions
static func get_tile_delta_from_key_event(event: InputEventKey, actions: GBActions) -> Vector2i:
	var move := Vector2.ZERO
	if event.is_action_pressed(actions.positioner_up):
		move += Vector2(0, -1)
	if event.is_action_pressed(actions.positioner_down):
		move += Vector2(0, 1)
	if event.is_action_pressed(actions.positioner_left):
		move += Vector2(-1, 0)
	if event.is_action_pressed(actions.positioner_right):
		move += Vector2(1, 0)
	return Vector2i(move)

## Keyboard helper: detect rotation input from a key event and actions
## [param event] The keyboard input event to check
## [param actions] GBActions containing rotation action mappings
## [return] Rotation direction: 1 for clockwise, -1 for counter-clockwise, 0 for no rotation
static func get_rotation_direction_from_key_event(event: InputEventKey, actions: GBActions) -> int:
	if event.is_action_pressed(actions.rotate_right):
		return 1  # Clockwise
	elif event.is_action_pressed(actions.rotate_left):
		return -1  # Counter-clockwise
	else:
		return 0  # No rotation
