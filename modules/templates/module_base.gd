@tool
class_name ModuleBase
extends ObjectBase

@export var sprite: Sprite2D
@onready var footprint: Area2D = $Offset/Footprint
@onready var nameplate: Label = $Offset/Sprite/Nameplate
@export var replacement_on_delete: ModuleData

@export var size: Vector2i = Vector2i(1, 1)
@export var show_debug: bool = true:
	set(new_show_debug):
		show_debug = new_show_debug
		queue_redraw()
		
@export var blocks_building: bool = true
@export var can_delete: bool = true
## Whether this module holds a breathable atmosphere when built (WI-17).
## AtmosphereManager attaches an AtmosphereComponent to modules that have a
## PathComponent on a non-SPACE layer AND this flag. Set false for structures
## pawns traverse but that hold no air (truss).
@export var has_atmosphere: bool = true
@export var structure_check_before_delete: bool = true
@export var add_to_groups: Array[StringName] = []

@export var offset: Node2D

var module_id: int = -1
var module_cell: Vector2i
var module_data: ModuleData
var is_horizontal: bool = true
## Whether this instance was placed flipped (the flipped_scene variant).
## Set by WorldManager.add_module; needed so save/load can re-place it.
var flipped: bool = false
enum BuildState { Preview, Blueprint, Built }
var build_state: BuildState = BuildState.Preview

## Lazily created - null whenever there's no overflow/dumped material
## sitting in this module. See get_or_create_overflow_pile().
var overflow_pile: ResourcePile = null


var _cached_path_component: PathComponent = null
var _cached_structure_component: StructureComponent = null

## Runtime stat-modifier layer. Components read effective stats through
## get_effective_stat() so local/global upgrades apply non-destructively.
var stat_modifiers: StatModifiers = StatModifiers.new()

## Per-instance local upgrade tiers (upgrade -> times purchased). This is the
## state that makes two modules of the same type differ.
var local_upgrade_tiers: Dictionary[LocalUpgradeData, int] = {}


const SHADER_PARAM_PREVIEW = "PREVIEW"
const SHADER_PARAM_PLACEABLE = "PLACEABLE"
const SHADER_PARAM_SELECTED = "SELECTED"
const SHADER_PARAM_PROGRESS = "PROGRESS"

var previewing: bool = false:
	get:
		return previewing
	set(new_value):
		previewing = new_value
		_update_shader()

var can_place: bool = true:
	get:
		return can_place
	set(new_value):
		if can_place != new_value:
			can_place = new_value
			_update_shader()
			
var selected: bool = false:
	get:
		return selected
	set(new_value):
		if selected != new_value:
			selected = new_value
			_update_shader()
			SignalBus.module_selected.emit(self)
			
var progress: float = 1.0:
	set(new_value):
		new_value = clamp(new_value, 0.0, 1.0)
		if new_value != progress:
			progress = new_value
			_update_shader()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if (sprite && sprite.material != null):
		sprite.material = sprite.material.duplicate()
	_update_shader()
	if module_data != null:
		nameplate.text = module_data.name
	elif nameplate != null:
		nameplate.text = ""
	add_to_group("module")
	for group_name: StringName in add_to_groups:
		add_to_group(group_name)
	if SignalBus.is_node_ready():
		SignalBus.module_added.emit(self)
	on_place()
	
func ready_preview() -> void:
	build_state = BuildState.Preview
	for component: ComponentBase in components:
		component.ready_preview()

func ready_blueprint() -> void:
	build_state = BuildState.Blueprint
	if module_data.instant_build:
		# Don't bother with blueprint if we're instant
		ready_constructed()
		return
	for component: ComponentBase in components:
		component.ready_blueprint()
	
func ready_constructed() -> void:
	build_state = BuildState.Built
	# Pull in any global (module-type-wide) stat modifiers unlocked so far.
	if Global.unlock_manager != null:
		Global.unlock_manager.apply_global_modifiers(self)
	for component: ComponentBase in components:
		component.ready_constructed()
	make_connections()

func is_complete() -> bool:
	return build_state == BuildState.Built

