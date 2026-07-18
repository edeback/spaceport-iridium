extends GutTest

## Unit tests for ModuleGraph (scripts/utility/module_graph.gd) - the pawn/
## structure traversal graph. Highest-risk pure logic in the game (WI-20/24/32
## all lean on reachability), so this suite pins down subgraph maintenance,
## implicit group cliques, the exterior clique, and cost multipliers.
##
## Vertices are plain Node2D stand-ins for modules; the graph never inspects
## anything but identity/position for these paths, and get_vertex_for_path only
## special-cases PawnBase (which we don't use here).

var graph: ModuleGraph

func before_each() -> void:
	graph = ModuleGraph.new()

## A throwaway Node2D vertex, named for readable path/debug output and freed at
## end of test so nothing leaks.
func _vertex(vertex_name: String = "v") -> Node2D:
	var node := Node2D.new()
	node.name = vertex_name
	autofree(node)
	return node

# --- subgraph ids & reachability ---------------------------------------------

func test_same_vertex_is_reachable_from_itself() -> void:
	var a := _vertex("a")
	graph.add_vertex(a)
	assert_true(graph.is_reachable(a, a), "a vertex always reaches itself")

func test_disconnected_vertices_are_not_reachable() -> void:
	var a := _vertex("a")
	var b := _vertex("b")
	graph.add_vertex(a)
	graph.add_vertex(b)
	assert_false(graph.is_reachable(a, b), "two islands with no edge/group are unreachable")

func test_edge_makes_two_vertices_reachable() -> void:
	var a := _vertex("a")
	var b := _vertex("b")
	graph.add_vertex(a)
	graph.add_vertex(b)
	assert_true(graph.add_edge(a, b, 1.0), "add_edge succeeds when both vertices exist")
	assert_true(graph.is_reachable(a, b), "an edge joins the two subgraphs")

func test_reachability_is_transitive_across_a_chain() -> void:
	var a := _vertex("a")
	var b := _vertex("b")
	var c := _vertex("c")
	graph.add_vertex(a)
	graph.add_vertex(b)
	graph.add_vertex(c)
	graph.add_edge(a, b, 1.0)
	graph.add_edge(b, c, 1.0)
	assert_true(graph.is_reachable(a, c), "a->b->c chain leaves a and c in one subgraph")

func test_removing_an_edge_splits_the_subgraph() -> void:
	var a := _vertex("a")
	var b := _vertex("b")
	var c := _vertex("c")
	graph.add_vertex(a)
	graph.add_vertex(b)
	graph.add_vertex(c)
	graph.add_edge(a, b, 1.0)
	graph.add_edge(b, c, 1.0)
	assert_true(graph.remove_edge(b, c), "remove_edge succeeds for an existing edge")
	# remove_edge marks dirty; is_reachable flushes and rebuilds subgraphs.
	assert_true(graph.is_reachable(a, b), "a and b stay connected")
	assert_false(graph.is_reachable(a, c), "c is cut off once b-c is gone")

func test_add_edge_to_missing_vertex_fails() -> void:
	var a := _vertex("a")
	var ghost := _vertex("ghost")
	graph.add_vertex(a)
	assert_false(graph.add_edge(a, ghost, 1.0), "edge to an unregistered vertex is rejected")

# --- implicit group cliques --------------------------------------------------

func test_group_members_are_implicitly_reachable_without_an_edge() -> void:
	var a := _vertex("a")
	var b := _vertex("b")
	graph.add_vertex(a, false, &"shaft")
	graph.add_vertex(b, false, &"shaft")
	assert_true(graph.is_reachable(a, b), "same-group vertices form an implicit clique")

func test_group_bridges_two_separate_edge_islands() -> void:
	# Island 1: a--b(group), Island 2: c(group)--d. b and c share a group, so
	# every member ends up in one subgraph even though no edge crosses over.
	var a := _vertex("a")
	var b := _vertex("b")
	var c := _vertex("c")
	var d := _vertex("d")
	graph.add_vertex(a)
	graph.add_vertex(b, false, &"g")
	graph.add_vertex(c, false, &"g")
	graph.add_vertex(d)
	graph.add_edge(a, b, 1.0)
	graph.add_edge(c, d, 1.0)
	assert_true(graph.is_reachable(a, d), "the shared group joins both islands")

