class_name ModuleFacts
extends RefCounted

## The numbers a module scene *declares*, read once per scene and cached (WI-54).
##
## The Build panel's selected row explains the module inline - "description, and
## its rate/draw line" - rather than in a hover tooltip, because that "survives
## keyboard and controller navigation, and is readable while the ghost is already
## on the station". This is where that line's numbers come from.
##
## Only **authored** values are read. Nothing here simulates: a mining bay's real
## ore rate depends on its drones, the asteroid they reach and the operator's
## skill, and a number the panel invented for it would be wrong in every station
## that is not the one it was calibrated on. What a scene states outright - what
## it draws from the grid, what it feeds back, how much it holds, how many crew
## it seats - is true before the module is placed, which is exactly when the
## player is reading it.
##
## Same shape and the same reason as [PreviewModule.ModulePreviewData] (WI-42):
## keyed by [PackedScene] rather than by [ModuleData] so a flippable module's two
## variants are distinguished for free, populated by instantiating the scene
## once, and owned by the node that asked rather than held in a static - a static
## cache would keep every inspected [PackedScene] alive across a Quit-to-Menu.
##
## Instantiating a scene never puts it in the tree, so no `_ready` runs and
## nothing registers itself with a manager. That also means [member
## ModuleBase.components] is still empty (components append themselves from their
## own `_ready`), which is why this walks the node tree instead of reading it.

## Cell footprint, straight off the module scene's root.
var footprint: Vector2i = Vector2i.ONE
## Grid draw, summed over every [PowerConsumptionComponent] in the scene.
var power_draw: float = 0.0
## Grid feed, summed over every [PowerGenerationComponent]. A solar panel's real
## output is scaled down by how boxed-in it is; the authored figure is its best
## case, which is the honest thing to show for a module that has not been placed
## and therefore has no neighbours yet.
var power_output: float = 0.0
## Units held, summed over the storages that count toward station stock. A
## processor's internal input hopper is excluded on the same
## `include_in_stats` flag the rest of the game reads it on.
var storage_capacity: int = 0
## Seats a module offers its crew: workspace assignments and sleep berths, which
## are the two things a player picks a module *for*.
var crew_slots: int = 0

## Reads one module scene. Never returns null - a scene with none of these
## components yields an all-zero factsheet, which renders as no facts line.
static func from_scene(scene: PackedScene) -> ModuleFacts:
	var facts := ModuleFacts.new()
	if scene == null:
		return facts
	var root: ModuleBase = scene.instantiate() as ModuleBase
	if root == null:
		return facts
	facts.footprint = root.size
	facts._read_components(root)
	root.queue_free()
	return facts

## Depth-first over the whole scene, because a component may sit under another
## component (the module scenes nest storages inside processors) and because
## `components` is not populated until the module is in a tree.
func _read_components(node: Node) -> void:
	var component: ComponentBase = node as ComponentBase
	if component != null:
		_read_one(component)
	for child: Node in node.get_children():
		_read_components(child)

func _read_one(component: ComponentBase) -> void:
	# SolarPowerComponent extends PowerGenerationComponent, so the generation
	# branch has to be tested before nothing in particular - it is caught here for
	# free rather than needing its own case.
	var generator: PowerGenerationComponent = component as PowerGenerationComponent
	if generator != null:
		power_output += maxf(generator.power_output, 0.0)
		return
	var consumer: PowerConsumptionComponent = component as PowerConsumptionComponent
	if consumer != null:
		power_draw += maxf(consumer.power_consumption, 0.0)
		return
	var storage: StorageComponent = component as StorageComponent
	if storage != null:
		if storage.include_in_stats:
			storage_capacity += maxi(storage.max_stored, 0)
		return
	var workspace: WorkspaceComponent = component as WorkspaceComponent
	if workspace != null:
		crew_slots += maxi(workspace.max_workers, 0)
		return
	var beds: SleepComponent = component as SleepComponent
	if beds != null:
		crew_slots += maxi(beds.capacity, 0)

## True when the module declares nothing worth a facts line. The panel hides the
## line rather than printing an empty one.
func is_empty() -> bool:
	return power_draw <= 0.0 and power_output <= 0.0 and storage_capacity <= 0 and crew_slots <= 0

## The formatted parts, ready for the row. The formatting rule itself lives in
## [BuildMenuModel] (pure and tested); this is only the hand-off.
func summary_parts() -> Array[String]:
	return BuildMenuModel.format_facts(power_draw, power_output, storage_capacity, crew_slots)
