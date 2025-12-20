## Grid Building System Analysis Tool
##
## Provides detailed analysis of grid building system components for debugging.
## This is plugin-specific (not project-agnostic) and can safely reference 
## grid building plugin classes like BuildingSystem, GridTargetingSystem, etc.
##
## Unlike the runtime scene analyzer which is project-agnostic, this analyzer
## is designed specifically for the grid building plugin and knows about all
## the plugin's internal classes and their expected configurations.
##
## Usage:
## var analyzer = GridBuildingAnalyzer.new()
## var analysis = analyzer.analyze_scene(scene_root)
## print(analysis)
class_name GridBuildingAnalyzer
extends RefCounted

## Analyzes a scene for grid building system components and configuration issues
func analyze_scene(scene_root: Node) -> String:
	var analysis = []
	analysis.append("=== GRID BUILDING SYSTEM ANALYSIS ===")
	analysis.append("Scene: " + scene_root.name + " (" + scene_root.get_class() + ")")
	analysis.append("")
	
	# Find and analyze the injector system
	var injector_analysis = _analyze_injector_system(scene_root)
	analysis.append(injector_analysis)
	
	# Find and analyze building/targeting systems
	var systems_analysis = _analyze_systems(scene_root)
	analysis.append(systems_analysis)
	
	# Find and analyze grid positioner
	var positioner_analysis = _analyze_grid_positioner(scene_root)
	analysis.append(positioner_analysis)
	
	# Find and analyze level context
	var level_analysis = _analyze_level_context(scene_root)
	analysis.append(level_analysis)
	
	# Summary of issues
	var issues_analysis = _analyze_configuration_issues(scene_root)
	analysis.append(issues_analysis)
	
	return "\n".join(analysis)

func _analyze_injector_system(scene_root: Node) -> String:
	var analysis = []
	analysis.append("--- INJECTOR SYSTEM ---")
	
	var injector = _find_node_by_type(scene_root, "GBInjectorSystem")
	if injector == null:
		analysis.append("❌ No GBInjectorSystem found")
		return "\n".join(analysis)
	
	analysis.append("✅ GBInjectorSystem found: " + str(injector.get_path()))
	
	# Check composition container
	if injector.has_method("composition_container") or "composition_container" in injector:
		var container = injector.composition_container if "composition_container" in injector else null
		if container != null:
			analysis.append("✅ Composition container exists")
			analysis.append(_analyze_composition_container(container))
		else:
			analysis.append("❌ Composition container is null")
	else:
		analysis.append("❌ No composition_container property found")
	
	return "\n".join(analysis)

func _analyze_composition_container(container) -> String:
	var analysis = []
	analysis.append("  Container config exists: " + str(container.config != null))
	
	if container.config != null:
		analysis.append("  Templates exists: " + str(container.config.templates != null))
		if container.config.templates != null:
			analysis.append("  Rule check indicator template: " + str(container.config.templates.rule_check_indicator != null))
		
		analysis.append("  Settings exists: " + str(container.config.settings != null))
		if container.config.settings != null:
			analysis.append("  Targeting settings: " + str(container.config.settings.targeting != null))
			analysis.append("  Building settings: " + str(container.config.settings.building != null))
			analysis.append("  Placement rules count: " + str(container.config.settings.placement_rules.size()))
	
	return "\n".join(analysis)

func _analyze_systems(scene_root: Node) -> String:
	var analysis = []
	analysis.append("--- GRID BUILDING SYSTEMS ---")
	
	# Check BuildingSystem
	var building_system = _find_node_by_type(scene_root, "BuildingSystem")
	if building_system != null:
		analysis.append("✅ BuildingSystem found: " + str(building_system.get_path()))
		
		# Check building state
		if building_system.has_method("get_building_state"):
			var building_state = building_system.get_building_state()
			analysis.append("  Building state exists: " + str(building_state != null))
			
			if building_state != null and building_state.has_method("get_placement_manager"):
				var placement_manager = building_state.get_placement_manager()
				analysis.append("  Placement manager exists: " + str(placement_manager != null))
			else:
				analysis.append("  Cannot check placement manager (no get_placement_manager method)")
	else:
		analysis.append("❌ No BuildingSystem found")
	
	# Check GridTargetingSystem
	var targeting_system = _find_node_by_type(scene_root, "GridTargetingSystem")
	if targeting_system != null:
		analysis.append("✅ GridTargetingSystem found: " + str(targeting_system.get_path()))
		
		# Check targeting state
		if targeting_system.has_method("get_targeting_state"):
			var targeting_state = targeting_system.get_targeting_state()
			analysis.append("  Targeting state exists: " + str(targeting_state != null))
			
			if targeting_state != null:
				var ready_status = targeting_state.ready if "ready" in targeting_state else "unknown"
				analysis.append("  Targeting state ready: " + str(ready_status))
				
				var positioner = targeting_state.positioner if "positioner" in targeting_state else null
				analysis.append("  Positioner set: " + str(positioner != null))
				
				var target_map = targeting_state.target_map if "target_map" in targeting_state else null
				analysis.append("  Target map set: " + str(target_map != null))
	else:
		analysis.append("❌ No GridTargetingSystem found")
	
	return "\n".join(analysis)