## Apply this module's active stat modifiers (from local/global upgrades) to a
## component's base value. Components should route their tunable @export stats
## through here rather than reading the raw value directly.
func get_effective_stat(stat: StringName, base: float) -> float:
	return stat_modifiers.get_effective(stat, base)

# --- local (per-instance) upgrades ---------------------------------------

func get_local_upgrade_tier(upgrade: LocalUpgradeData) -> int:
	return local_upgrade_tiers.get(upgrade, 0)

## True if the next tier of this upgrade can be purchased on this module right
## now (type matches, globally unlocked, tier remaining, prereqs met, affordable).
func can_apply_local_upgrade(upgrade: LocalUpgradeData) -> bool:
	if upgrade == null:
		return false
	if not upgrade.matches_module(module_data):
		return false
	if not upgrade.is_globally_unlocked():
		return false
	if get_local_upgrade_tier(upgrade) >= upgrade.max_tiers:
		return false
	for prereq: LocalUpgradeData in upgrade.prerequisites:
		if get_local_upgrade_tier(prereq) < 1:
			return false
	return upgrade.can_afford(get_local_upgrade_tier(upgrade))

## Purchase the next tier: spend its (tier-scaled) cost and stack its modifiers.
func try_apply_local_upgrade(upgrade: LocalUpgradeData) -> bool:
	if not can_apply_local_upgrade(upgrade):
		return false
	var tier: int = get_local_upgrade_tier(upgrade)
	upgrade.withdraw_cost(tier)
	local_upgrade_tiers[upgrade] = tier + 1
	for spec: StatModifierSpec in upgrade.modifiers:
		stat_modifiers.add_modifier(spec.stat, spec.op, spec.value, upgrade.id)
	SignalBus.module_upgraded.emit(self)
	return true

## Serialize this module's local upgrade tiers (upgrade id -> tier count) for a
## save file. Fold this into whatever per-module save data the game persists.
func get_upgrade_save_data() -> Dictionary:
	var data: Dictionary = {}
	for upgrade: LocalUpgradeData in local_upgrade_tiers:
		data[String(upgrade.id)] = local_upgrade_tiers[upgrade]
	return data

## Full per-instance save data: placement, build state, and component state
## (construction progress, storage contents keyed by component path, upgrade
## tiers). WorldManager's world section aggregates these.
func get_save_data() -> Dictionary:
	var data: Dictionary = {
		"id": String(module_data.id),
		"cell": [module_cell.x, module_cell.y],
		"horizontal": is_horizontal,
		"flipped": flipped,
		"built": is_complete(),
	}
	var construction: ConstructionComponent = get_component_by_type(ConstructionComponent) as ConstructionComponent
	if construction != null:
		data["construction"] = construction.get_save_data()
	var storages: Dictionary = {}
	for component: ComponentBase in components:
		if component is StorageComponent:
			var storage_save: Dictionary = (component as StorageComponent).get_save_data()
			if not storage_save.is_empty():
				storages[String(get_path_to(component))] = storage_save
	if not storages.is_empty():
		data["storage"] = storages
	var trade: TradeComponent = get_component_by_type(TradeComponent) as TradeComponent
	if trade != null:
		var trade_save: Dictionary = trade.get_save_data()
		if not trade_save.is_empty():
			data["trade"] = trade_save
	var processor: ProcessorComponent = get_component_by_type(ProcessorComponent) as ProcessorComponent
	if processor != null:
		var processor_save: Dictionary = processor.get_save_data()
		if not processor_save.is_empty():
			data["processor"] = processor_save
	var atmosphere: AtmosphereComponent = get_component_by_type(AtmosphereComponent) as AtmosphereComponent
	if atmosphere != null:
		data["atmosphere"] = atmosphere.get_save_data()
	var o2_generator: OxygenGeneratorComponent = get_component_by_type(OxygenGeneratorComponent) as OxygenGeneratorComponent
	if o2_generator != null:
		var generator_save: Dictionary = o2_generator.get_save_data()
		if not generator_save.is_empty():
			data["o2_generator"] = generator_save
	var upgrades: Dictionary = get_upgrade_save_data()
	if not upgrades.is_empty():
		data["upgrades"] = upgrades
	return data

