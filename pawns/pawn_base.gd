class_name PawnBase
extends Node2D

@export var cell: Vector2i
@export var current_module: ModuleBase:
	set = _on_module_changed
@export var destination_cell: Vector2i
@export var destination_module: ModuleBase
@export var path: PackedVector2Array
@export var speed: float = 80.0
@export var carrying_capacity: int = 10
@export var animated_sprite: AnimatedSprite2D
@export var pawn_name: String = ""
@export var collision: Area2D

var current_layer: WorldManager.StructureLayer = WorldManager.StructureLayer.SPACE
var traveling: bool = false
var next_point: int = 0
var current_job: JobBase = null:
	set(new_job):
		if new_job != current_job:
			current_job = new_job
			job_changed.emit()
			
var job_mine_asteroid: Job_MineAsteroid = null

var job_length: float = 0

var components: Array[PawnComponentBase] = []

signal job_changed

func get_component_by_type(type: Variant) -> PawnComponentBase:
	for component: PawnComponentBase in components:
		if is_instance_of(component, type):
			return component
	return null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.path_manager.add_vertex(self, true, "" if current_module != null else "space")
	SignalBus.module_removed.connect(_on_module_removed)
	#SignalBus.module_selected.connect(_on_module_selected)
	pass # Replace with function body.
	

func _on_module_removed(module: ModuleBase) -> void:
	if current_module == module:
		current_module = null

func try_start_job(new_job: JobBase) -> bool:
	if current_job == null and new_job.can_do_job(self):
		current_job = new_job
		current_job.start_job(self)
		return true
	return false
		

func start_job() -> void:
	current_job = Global.job_manager.find_job(self)
	if current_job:
		current_job.start_job(self)
	else:
		# Wander!
		var idle_job: Job_IdleWander = Job_IdleWander.new()
		if idle_job.can_do_job(self):
			current_job = idle_job
			current_job.start_job(self)
		else:
			# Can't even move anywhere, idle pose
			if animated_sprite != null:
				animated_sprite.play("idle")
		
	#var processors: Array[Node] = get_tree().get_nodes_in_group("processor")
	#if processors.size() > 0:
		#job_mine_asteroid = Job_MineAsteroid.new()
		#var processor_component: ComponentBase = processors.pick_random() as ComponentBase
		#job_mine_asteroid.setup(processor_component.owner_module, self)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	job_length += delta
	if current_job != null:
		if current_job.is_failed() or current_job.is_finished():
			current_job.end_job()
			current_job = null
		else:
			current_job.process_job(delta)
	elif job_length > 1.0:
		job_length = 0
		start_job()
	#if traveling:
		#var dist_to_travel: float = speed * delta
		#var next_position: Vector2 = position
		#while dist_to_travel > 0:
			#if next_point >= path.size():
				#break
			#var next_point_position = path[next_point] * Vector2(Global.CELL_SIZE) + Vector2(32, 32)
			#var travel_vector: Vector2 = next_point_position - next_position
			#var dist_to_next_point = travel_vector.length()
			#if dist_to_next_point <= dist_to_travel:
				#next_position = next_point_position
				#dist_to_travel -= dist_to_next_point
				#next_point += 1
			#else:
				#next_position = position + travel_vector.normalized() * dist_to_travel
				#dist_to_travel = 0
				#break
		#if next_position == position:
			## We didn't move, we're done here
			#traveling = false
		#else:
			#position = next_position
				#
		#
	pass

#func _on_module_selected(selected_module: ModuleBase):
	#destination_module = selected_module
	#current_module = Global.path_manager.get_closest_module_by_position(position)
	#path = Global.path_manager.run_pathfinding(current_module, destination_module)
	#next_point = 0
	#traveling = true
	#pass

#func _exit_tree() -> void:
	#Global.path_manager.remove_vertex(self)
	#if current_job != null:
		#current_job.cancel(true)
		#current_job = null
		
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		Global.path_manager.remove_vertex(self)
		if current_job != null:
			current_job.cancel(true)
			current_job = null

func move_to(new_pos: Vector2) -> void:
	if animated_sprite != null:
		if position == new_pos:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("walk")
			animated_sprite.flip_h = new_pos.x < position.x
	position = new_pos

func _on_module_changed(new_module: ModuleBase) -> void:
	current_module = new_module
	if new_module == null:
		if current_layer != WorldManager.StructureLayer.SPACE:
			current_layer = WorldManager.StructureLayer.SPACE
			reparent(Global.world_manager.get_canvas_for_layer(current_layer))
		Global.path_manager.graph.change_vertex_group(self, "space")
	else:
		Global.path_manager.graph.change_vertex_group(self, "")
		if current_layer != new_module.module_data.interaction_layer:
			current_layer = new_module.module_data.interaction_layer
			reparent(Global.world_manager.get_canvas_for_layer(current_layer))

#func _find_next_job() -> void:
	#if current_job == null:
		#current_job = Global.job_manager.find_job()
	#pass


func _on_collision_clicked(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event.is_action_pressed("build"):
		get_viewport().set_input_as_handled()
		Global.ui_main.pawn_clicked(self)