func _analyze_grid_positioner(scene_root: Node) -> String:
	var analysis = []
	analysis.append("--- GRID POSITIONER ---")
	
	var positioner = _find_node_by_name(scene_root, "GridPositioner")
	if positioner == null:
		analysis.append("❌ No GridPositioner found")
		return "\n".join(analysis)
	
	analysis.append("✅ GridPositioner found: " + str(positioner.get_path()))
	analysis.append("  Type: " + positioner.get_class())
	analysis.append("  Children count: " + str(positioner.get_children().size()))
	
	for child in positioner.get_children():
		analysis.append("    Child: " + child.name + " (" + child.get_class() + ")")
		
		if child.name == "ManipulationParent":
			analysis.append("      ManipulationParent children: " + str(child.get_children().size()))
			for grandchild in child.get_children():
				analysis.append("        " + grandchild.name + " (" + grandchild.get_class() + ")")
				
				if grandchild.name == "IndicatorManager":
					analysis.append("        ✅ IndicatorManager found in hierarchy")
					analysis.append("        Has script: " + str(grandchild.get_script() != null))
					
					# Check if IndicatorManager is properly initialized
					if grandchild.has_method("get_dependency_issues"):
						var validation_issues = grandchild.get_runtime_issues()
						if validation_issues.size() > 0:
							analysis.append("        ❌ IndicatorManager validation issues:")
							for issue in validation_issues:
								analysis.append("          - " + issue)
						else:
							analysis.append("        ✅ IndicatorManager validation passed")
	
	return "\n".join(analysis)

func _analyze_level_context(scene_root: Node) -> String:
	var analysis = []
	analysis.append("--- LEVEL CONTEXT ---")
	
	# Look for level context nodes
	var level_context = _find_node_by_type(scene_root, "GBLevelContext")
	if level_context != null:
		analysis.append("✅ GBLevelContext found: " + str(level_context.get_path()))
	else:
		analysis.append("❌ No GBLevelContext found")
		
		# Check for common level containers
		var level_containers = ["IsometricLevel", "PlatformerLevel", "Level"]
		for container_name in level_containers:
			var container = _find_node_by_name(scene_root, container_name)
			if container != null:
				analysis.append("  Found level container: " + str(container.get_path()))
				# Check if it has a level context child
				for child in container.get_children():
					if child.get_class().contains("LevelContext") or child.name.contains("LevelContext"):
						analysis.append("  ✅ Found level context child: " + str(child.get_path()))
	
	return "\n".join(analysis)

func _analyze_configuration_issues(scene_root: Node) -> String:
	var analysis = []
	analysis.append("--- CONFIGURATION ISSUES SUMMARY ---")
	
	var issues = []
	
	# Check critical components
	if _find_node_by_type(scene_root, "GBInjectorSystem") == null:
		issues.append("Missing GBInjectorSystem")
	
	if _find_node_by_type(scene_root, "BuildingSystem") == null:
		issues.append("Missing BuildingSystem")
	
	if _find_node_by_type(scene_root, "GridTargetingSystem") == null:
		issues.append("Missing GridTargetingSystem")
	
	if _find_node_by_name(scene_root, "GridPositioner") == null:
		issues.append("Missing GridPositioner")
	
	if _find_node_by_type(scene_root, "GBLevelContext") == null:
		issues.append("Missing GBLevelContext (may cause placement issues)")
	
	# Check for common misconfigurations
	var targeting_system = _find_node_by_type(scene_root, "GridTargetingSystem")
	if targeting_system != null and targeting_system.has_method("get_targeting_state"):
		var targeting_state = targeting_system.get_targeting_state()
		if targeting_state != null:
			if "positioner" in targeting_state and targeting_state.positioner == null:
				issues.append("GridTargetingState positioner not set")
			if "target_map" in targeting_state and targeting_state.target_map == null:
				issues.append("GridTargetingState target_map not set")
	
	if issues.size() > 0:
		analysis.append("❌ Issues found:")
		for issue in issues:
			analysis.append("  - " + issue)
	else:
		analysis.append("✅ No critical configuration issues detected")
	
	return "\n".join(analysis)

func _find_node_by_type(root: Node, type_name: String) -> Node:
	# Check if this node matches by class name
	if root.get_class() == type_name:
		return root
	
	# Also check script class names for custom classes by checking the script path
	if root.get_script() != null:
		var script_path = root.get_script().get_path()
		var script_file = script_path.get_file().get_basename()
		# Match common patterns like "building_system.gd" for "BuildingSystem"
		if script_file.to_lower().replace("_", "").contains(type_name.to_lower().replace("_", "")):
			return root
	
	# Search children recursively
	for child in root.get_children():
		var found = _find_node_by_type(child, type_name)
		if found != null:
			return found
	
	return null

func _find_node_by_name(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	
	for child in root.get_children():
		var found = _find_node_by_name(child, node_name)
		if found != null:
			return found
	
	return null