## Restore per-instance state. Call AFTER the ready pass (ready_constructed /
## ready_blueprint) so components have done their normal state setup first.
## Construction before storage: the deconstructed path reconfigures the
## material storage, and the storage section then restores actual contents.
func load_save_data(data: Dictionary) -> void:
	var construction: ConstructionComponent = get_component_by_type(ConstructionComponent) as ConstructionComponent
	if construction != null and data.has("construction"):
		construction.load_save_data(data["construction"])
	# Processor before storage: restoring the selected recipe reconfigures the
	# input/output slots, and the storage section then restores actual
	# contents on top of that configuration.
	var processor: ProcessorComponent = get_component_by_type(ProcessorComponent) as ProcessorComponent
	if processor != null and data.has("processor"):
		processor.load_save_data(data["processor"])
	var storages: Dictionary = data.get("storage", {})
	for path_str: String in storages:
		var storage: StorageComponent = get_node_or_null(NodePath(path_str)) as StorageComponent
		if storage == null:
			push_warning("Saved storage component not found on " + name + ": " + path_str)
			continue
		storage.load_save_data(storages[path_str])
	var trade: TradeComponent = get_component_by_type(TradeComponent) as TradeComponent
	if trade != null and data.has("trade"):
		trade.load_save_data(data["trade"])
	var atmosphere: AtmosphereComponent = get_component_by_type(AtmosphereComponent) as AtmosphereComponent
	if atmosphere != null and data.has("atmosphere"):
		atmosphere.load_save_data(data["atmosphere"])
	var o2_generator: OxygenGeneratorComponent = get_component_by_type(OxygenGeneratorComponent) as OxygenGeneratorComponent
	if o2_generator != null and data.has("o2_generator"):
		o2_generator.load_save_data(data["o2_generator"])
	load_upgrade_save_data(data.get("upgrades", {}))

## Restore tiers saved by get_upgrade_save_data() and re-apply their modifiers,
## exactly as if each tier had been purchased. Call after module_data is set.
func load_upgrade_save_data(data: Dictionary) -> void:
	for id_str: String in data:
		var upgrade := Global.unlock_manager.get_local_upgrade_by_id(StringName(id_str))
		if upgrade == null:
			push_warning("Unknown local upgrade id in save, skipping: " + id_str)
			continue
		var tier: int = int(data[id_str])
		local_upgrade_tiers[upgrade] = tier
		for i in tier:
			for spec: StatModifierSpec in upgrade.modifiers:
				stat_modifiers.add_modifier(spec.stat, spec.op, spec.value, upgrade.id)

func on_place() -> void:
	if get_structure_component() != null and module_data.interaction_layer == WorldManager.StructureLayer.MODULE:
		var cells: Array[Vector2i] = []
		for internal_point: Vector2i in get_structure_component().internal_points:
			cells.append(module_cell + internal_point)
		Global.tilemap.set_cells_terrain_connect(cells, 0, 0)
	pass
	
func pre_delete() -> void:
	_eject_stored_resources_as_debris()

func _eject_stored_resources_as_debris() -> void:
	for component: ComponentBase in components:
		if component is StorageComponent:
			var storage := component as StorageComponent
			if not storage.is_empty():
				storage.dump_all_to_pile(get_or_create_overflow_pile())
	if is_instance_valid(overflow_pile):
		# The module's gone - whatever's left is just floating where the
		# module used to be, not "in" anything anymore.
		overflow_pile.parent_module = null

func on_select(new_selected: bool) -> void:
	self.selected = new_selected
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#if previewing:
		#can_place = _check_if_placeable()
	#else:
		#can_place = true
	#pass
	
#func _physics_process(delta: float) -> void:
#	pass
	
func _update_shader() -> void:
	if (get_sprite() && get_sprite().material != null):
		get_sprite().material.set_shader_parameter(SHADER_PARAM_PREVIEW, previewing)
		get_sprite().material.set_shader_parameter(SHADER_PARAM_PLACEABLE, can_place)
		get_sprite().material.set_shader_parameter(SHADER_PARAM_SELECTED, selected)
		get_sprite().material.set_shader_parameter(SHADER_PARAM_PROGRESS, progress)
		
