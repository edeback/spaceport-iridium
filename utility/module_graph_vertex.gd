class_name ModuleGraphVertex
extends Object

class EdgeData:
	var cost: float = 0
	var data: Variant

var node: Node2D = null
var edges: Dictionary[ModuleGraphVertex, EdgeData]
var subgraph: int
var blocked: bool = false
var group: StringName = ""
## If endpoint, never try to path through this. Generally only valid for non-module entities
var endpoint: bool = false

func add_edge(destination: ModuleGraphVertex, cost: float, data: Variant = null) -> void:
	var new_edge:EdgeData = EdgeData.new()
	new_edge.cost = cost
	new_edge.data = data
	edges[destination] = new_edge

func dist_squared_to(other_vertex: ModuleGraphVertex) -> float:
	if is_instance_valid(node) and is_instance_valid(other_vertex.node):
		return node.global_position.distance_squared_to(other_vertex.node.global_position)
	return 99999999

func dist_to(other_vertex: ModuleGraphVertex) -> float:
	if is_instance_valid(node) and is_instance_valid(other_vertex.node):
		return node.global_position.distance_to(other_vertex.node.global_position)
	return 99999999
