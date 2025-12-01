class_name PawnBase
extends Node2D

@export var cell: Vector2i
@export var current_module: ModuleBase
@export var destination_cell: Vector2i
@export var destination_module: ModuleBase
@export var path: PackedVector2Array
@export var speed: float = 120.0
@export var carrying_capacity: int = 10

var traveling: bool = false
var next_point: int = 0
var current_job: JobBase = null
var job_mine_asteroid: Job_MineAsteroid = null

var job_length: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SignalBus.module_selected.connect(_on_module_selected)
	pass # Replace with function body.

func start_job() -> void:
	current_job = Global.job_manager.get_job()
	if current_job:
		current_job.start_job(self)
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

func _on_module_selected(selected_module: ModuleBase):
	destination_module = selected_module
	current_module = Global.path_manager.get_closest_module_by_position(position)
	path = Global.path_manager.run_pathfinding(current_module, destination_module)
	next_point = 0
	traveling = true
	pass

#func _find_next_job() -> void:
	#if current_job == null:
		#current_job = Global.job_manager.find_job()
	#pass