func get_path_component() -> PathComponent:
	if _cached_path_component:
		return _cached_path_component
	_cached_path_component = get_node_or_null("PathComponent")
	return _cached_path_component

func get_structure_component() -> StructureComponent:
	if _cached_structure_component:
		return _cached_structure_component
	_cached_structure_component = get_node_or_null("StructureComponent")
	return _cached_structure_component
	
func make_connections() -> void:
	if get_path_component() != null:
		get_path_component().make_connections()
	if get_structure_component() != null:
		get_structure_component().make_connections()

func remove_connections() -> void:
	if get_path_component() != null:
		get_path_component().remove_connections()
	if get_structure_component() != null:
		get_structure_component().remove_connections()
	
func get_global_center() -> Vector2:
	return global_position + Vector2(Global.CELL_SIZE * size) / 2
	
func enter_module_from(pawn: PawnBase, _prev_module: ModuleBase = null) -> void:
	# Exterior modules (blueprints, deconstruction sites) have no "inside" yet.
	if not Global.path_manager.is_exterior(self):
		pawn.current_module = self
	else:
		pawn.current_module = null
	
func get_sprite() -> Sprite2D:
	return sprite

## True if this overlap requires us to cancel a build
func overlap_module(_new_module: ModuleData, _is_horizontal: bool) -> bool:
	return true
	
func has_custom_pathing() -> bool:
	var pc := get_path_component()
	return pc != null and (not pc.door_behaviors.is_empty() or not pc.edge_behaviors.is_empty())
	
func traverse(pawn: PawnBase, edge: PathComponent.PathTraversalEdgeData) -> void:
	var pc := get_path_component()
	var behavior := pc.get_edge_behavior(edge)
	if behavior:
		await behavior.on_traverse(pawn, edge, self, pc.get_behavior_state(behavior))

func path_enter(pawn: PawnBase, door: int, meta: StringName, next_node: Node2D, cancel_signal: Signal) -> void:
	var pc := get_path_component()
	var behavior: PathBehavior = pc.door_behaviors.get(door)
	if behavior:
		await behavior.on_enter(pawn, door, meta, self, next_node, pc.get_behavior_state(behavior))

func path_exit(pawn: PawnBase, door: int, meta: StringName, next_node: Node2D, cancel_signal: Signal) -> void:
	var pc := get_path_component()
	var behavior: PathBehavior = pc.door_behaviors.get(door)
	if behavior:
		var ctx := PathBehaviorContext.new()
		ctx.next_node = next_node
		ctx.state = pc.get_behavior_state(behavior)
		ctx.cancelled = cancel_signal
		await behavior.on_exit(pawn, door, meta, self, ctx)
	
func get_or_create_overflow_pile() -> ResourcePile:
	if not is_instance_valid(overflow_pile):
		var spawn_pos: Vector2 = get_random_position_on_module() if get_structure_component() != null else global_position
		overflow_pile = ResourcePile.spawn(get_parent(), spawn_pos, self)
		overflow_pile.despawning.connect(func() -> void: overflow_pile = null)
	return overflow_pile

func show_label() -> void:
	if nameplate != null:
		nameplate.visible = true

func hide_label() -> void:
	if nameplate != null:
		nameplate.visible = false

func get_random_position_on_module() -> Vector2:
	return global_position + Vector2(get_structure_component().internal_points.pick_random() * Global.CELL_SIZE) + Global.CELL_SIZE * 0.15 + Vector2(randf() * Global.CELL_SIZE.x, randf() * Global.CELL_SIZE.y) * 0.7

func _on_footprint_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		#if sprite.is_pixel_opaque(sprite.to_local(get_global_mouse_position())):
			#print("clicked " + module_data.name)
			if event.is_action_pressed("build"):
					get_viewport().set_input_as_handled()
					# Routed through UIMain's click arbiter: stacked footprints
					# (corridor/turbolift/module on one cell) all receive this
					# event, and repeated clicks cycle the stack (WI-10).
					Global.ui_main.module_clicked(self)
			if event.is_action_pressed("remove"):
				get_viewport().set_input_as_handled()
				Global.world_manager.remove_module(self)