func test_no_group_stop_vertex_leaves_the_group_clique() -> void:
	var a := _vertex("a")
	var b := _vertex("b")
	graph.add_vertex(a, false, &"g")
	graph.add_vertex(b, false, &"g")
	assert_true(graph.is_reachable(a, b), "grouped and initially reachable")
	# A disabled turbolift floor is still a physical group member but never a
	# boarding/alighting point - with no real edge, b becomes unreachable.
	assert_true(graph.set_vertex_no_group_stop(b, true), "flag actually changed")
	assert_false(graph.is_reachable(a, b), "no_group_stop b no longer rides the group jump")

func test_change_vertex_group_reconnects_reachability() -> void:
	var a := _vertex("a")
	var b := _vertex("b")
	graph.add_vertex(a, false, &"left")
	graph.add_vertex(b, false, &"right")
	assert_false(graph.is_reachable(a, b), "different groups, no edge -> unreachable")
	graph.change_vertex_group(b, &"left")
	assert_true(graph.is_reachable(a, b), "moving b into a's group joins them")

# --- group cost multipliers --------------------------------------------------

func test_group_multiple_defaults_to_one() -> void:
	assert_eq(graph.get_group_multiple(&"never_set"), 1.0, "unset groups cost 1x")

func test_group_multiple_round_trips() -> void:
	graph.set_group_multiple(&"expensive", 2.5)
	assert_eq(graph.get_group_multiple(&"expensive"), 2.5, "set value is read back")

# --- exterior ("open space") clique ------------------------------------------

func test_exterior_vertices_share_the_exterior_subgraph() -> void:
	var a := _vertex("a")
	var b := _vertex("b")
	graph.add_vertex(a, false, &"", 0, true)
	graph.add_vertex(b, false, &"", 0, true)
	assert_true(graph.is_reachable(a, b), "exterior vertices form the space clique")
	assert_true(graph.is_space_reachable(a), "a can reach open space")
	assert_true(graph.is_space_reachable(b), "so can b - is_space_reachable checks membership in the exterior subgraph")
	assert_ne(graph.get_exterior_subgraph(), -1, "the exterior subgraph has a real id")

func test_space_unreachable_from_interior_only_vertex() -> void:
	var interior := _vertex("interior")
	var airlock := _vertex("airlock")
	graph.add_vertex(interior)
	graph.add_vertex(airlock, false, &"", 0, true)
	assert_false(graph.is_space_reachable(interior), "an unconnected interior cell can't reach space")

func test_no_exterior_reports_negative_subgraph() -> void:
	var a := _vertex("a")
	graph.add_vertex(a)
	assert_eq(graph.get_exterior_subgraph(), -1, "no exterior vertices -> -1 sentinel")
	assert_false(graph.is_space_reachable(a), "and space is unreachable")

func test_set_vertex_exterior_joins_and_leaves_the_clique() -> void:
	var a := _vertex("a")
	var b := _vertex("b")
	graph.add_vertex(a, false, &"", 0, true)
	graph.add_vertex(b)
	assert_false(graph.is_space_reachable(b), "b starts interior-only")
	assert_true(graph.set_vertex_exterior(b, true), "flag flips to exterior")
	assert_true(graph.is_space_reachable(b), "now b is in the space clique")
	assert_true(graph.set_vertex_exterior(b, false), "flag flips back")
	assert_false(graph.is_space_reachable(b), "and it leaves the clique again")

# --- pathfinding smoke -------------------------------------------------------

func test_pathfind_returns_endpoints_in_order() -> void:
	var a := _vertex("a")
	var b := _vertex("b")
	var c := _vertex("c")
	graph.add_vertex(a)
	graph.add_vertex(b)
	graph.add_vertex(c)
	graph.add_edge(a, b, 1.0)
	graph.add_edge(b, c, 1.0)
	var path: Array[ModuleGraph.PathPoint] = graph.pathfind(a, c)
	assert_eq(path.size(), 3, "a-b-c yields a three-node path")
	if path.size() == 3:
		assert_eq(path[0].node, a, "path starts at a")
		assert_eq(path[path.size() - 1].node, c, "path ends at c")

func test_pathfind_between_disconnected_vertices_is_empty() -> void:
	var a := _vertex("a")
	var b := _vertex("b")
	graph.add_vertex(a)
	graph.add_vertex(b)
	assert_eq(graph.pathfind(a, b).size(), 0, "no route -> empty path")
