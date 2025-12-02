class_name ModuleGraphVertex
extends Object

class EdgeData:
	var cost: float = 0
	var data: Variant

var module: ModuleBase
var location: Vector2
var edges: Dictionary[ModuleGraphVertex, EdgeData]
var subgraph: int
var blocked: bool = false

func add_edge(destination: ModuleGraphVertex, cost: float, data: Variant = null) -> void:
	var new_edge:EdgeData = EdgeData.new()
	new_edge.cost = cost
	new_edge.data = data
	edges[destination] = new_edge

func dist_squared_to(other_vertex: ModuleGraphVertex) -> float:
	return location.distance_squared_to(other_vertex.location)

func dist_to(other_vertex: ModuleGraphVertex) -> float:
	return location.distance_to(other_vertex.location)
