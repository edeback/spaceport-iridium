class_name SaveRefs
extends RefCounted

## How a save names things it cannot hold (WI-73 §4, out of SaveManager): a live
## module, component, asteroid, pawn or pile as a small dictionary that survives
## the scene swap, the resolve back to the live object once it has been rebuilt,
## and resource stacks with their variance data.
##
## This is the `*_ref` discipline of CLAUDE.md's reference-hygiene rule: anything
## saved holds a node through one of these, never directly. A resolve runs against
## the restored world, so it only answers once the section that rebuilds its kind
## of object has applied - which is what [constant SaveManager.SECTION_ORDER] is
## ordered for.

## Whether `value` is a live instance, and complains when it is a FREED one.
##
## Why every *_ref helper takes a Variant (WI-68 F23): a typed parameter rejects
## a freed object at the call, before the body runs, so the is_instance_valid
## checks these helpers always carried were dead code for the one case they were
## written for. The script error then aborted whichever section collector was
## running - a pile tagged with a since-removed module wrote the whole `piles`
## section empty, and every pile on the station was gone on the next load. A
## freed reference now costs its own entry, never its neighbours'. The warning
## is how the dangling reference behind it gets found.
static func _live(value: Variant, what: String) -> bool:
	if is_instance_valid(value):
		return true
	if typeof(value) == TYPE_OBJECT:
		push_warning("SaveRefs: skipped a reference to a freed %s" % what)
	return false

# --- references to live objects ---------------------------------------------------

## Reference to a placed module instance: layer + root cell uniquely identify
## it (no per-instance ids needed). Null or freed module -> empty dict.
static func module_ref(module: Variant) -> Dictionary:
	if not _live(module, "module"):
		return {}
	var placed: ModuleBase = module as ModuleBase
	if placed == null or placed.module_data == null:
		return {}
	return {
		"layer": placed.module_data.interaction_layer,
		"cell": [placed.module_cell.x, placed.module_cell.y],
	}

static func resolve_module_ref(ref: Dictionary) -> ModuleBase:
	if ref.is_empty():
		return null
	var cell_arr: Array = ref.get("cell", [])
	if cell_arr.size() != 2:
		return null
	var layer: WorldManager.StructureLayer = int(ref.get("layer", 0)) as WorldManager.StructureLayer
	return Global.world_manager.get_module_by_cell(layer, Vector2i(int(cell_arr[0]), int(cell_arr[1])))

## Reference to a component inside a placed module (WI-21): the owning module's
## layer+cell (as module_ref) plus the node path from the module to the
## component. Same layer+cell+path scheme ModuleBase already uses to key its
## per-storage save data, so a re-placed module resolves the exact component.
static func component_ref(component: Variant) -> Dictionary:
	if not _live(component, "component"):
		return {}
	var part: ComponentBase = component as ComponentBase
	if part == null or not is_instance_valid(part.owner_module):
		return {}
	var ref: Dictionary = module_ref(part.owner_module)
	if ref.is_empty():
		return {}
	ref["path"] = String(part.owner_module.get_path_to(part))
	return ref

static func resolve_component_ref(ref: Dictionary) -> ComponentBase:
	var module: ModuleBase = resolve_module_ref(ref)
	if module == null:
		return null
	var path_str: String = String(ref.get("path", ""))
	if path_str == "":
		return null
	return module.get_node_or_null(NodePath(path_str)) as ComponentBase

## Reference to an asteroid by its stable id (WI-21). Empty for a null/freed
## rock; resolve returns null when the id is gone (mined dry, despawned, or a
## hand-edited save) so a mining job cancels cleanly through its lifecycle.
static func asteroid_ref(asteroid: Variant) -> Dictionary:
	if not _live(asteroid, "asteroid"):
		return {}
	var rock: AsteroidBase = asteroid as AsteroidBase
	return {"id": rock.asteroid_id} if rock != null else {}

static func resolve_asteroid_ref(ref: Dictionary) -> AsteroidBase:
	if ref.is_empty() or Global.asteroid_manager == null:
		return null
	return Global.asteroid_manager.get_asteroid_by_id(int(ref.get("id", -1)))

## Reference to a pawn by its stable pawn_id (WI-23 ids, WI-44 job targets).
## Pawns are restored before their jobs are rebuilt (SaveManager._load_pawn_jobs
## runs at the end of each pawn's entry), so a resolve during job restore sees
## every pawn loaded before it - and the pawn itself.
static func pawn_ref(pawn: Variant) -> Dictionary:
	if not _live(pawn, "pawn"):
		return {}
	var who: PawnBase = pawn as PawnBase
	if who == null or who.pawn_id == 0:
		return {}
	return {"pawn": who.pawn_id}

static func resolve_pawn_ref(ref: Dictionary) -> PawnBase:
	if ref.is_empty() or Global.world_manager == null:
		return null
	var target_id: int = int(ref.get("pawn", 0))
	if target_id == 0:
		return null
	for node: Node in Global.world_manager.get_tree().get_nodes_in_group(Groups.PAWN):
		var pawn: PawnBase = node as PawnBase
		if pawn != null and pawn.pawn_id == target_id:
			return pawn
	return null

