## Generic material spending rule for placement validation.
##
## Allows custom resource classes without building system inventory dependencies. Expects resource stacks with type and count properties. Looks for _mat_container on the target building node.[br][br]
## [b]Required inventory methods:[/b][br]
## • [code]try_add[/code] or [code]add[/code] - Parameters: type: Resource, count: int[br]
## • [code]try_remove[/code] or [code]remove[/code] - Parameters: type: Resource, count: int[br]
## • [code]get_count[/code] - Parameters: type: Resource - Returns: int[br][br]
## Alternative: inherit from VirtualItemContainer and implement the methods.
class_name SpendMaterialsRuleGeneric
extends PlacementRule

## How many of each type need to be spent for the building rule to pass
## Resource should have fields type and count defined
@export var resource_stacks_to_spend : Array[ResourceStack] = []

## Used to find the inventory on the _owner_root passed in as a setup parameter
## so that the rule knows where to spend the resource_stacks_to_spend from
@export var locator : NodeLocator

## The target container to search for materials to spend
var _mat_container : Object :
	get:
		if _mat_container == null && _owner_root != null:
			_mat_container = _get_material_container_from_user(_owner_root)
			
		return _mat_container

## The spender root node where the material container should be located for spending resources from
var _owner_root : Node

func _init(
		p_resource_stacks_to_spend : Array[ResourceStack] = [],
		p_locator : NodeLocator = NodeLocator.new(),
		):
	resource_stacks_to_spend = p_resource_stacks_to_spend
	locator = p_locator

func setup(p_gts : GridTargetingState) -> Array[String]:
	_owner_root = p_gts.get_owner_root()
	_mat_container = _get_material_container_from_user(_owner_root)
	# Delegate to base PlacementRule.setup to initialize common state
	return super.setup(p_gts)

## Tries to spend the resources from the _mat_container
## Returns an array of issues found during the spending process
## If the spending was successful, the array will be empty
func apply() -> Array[String]:
	var issues : Array[String] = []
	var spent_stacks : Array[ResourceStack] = []
	var success = true
	
	if _mat_container == null:
		issues.append("No _mat_container found. Cannot spend resources from it.")
		return issues

	# Find the corresponding material type key and subtract the count from the material container
	for material in resource_stacks_to_spend:
		var spent_stack : ResourceStack
		var spent = 0
		
		if "try_remove" in _mat_container:
			spent += _mat_container.try_remove(material.type, material.count)
		elif "remove" in _mat_container:
			spent += _mat_container.remove(material.type, material.count)
		else:
			issues.append("SpendMaterialsRuleGeneric cannot spend resources from _mat_container. Expected it to have try_remove or remove methods.")
			success = false
			return issues

		if spent > 0:
			spent_stack = ResourceStack.new(material.type, spent)
			spent_stacks.append(spent_stack)
			
		if not spent == material.count:
			issues.append("Expected to spend %d of type [%s] but actually spent %d" % [material.count, material.type.resource_path, spent])
			success = false
			return issues

	return issues

func tear_down():
	pass

## Checks to see if there are enough resources to build item
func validate_placement() -> RuleResult:
	# Find the resource owning script and get the resource count for each type 
	# needed. Verify that each type has at least the count requested. If
	# any resource is not sufficient, return false
	var missing_resources_stacks : Array[ResourceStack] = check_missing_resources(_mat_container)
	
	if missing_resources_stacks.size() > 0:
		var failed_message : String = "Not Enough Materials: "
		
		# Needs to set resource names for them to show up in the string
		for missing_stack in missing_resources_stacks:
			if missing_stack.type == null:
				push_error("Missing a null resource type of count " + str(missing_stack.count) + " at " + missing_stack.resource_path)
				continue
			
			# Try to find display_name property, else default back to resource name for display
			var material_name = _get_material_name(missing_stack.type)
			
			failed_message += "\n" + material_name + " : " + str(missing_stack.count)
		
		return RuleResult.build(self, [failed_message])
	else:
		return RuleResult.build(self, [])
	
## Checks the resouce _mat_container to see if it has enough of each resource type
## Returns ItemStacks that contain the amount missing for each type
func check_missing_resources(p_owner_root_container) -> Array[ResourceStack]:
	assert(p_owner_root_container != null, "No spender container provided to check for missing resources.")
	if p_owner_root_container == null:
		return resource_stacks_to_spend

	var missing_resources : Array[ResourceStack] = []
	
	for needed_resource in resource_stacks_to_spend:
		# Interface: Inventory target should have get_count
		var had_count : int = p_owner_root_container.get_count(needed_resource.type)
		
		if had_count < needed_resource.count:
			var missing_count = needed_resource.count - had_count
			var missing_stack = ResourceStack.new(needed_resource.type, missing_count)
			missing_resources.append(missing_stack)
			
	return missing_resources
	
## Finds the container for the spendable materials by
## searching either for the matching node by name or class name
## Starts at the user node of the building system and then checks children
## nodes recursively
func _get_material_container_from_user(user : Node) -> Node:
	return locator.locate_container(user)

func _get_pre_setup_issues(p_gts : GridTargetingState) -> Array[String]:
	var issues : Array[String] = []
	
	if(resource_stacks_to_spend == null):
		issues.append("Materials to Spend is null in rule " + resource_path)

	if(resource_stacks_to_spend.size() == 0):
		issues.append("No materials to spend set in array for rule " + resource_path)

	for stack in resource_stacks_to_spend:
		if(stack.type == null):
			issues.append("Spend resource type is null: " + stack.resource_path)

	return issues

func _get_post_setup_issues() -> Array[String]:
	var issues : Array[String] = []

	if _mat_container == null:
		issues.append("No material container found for spender " + str(_owner_root.get_path()))

	return issues

func _get_material_name(p_material : Resource) -> String:
	if "display_name" in p_material:
		return p_material.display_name
	
	return p_material.resource_name
