## Centralized validation system for GBCompositionContainer configuration.
##
## Validates that all required dependencies and configurations are properly set up before systems start operating.
class_name GBConfigurationValidator
extends RefCounted

## Validates a GBCompositionContainer configuration.
## Returns list of validation issues (empty if valid).
## [code]container[/code]: [i]GBCompositionContainer[/i] - The container to validate
static func get_editor_issues(container: GBCompositionContainer) -> Array[String]:
	var issues: Array[String] = []

	var contexts : GBContexts = container.get_contexts()

	if not contexts:
		issues.append("GBContexts is not initialized")
	else:
		issues.append_array(contexts.get_editor_issues())

	if not container.config:
		issues.append("GBConfig is not assigned in GBCompositionContainer")
	else:
		issues.append_array(container.config.get_editor_issues())

	var templates : GBTemplates = container.get_templates()

	if not templates:
		issues.append("GBTemplates is not initialized")
	else:
		issues.append_array(templates.get_editor_issues())

	var actions : GBActions = container.get_actions()

	if not actions:
		issues.append("GBActions is not initialized")
	else:
		issues.append_array(actions.get_editor_issues())

	var states : GBStates = container.get_states()

	if not states:
		issues.append("GBStates is not initialized")

	return issues

## Validates runtime configuration (called after nodes are set up)
## [code]container[/code]: [i]GBCompositionContainer[/i] - The container to validate
## [code]logger[/code]: [i]GBLogger[/i] - The logger to use for logging issues
## [code]p_checks[/code]: [i]GBRuntimeChecks[/i] - The runtime checks to perform
static func get_runtime_issues(container: GBCompositionContainer, p_checks: GBRuntimeChecks) -> Array[String]:
	var issues: Array[String] = []

	var contexts : GBContexts = container.get_contexts()

	if not contexts:
		issues.append("GBContexts is not initialized")
	else:
		issues.append_array(contexts.get_runtime_issues(p_checks))

	if not container.config:
		issues.append("GBConfig is not assigned in GBCompositionContainer")
	else:
		issues.append_array(container.config.get_runtime_issues())

	var templates : GBTemplates = container.get_templates()

	if not templates:
		issues.append("GBTemplates is not initialized")
	else:
		issues.append_array(templates.get_runtime_issues())

	var actions : GBActions = container.get_actions()

	if not actions:
		issues.append("GBActions is not initialized")
	else:
		issues.append_array(actions.get_runtime_issues())

	var states : GBStates = container.get_states()

	if not states:
		issues.append("GBStates is not initialized")
	else:
		issues.append_array(states.get_runtime_issues())

	return issues

## Helper function to format diagnostic sections into human-readable output
static func _format_diagnostic_sections(sections: Dictionary, title: String, container: GBCompositionContainer, all_issues: Array) -> String:
	var lines: Array[String] = []
	lines.append("GBConfigurationValidator: %s" % title)
	var container_path = "<unknown>"
	if container.resource_path != null and container.resource_path != "":
		container_path = container.resource_path
	lines.append("Container: %s" % container_path)
	lines.append("")

	for section_name in sections.keys():
		lines.append("--- %s ---" % section_name)
		var issues: Array = sections[section_name]
		if issues == null or issues.size() == 0:
			lines.append("OK")
		else:
			for it in issues:
				lines.append("- %s" % str(it))
		lines.append("")

	# Also include consolidated summary and total count
	lines.append("Summary: %d issue(s) found" % [all_issues.size()])
	if all_issues.size() > 0:
		lines.append("Consolidated issues:")
		for it in all_issues:
			lines.append("- %s" % str(it))

	return "\n".join(lines)

## Returns a human-readable, grouped diagnostic string for editor issues.
## This enumerates each main subresource (contexts, config, templates, actions, states)
## and prints the issues found for each one, including the resource path when available.
static func editor_diagnostic(container: GBCompositionContainer) -> String:
	if container == null:
		return "GBConfigurationValidator: container is NULL"

	var sections := {}

	# GBContexts
	var contexts : GBContexts = null
	contexts = container.get_contexts()

	if not contexts:
		sections["GBContexts"] = ["GBContexts is not initialized"]
	else:
		sections["GBContexts"] = contexts.get_editor_issues()

	# GBConfig and its subresources
	if not container.config:
		sections["GBConfig"] = ["GBConfig is not assigned in GBCompositionContainer"]
	else:
		sections["GBConfig"] = container.config.get_editor_issues()

	# GBTemplates
	var templates : GBTemplates = container.get_templates()
	if not templates:
		sections["GBTemplates"] = ["GBTemplates is not initialized"]
	else:
		sections["GBTemplates"] = templates.get_editor_issues()

	# GBActions
	var actions : GBActions = container.get_actions()
	if not actions:
		sections["GBActions"] = ["GBActions is not initialized"]
	else:
		sections["GBActions"] = actions.get_editor_issues()

	# GBStates
	var states : GBStates = container.get_states()
	if not states:
		sections["GBStates"] = ["GBStates is not initialized"]

	# Use shared formatting function
	var all_issues: Array = get_editor_issues(container)
	return _format_diagnostic_sections(sections, "Editor Diagnostic", container, all_issues)

## Returns a human-readable, grouped diagnostic string for runtime issues.
## This enumerates each main subresource (contexts, config, templates, actions, states)
## and prints the issues found for each one, including the resource path when available.
static func runtime_diagnostic(container: GBCompositionContainer, p_checks: GBRuntimeChecks = null) -> String:
	if container == null:
		return "GBConfigurationValidator: container is NULL"

	if p_checks == null:
		# Best-effort: try to obtain runtime checks from the container
		p_checks = container.get_runtime_checks()

	var sections := {}

	# GBContexts
	var contexts : GBContexts = null
	contexts = container.get_contexts()

	if not contexts:
		sections["GBContexts"] = ["GBContexts is not initialized"]
	else:
		sections["GBContexts"] = contexts.get_runtime_issues(p_checks)

	# GBConfig and its subresources
	if not container.config:
		sections["GBConfig"] = ["GBConfig is not assigned in GBCompositionContainer"]
	else:
		sections["GBConfig"] = container.config.get_runtime_issues()

	# GBTemplates
	var templates : GBTemplates = container.get_templates()
	if not templates:
		sections["GBTemplates"] = ["GBTemplates is not initialized"]
	else:
		sections["GBTemplates"] = templates.get_runtime_issues()

	# GBActions
	var actions : GBActions = container.get_actions()
	if not actions:
		sections["GBActions"] = ["GBActions is not initialized"]
	else:
		sections["GBActions"] = actions.get_runtime_issues()

	# GBStates
	var states : GBStates = container.get_states()
	if not states:
		sections["GBStates"] = ["GBStates is not initialized"]
	else:
		sections["GBStates"] = states.get_runtime_issues()

	# Use shared formatting function
	var all_issues: Array = get_runtime_issues(container, p_checks)
	return _format_diagnostic_sections(sections, "Runtime Diagnostic", container, all_issues)



## Logs issues and returns whether no issues were found
static func validate_editor(container: GBCompositionContainer) -> bool:
	var issues := get_editor_issues(container)
	var logger := container.get_logger()

	logger.log_issues(issues)

	return issues.is_empty()

## Highly recommended to call this deferred on ready for your main gameplay scene
## to allow all nodes to be properly added to the scene AND injected
## by the GBInjectorSystem before validation
static func validate_runtime(container: GBCompositionContainer) -> bool:
	var issues := get_runtime_issues(container, container.get_runtime_checks())
	var logger := container.get_logger()

	logger.log_issues(issues)

	return issues.is_empty()
