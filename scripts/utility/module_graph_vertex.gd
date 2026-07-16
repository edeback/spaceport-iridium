class_name ModuleGraphVertex
extends RefCounted

class EdgeData:
	var cost: float = 0
	var data: StringName = ""

var node: Node2D = null
var edges: Dictionary[ModuleGraphVertex, EdgeData]
var subgraph: int
var blocked: bool = false
var group: StringName = ""
# When going to this group, what index in the path component counts as the "door"?
var group_door: int = 0
## Still a physical member of its group (cabs pass through) but never a valid
## boarding/alighting point for the implicit group jump - a turbolift floor
## that's been toggled off. Checked in both group-expansion loops AND in
## subgraph flooding, so is_reachable stays honest about it.
var no_group_stop: bool = false
## Exterior/unfinished: part of the implicit "open space" clique (blueprints,
## deconstruction sites, pawns on EVA, space-door nodes). Orthogonal to group -
## a vertex can be in a network group and exterior at once (WI-15).
var is_exterior: bool = false
# When entering this module from open space, what index in the path component
# counts as the "door"? Mirrors group_door for the exterior clique.
var exterior_door: int = 0
## If endpoint, never try to path through this. Generally only valid for non-module entities
var endpoint: bool = false

func add_edge(destination: ModuleGraphVertex, cost: float, data: StringName = "") -> void:
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
