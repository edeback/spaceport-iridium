## Helper logic and diagnostics for RuleCheckIndicator.
##
## Centralizes small, side-effect-free helpers used by tests and runtime tooling
## to avoid duplicating formatting and inspection code across test suites.
##
## Functions here are pure (no printing/logging). Callers decide whether to log
## or attach strings to assertions.
class_name RuleCheckIndicatorLogic
extends RefCounted

## Build a concise rules diagnostic string for an indicator.
## [param ind] The indicator to inspect
## [return] A short summary like: "rules=2 [{pass_on_collision=true, mask=1}, ...]"
static func build_rules_diag(ind: RuleCheckIndicator) -> String:
	if ind == null:
		return "<indicator:null>"
	var rules: Array = []
	# Prefer direct API; keep a minimal guard for legacy callers
	if ind.has_method("get_rules"):
		rules = ind.get_rules()
	if rules.is_empty():
		return "rules=0 []"
	var parts: Array[String] = []
	for r in rules:
		# Best-effort formatting for CollisionsCheckRule-like objects
		var pass_on_collision: bool = false
		if ("pass_on_collision" in r):
			pass_on_collision = bool(r.pass_on_collision)
		var mask: int = -1
		if ("collision_mask" in r):
			mask = int(r.collision_mask)
		parts.append("{pass_on_collision=%s, mask=%d}" % [str(pass_on_collision), mask])
	return "rules=%d %s" % [rules.size(), "[" + ", ".join(parts) + "]"]

## Build a visual/texture diagnostic for current indicator state.
## [param ind] The indicator to inspect
## [return] A summary like: "display=valid_settings tex=(valid=true, invalid=false) modulate=Color(1,1,1,1)"
static func build_visuals_diag(ind: RuleCheckIndicator) -> String:
	if ind == null:
		return "<indicator:null>"
	var cd := ind.current_display_settings
	var which := "<none>"
	if cd == ind.valid_settings:
		which = "valid_settings"
	elif cd == ind.invalid_settings:
		which = "invalid_settings"
	var tex := ind.validity_sprite.texture if ind.validity_sprite != null else null
	var tex_eq_v := tex == (ind.valid_settings.texture if ind.valid_settings else null)
	var tex_eq_i := tex == (ind.invalid_settings.texture if ind.invalid_settings else null)
	var mod := ind.validity_sprite.modulate if ind.validity_sprite != null else Color.WHITE
	return "display=%s tex=(valid=%s, invalid=%s) modulate=%s" % [which, str(tex_eq_v), str(tex_eq_i), str(mod)]

## Build a full indicator state diagnostic formatted via GBDiagnostics.
## [param ind] The indicator to inspect
## [param header] Optional header line to prepend
## [return] Multi-line diagnostic wrapped by GBDiagnostics.format_debug
static func format_indicator_state(ind: RuleCheckIndicator, header: String = "", resource_path: String = "") -> String:
	# Backwards-compatible adapter that extracts minimal pieces and delegates
	if ind == null:
		var rp := resource_path
		if rp == "":
			rp = ""
		return GBDiagnostics.format_debug("<indicator:null>", "RuleCheckIndicator", rp)
	var collisions := ind.get_collision_count() if ind.has_method("get_collision_count") else -1
	var rp := resource_path
	if rp == "":
		# Safely get instance script path from the provided indicator
		if ind.has_method("get_script"):
			var s := ind.get_script()
			rp = s.resource_path if s != null else ""
	return format_indicator_state_from_parts(
		ind.valid,
		collisions,
		ind.global_position,
		ind.get_rules() if ind.has_method("get_rules") else [],
		ind.current_display_settings,
		ind.valid_settings,
		ind.invalid_settings,
		ind.validity_sprite,
		header,
		rp
	)

## Build a concise rules diagnostic from a rules array (no indicator object required)
static func build_rules_diag_from_rules(rules: Array) -> String:
	if rules == null or rules.is_empty():
		return "rules=0 []"
	var parts: Array[String] = []
	for r in rules:
		var pass_on_collision: bool = false
		if ("pass_on_collision" in r):
			pass_on_collision = bool(r.pass_on_collision)
		var mask: int = -1
		if ("collision_mask" in r):
			mask = int(r.collision_mask)
		parts.append("{pass_on_collision=%s, mask=%d}" % [str(pass_on_collision), mask])
	return "rules=%d %s" % [rules.size(), "[" + ", ".join(parts) + "]"]

