class_name PawnBase
extends Node2D

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

var movement_component: PawnMovementComponent
var inventory_component: PawnInventoryComponent

var current_layer: WorldManager.StructureLayer = WorldManager.StructureLayer.SPACE
var path_position_override: Node2D = null
var traveling: bool = false
var next_point: int = 0
var current_job: JobBase = null:
	set(new_job):
		if new_job != current_job:
			current_job = new_job
			job_changed.emit()
			

## Jobs waiting for this specific pawn - chained followups (see
## JobBase.get_followup_job) and queued needs (see queue_job()) alike.
## Always checked before the shared board in start_job(), and never touched
## by other pawns or JobManager.
var job_queue: Array[JobBase] = []

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
	add_to_group("pawn")
	movement_component = PawnMovementComponent.new()
	movement_component.owner_pawn = self
	add_child(movement_component)
	inventory_component = PawnInventoryComponent.new()
	inventory_component.owner_pawn = self
	add_child(inventory_component)
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
		

func _process(delta: float) -> void:
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	job_length += sim_delta
	if current_job != null:
		if current_job.is_failed() or current_job.is_finished():
			_end_current_job()
		else:
			current_job.process_job(sim_delta)
	elif job_length > 1.0:
		# We don't want to try to start new jobs more than once a second, such as
		# if a job fails but then is posted and picked up again in rapid succession.
		# This keeps us from doing things like running pathfinding every frame.
		job_length = 0
		start_job()

func _end_current_job() -> void:
	var finished_job: JobBase = current_job
	current_job = null
	finished_job.end_job()
	# Intentionally don't start the next job immediately
		

func start_job() -> void:
	# If we have an inventory, try to store it ASAP
	if inventory_component != null and not inventory_component.is_empty():
		var return_job: Job_StoreInventory = Job_StoreInventory.new()
		if return_job.can_do_job(self):
			_begin_job(return_job)
			return
		# No storage will take what we're carrying right now — fall through and
		# look for a normal job anyway rather than stalling the pawn entirely.
	# Personal queue next - chained followups and queued needs. Checked once
	# here rather than polled every frame by whatever queued them.
	while not job_queue.is_empty():
		var queued_job: JobBase = job_queue.pop_front()
		if queued_job.is_valid() and queued_job.can_do_job(self):
			_begin_job(queued_job)
			return
		queued_job.cancel(true)
		queued_job.end_job()
	current_job = Global.job_manager.find_job(self)
	if current_job:
		current_job.start_job(self)
	else:
		# Wander!
		var idle_job: Job_IdleWander = Job_IdleWander.new()
		if idle_job.can_do_job(self):
			_begin_job(idle_job)
		else:
			# Can't even move anywhere, idle pose
			if animated_sprite != null:
				animated_sprite.play("idle")

func _begin_job(job: JobBase) -> void:
	current_job = job
	current_job.start_job(self)

## Adds a job to this pawn's personal queue, checked in start_job() ahead of
## the shared board. Use this for queued needs - queue once when the need
## arises instead of polling can_do_job() every frame. to_front = true jumps
## ahead of anything already queued (what chained followup jobs use) but
## still waits for the current job to finish - see interrupt_with_job() to
## preempt immediately instead.
func queue_job(job: JobBase, to_front: bool = false) -> void:
	if to_front:
		job_queue.push_front(job)
	else:
		job_queue.push_back(job)

## Ends the current job right now - gracefully, not as a failure, so
## anything the pawn is carrying is left for Job_StoreInventory to sweep up
## afterward instead of lost - and starts new_job immediately. For needs
## that can't wait, e.g. a pawn about to collapse from hunger.
func interrupt_with_job(new_job: JobBase) -> void:
	if current_job != null:
		var interrupted: JobBase = current_job
		current_job = null
		interrupted.cancel(false)
		interrupted.end_job()
	job_length = 0
	_begin_job(new_job)


#func _exit_tree() -> void:
	#Global.path_manager.remove_vertex(self)
	#if current_job != null:
		#current_job.cancel(true)
		#current_job = null
		
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(Global.path_manager):
			Global.path_manager.remove_vertex(self)
		if current_job != null:
			current_job.cancel(true)
			current_job = null
		# TODO: We don't have pawn death in any meaningful way yet, so just conclude
		# if we're being destroyed, dump our inventory. Skipped during game
		# teardown (managers already gone) and when there's nothing to dump.
		if not is_instance_valid(inventory_component) or inventory_component.is_empty():
			return
		if not is_instance_valid(Global.world_manager) or not is_instance_valid(Global.world_manager.pawn_layer):
			return
		var pile := ResourcePile.spawn(Global.world_manager.pawn_layer, global_position, current_module)
		inventory_component.dump_all_to_pile(pile)

func move_to(new_pos: Vector2) -> void:
	if animated_sprite != null:
		if position.x == new_pos.x:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("walk")
			animated_sprite.flip_h = new_pos.x < position.x
			animated_sprite.rotation_degrees = abs(animated_sprite.rotation_degrees) * (-1 if animated_sprite.flip_h else 1)
	if global_position.distance_to(new_pos) > 100.0:
		pass
	global_position = new_pos

func set_idle() -> void:
	animated_sprite.play("idle")

func _on_module_changed(new_module: ModuleBase) -> void:
	if current_module != new_module:
		current_module = new_module
		if new_module == null:
			if current_layer != WorldManager.StructureLayer.SPACE:
				current_layer = WorldManager.StructureLayer.SPACE
				reparent(Global.world_manager.get_canvas_for_layer(current_layer))
			Global.path_manager.change_vertex_group(self, "space", -1)
			animated_sprite.rotation_degrees = 90
		else:
			Global.path_manager.change_vertex_group(self, "", -1)
			animated_sprite.rotation_degrees = 0
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