## Reference to a resource pile by its stable id (WI-21). Piles are saved in the
## piles section with their ids, so resolve scans the live resource_debris group.
static func pile_ref(pile: Variant) -> Dictionary:
	if not _live(pile, "pile"):
		return {}
	var heap: ResourcePile = pile as ResourcePile
	return {"id": heap.pile_id} if heap != null else {}

static func resolve_pile_ref(ref: Dictionary) -> ResourcePile:
	if ref.is_empty() or Global.world_manager == null:
		return null
	var target_id: int = int(ref.get("id", -1))
	if target_id < 0:
		return null
	for node: Node in Global.world_manager.get_tree().get_nodes_in_group(Groups.RESOURCE_DEBRIS):
		var pile: ResourcePile = node as ResourcePile
		if pile != null and pile.pile_id == target_id:
			return pile
	return null

## Reference to any node a pawn's walk can name (WI-75): a path point or a walk's
## destination. That is a module, a pawn (a path starting in open space starts at
## the pawn itself), a pile, an asteroid, a turbolift cab, or one of the Node2Ds a
## module's SPACE door stands in open space - named by its module and door.
## Empty for null, a freed node, or anything else.
static func node_ref(node: Variant) -> Dictionary:
	if not _live(node, "path node"):
		return {}
	if node is ModuleBase:
		return {"module": module_ref(node)}
	if node is PawnBase:
		return pawn_ref(node)
	if node is ResourcePile:
		return {"pile": pile_ref(node)}
	if node is AsteroidBase:
		return {"asteroid": asteroid_ref(node)}
	if node is TurboliftCab:
		return {"cab": Global.turbolift_manager.cab_ref(node)} if Global.turbolift_manager != null else {}
	var point: Node2D = node as Node2D
	var owner_module: ModuleBase = point.get_parent() as ModuleBase if point != null else null
	if owner_module != null and owner_module.get_path_component() != null:
		var door: int = owner_module.get_path_component().door_of_space_node(point)
		if door >= 0:
			return {"space": module_ref(owner_module), "door": door}
	return {}

static func resolve_node_ref(ref: Dictionary) -> Node2D:
	if ref.is_empty():
		return null
	if ref.has("module"):
		return resolve_module_ref(ref["module"])
	if ref.has("pawn"):
		return resolve_pawn_ref(ref)
	if ref.has("pile"):
		return resolve_pile_ref(ref["pile"])
	if ref.has("asteroid"):
		return resolve_asteroid_ref(ref["asteroid"])
	if ref.has("cab"):
		return Global.turbolift_manager.resolve_cab_ref(ref["cab"]) if Global.turbolift_manager != null else null
	if ref.has("space"):
		var owner_module: ModuleBase = resolve_module_ref(ref["space"])
		if owner_module == null or owner_module.get_path_component() == null:
			return null
		return owner_module.get_path_component().space_node_for_door(int(ref.get("door", -1)))
	return null

# --- resource stacks -----------------------------------------------------------------

static func stacks_to_dicts(stacks: Array[ResourceStack]) -> Array:
	var out: Array = []
	for stack: ResourceStack in stacks:
		var entry: Dictionary = {"amount": stack.amount}
		if stack.instance_data != null:
			entry["instance"] = stack.instance_data.to_dict()
		out.append(entry)
	return out

static func stack_from_dict(resource: ResourceData, data: Dictionary) -> ResourceStack:
	var stack := ResourceStack.new()
	stack.resource_data = resource
	stack.amount = int(data.get("amount", 0))
	stack.instance_data = instance_from_dict(resource, data.get("instance", {}))
	return stack

## Rebuilds a stack's variance data from its to_dict() form (WI-47 M4). Returns
## null for an empty entry: null instance_data is a plain fungible stack.
##
## The class comes from the owning
## ResourceData's instance_data_script, not from a table in here: this used to be
## a `match` naming OreInstanceData and FoodInstanceData, so any modded resource
## with has_variance = true silently lost its instance data on every save.
##
## Resolving per-resource rather than through a global type_id table also means two
## mods can both call their variance "purity" without colliding - there is no
## shared namespace to collide in.
static func instance_from_dict(resource: ResourceData, data: Dictionary) -> ItemInstanceData:
	if data.is_empty():
		return null
	var saved_type: String = String(data.get("type", ""))
	if resource == null or resource.instance_data_script == null:
		# A stack that carries variance for a resource that no longer declares any:
		# the mod that owned it is gone, or the .tres lost its script. Dropping the
		# variance keeps the stack (and its amount), which is the fail-soft choice.
		if saved_type != "":
			push_warning("Saved '%s' instance data has no instance_data_script to rebuild it on %s"
					% [saved_type, resource.id if resource != null else &"<null resource>"])
		return null
	var script := resource.instance_data_script as GDScript
	if script == null or not script.can_instantiate():
		push_warning("instance_data_script on '%s' cannot be instantiated" % resource.id)
		return null
	var instance := script.new() as ItemInstanceData
	if instance == null:
		push_warning("instance_data_script on '%s' is not an ItemInstanceData" % resource.id)
		return null
	# The tag is advisory, but a mismatch means the resource's script changed under
	# an existing save and the fields about to be read may not be the ones written.
	if saved_type != "" and saved_type != String(instance.type_id()):
		push_warning("Saved instance type '%s' on '%s' no longer matches its script ('%s') - reading anyway"
				% [saved_type, resource.id, instance.type_id()])
	instance.from_dict(data)
	return instance