## Build visuals diagnostic given discrete components (no indicator object required)
static func build_visuals_diag_from_parts(current_display_settings: IndicatorVisualSettings, valid_settings: IndicatorVisualSettings, invalid_settings: IndicatorVisualSettings, validity_sprite: Sprite2D) -> String:
	if current_display_settings == null and validity_sprite == null and valid_settings == null and invalid_settings == null:
		return "<indicator:null>"
	var cd := current_display_settings
	var which := "<none>"
	if cd == valid_settings:
		which = "valid_settings"
	elif cd == invalid_settings:
		which = "invalid_settings"
	var tex := validity_sprite.texture if validity_sprite != null else null
	var tex_eq_v := tex == (valid_settings.texture if valid_settings else null)
	var tex_eq_i := tex == (invalid_settings.texture if invalid_settings else null)
	var mod := validity_sprite.modulate if validity_sprite != null else Color.WHITE
	return "display=%s tex=(valid=%s, invalid=%s) modulate=%s" % [which, str(tex_eq_v), str(tex_eq_i), str(mod)]

## Format indicator state from small pieces of data (no indicator object required)
static func format_indicator_state_from_parts(valid: bool, collisions: int, global_position: Vector2, rules: Array, current_display_settings: IndicatorVisualSettings, valid_settings: IndicatorVisualSettings, invalid_settings: IndicatorVisualSettings, validity_sprite: Sprite2D, header: String = "", resource_path: String = "") -> String:
	var rows: Array[String] = []
	if header != "":
		rows.append(header)
	rows.append("valid=%s collisions=%d pos=%s" % [str(valid), collisions, str(global_position)])
	rows.append(build_rules_diag_from_rules(rules))
	rows.append(build_visuals_diag_from_parts(current_display_settings, valid_settings, invalid_settings, validity_sprite))
	var rp := resource_path
	return GBDiagnostics.format_debug("\n" + "\n".join(rows), "RuleCheckIndicator", rp)

## Find the rule with highest visual priority that defines fail_visual_settings.
static func find_highest_rule_with_visual_settings(p_rules: Array[TileCheckRule]) -> TileCheckRule:
	var selected_rule: TileCheckRule = null
	# visual_priority is exported as int; use -1 sentinel so we can type it as int
	var selected_priority: int = -1
	for rule in p_rules:
		if rule == null:
			continue
		if rule.fail_visual_settings == null:
			continue
		if selected_priority == -1 or rule.visual_priority > selected_priority:
			selected_rule = rule
			selected_priority = int(rule.visual_priority)
	return selected_rule

## Validate the provided rules for the given indicator and return failing rules.
## This mirrors RuleCheckIndicator.validate_rules but as a pure function to aid testing.
static func validate_rules_from_rules_and_checker(p_rules: Array[TileCheckRule], failing_checker: Callable) -> Array[TileCheckRule]:
	var failing_rules : Array[TileCheckRule] = []
	if p_rules == null:
		return failing_rules
	for rule in p_rules:
		if not rule._ready:
			continue
		# failing_checker is expected to be a callable that accepts a rule and returns an Array of failing indicators
		var failing_indicators := failing_checker.call(rule)
		var is_valid: bool = failing_indicators.size() == 0
		if not is_valid:
			failing_rules.append(rule)
	return failing_rules

## Pick the appropriate display settings given validity state and failing rules.
static func choose_display_settings(p_display_rules: Array[TileCheckRule], p_is_valid: bool, valid_settings: IndicatorVisualSettings, invalid_settings: IndicatorVisualSettings) -> IndicatorVisualSettings:
	if p_is_valid:
		return valid_settings
	var displaying_rule := find_highest_rule_with_visual_settings(p_display_rules)
	if displaying_rule != null:
		return displaying_rule.fail_visual_settings
	return invalid_settings
