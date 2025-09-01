class_name ModuleGraphVertex
extends Object

var module: ModuleBase
var location: Vector2
var edges: Dictionary[ModuleGraphVertex, float]
var subgraph: int

func dist_squared_to(other_vertex: ModuleGraphVertex) -> float:
	return location.distance_squared_to(other_vertex.location)

func dist_to(other_vertex: ModuleGraphVertex) -> float:
	return location.distance_to(other_vertex.location)
