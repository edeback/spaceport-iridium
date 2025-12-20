## Holds references to all settings resources for grid building operations
class_name GBSettings
extends GBResource

## Holds all of the settings for parameters, input actions, etc for building / placing objects inside of the game
@export var building : BuildingSettings

## ## Settings concerning moving objects within the game world
@export var manipulation : ManipulationSettings

## Settings related to targeting tiles and the pathing that goes between them
@export var targeting : GridTargetingSettings

## Settings for how grid building should display visual information like UI elements to the player.
@export var visual : GBVisualSettings

## Settings that control how the action log UI functions
@export var action_log : ActionLogSettings

## The base rules that apply to all placement (initial build or adjust from one spot to another)
@export var placement_rules : Array[PlacementRule]

## Extra flags for checking specific systems at runtime
@export var runtime_checks : GBRuntimeChecks

## Settings concerning debugging GridBuilder plugin issues
@export var debug : GBDebugSettings

func _init():
	building = building if building != null else BuildingSettings.new()
	manipulation = manipulation if manipulation != null else ManipulationSettings.new()
	targeting = targeting if targeting != null else GridTargetingSettings.new()
	visual = visual if visual != null else GBVisualSettings.new()
	debug = debug if debug != null else GBDebugSettings.new()

func get_editor_issues() -> Array[String]:
	var issues : Array[String] = []

	if building == null:
		issues.append("GBSettings.building is null")
	else:
		issues.append_array(building.get_editor_issues())
	if manipulation == null:
		issues.append("GBSettings.manipulation is null")
	else:
		issues.append_array(manipulation.get_editor_issues())
	if targeting == null:
		issues.append("GBSettings.targeting is null")
	else:
		issues.append_array(targeting.get_editor_issues())

	if visual == null:
		issues.append("GBSettings.visual is null")
	else:
		issues.append_array(visual.get_editor_issues())
		
	if debug == null:
		issues.append("GBSettings.debug is null")
	else:
		issues.append_array(debug.get_editor_issues())

	return issues

func get_runtime_issues() -> Array[String]:
	var issues : Array[String] = []

	if building == null:
		issues.append("GBSettings.building is null")
	else:
		issues.append_array(building.get_runtime_issues())
	if manipulation == null:
		issues.append("GBSettings.manipulation is null")
	else:
		issues.append_array(manipulation.get_runtime_issues())
	if targeting == null:
		issues.append("GBSettings.targeting is null")
	else:
		issues.append_array(targeting.get_runtime_issues())

	if visual == null:
		issues.append("GBSettings.visual is null")
	else:
		issues.append_array(visual.get_runtime_issues())
		
	if debug == null:
		issues.append("GBSettings.debug is null")
	else:
		issues.append_array(debug.get_runtime_issues())

	return issues
