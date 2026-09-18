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

# --- cut-vertex / would_removal_split ----------------------------------------

func test_isolated_vertex_removal_never_splits() -> void:
	var a := _vertex("a")
	graph.add_vertex(a)
	assert_false(graph.would_removal_split(a), "a vertex with no edges only detaches itself")

func test_leaf_removal_never_splits() -> void:
	# a--b--c: removing the leaf c leaves a and b connected.
	var a := _vertex("a")
	var b := _vertex("b")
	var c := _vertex("c")
	graph.add_vertex(a)
	graph.add_vertex(b)
	graph.add_vertex(c)
	graph.add_edge(a, b, 1.0)
	graph.add_edge(b, c, 1.0)
	assert_false(graph.would_removal_split(c), "a leaf's removal can't disconnect anything")

func test_bridge_vertex_removal_splits() -> void:
	# a--b--c: b is the only link between a and c, so removing it splits them.
	var a := _vertex("a")
	var b := _vertex("b")
	var c := _vertex("c")
	graph.add_vertex(a)
	graph.add_vertex(b)
	graph.add_vertex(c)
	graph.add_edge(a, b, 1.0)
	graph.add_edge(b, c, 1.0)
	assert_true(graph.would_removal_split(b), "removing the middle of a chain splits the ends apart")

func test_redundant_vertex_in_a_cycle_does_not_split() -> void:
	# Triangle a-b-c: every vertex has a bypass, so none is a cut vertex.
	var a := _vertex("a")
	var b := _vertex("b")
	var c := _vertex("c")
	graph.add_vertex(a)
	graph.add_vertex(b)
	graph.add_vertex(c)
	graph.add_edge(a, b, 1.0)
	graph.add_edge(b, c, 1.0)
	graph.add_edge(c, a, 1.0)
	assert_false(graph.would_removal_split(b), "b's neighbours stay joined through the a-c edge")

func test_removal_split_ignores_unrelated_islands() -> void:
	# The robustness guarantee: a separate disconnected island (island2) must not
	# make every deletion look unsafe. a--b--c is one chain; d--e is another. b is
	# still correctly a cut vertex; the leaf c is still safe - independent of d/e.
	var a := _vertex("a")
	var b := _vertex("b")
	var c := _vertex("c")
	var d := _vertex("d")
	var e := _vertex("e")
	for v: Node2D in [a, b, c, d, e]:
		graph.add_vertex(v)
	graph.add_edge(a, b, 1.0)
	graph.add_edge(b, c, 1.0)
	graph.add_edge(d, e, 1.0)
	assert_true(graph.would_removal_split(b), "a pre-existing separate island doesn't hide a real bridge")
	assert_false(graph.would_removal_split(c), "nor does it wrongly veto a safe leaf removal")

func test_would_removal_split_leaves_the_graph_intact() -> void:
	# The check blocks/unblocks internally; afterwards reachability must be
	# exactly what it was, with nothing left blocked.
	var a := _vertex("a")
	var b := _vertex("b")
	var c := _vertex("c")
	graph.add_vertex(a)
	graph.add_vertex(b)
	graph.add_vertex(c)
	graph.add_edge(a, b, 1.0)
	graph.add_edge(b, c, 1.0)
	graph.would_removal_split(b)
	assert_true(graph.is_reachable(a, c), "the whole chain is still connected after the probe")
	assert_false(graph.is_blocked(b), "the probed vertex is unblocked again")

func test_missing_vertex_removal_never_splits() -> void:
	var ghost := _vertex("ghost")
	assert_false(graph.would_removal_split(ghost), "an unregistered node can't split anything")

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

# --- teardown (WI-68 F3) -------------------------------------------------------

## A linked a-b-c chain, for the teardown tests.
func _chain() -> Array[Node2D]:
	var a := _vertex("a")
	var b := _vertex("b")
	var c := _vertex("c")
	graph.add_vertex(a)
	graph.add_vertex(b)
	graph.add_vertex(c)
	graph.add_edge(a, b, 1.0)
	graph.add_edge(b, c, 1.0)
	var nodes: Array[Node2D] = [a, b, c]
	return nodes

func test_clear_releases_connected_vertices() -> void:
	# Neighbours hold each other through `edges`, so a graph that is merely
	# released leaks every connected vertex as a RefCounted cycle. clear() is what
	# PathManager/StructureManager call on the way out to break them.
	var nodes: Array[Node2D] = _chain()
	var ref: WeakRef = weakref(graph.get_vertex_for_path(nodes[1]))
	graph.clear()
	graph = null
	assert_null(ref.get_ref(), "the middle vertex of a linked chain is freed with its graph")

func test_clear_forgets_every_vertex() -> void:
	var nodes: Array[Node2D] = _chain()
	graph.clear()
	for node: Node2D in nodes:
		assert_null(graph.get_vertex_for_path(node), "%s is no longer a vertex" % node.name)
	assert_false(graph.is_reachable(nodes[0], nodes[2]), "nothing is reachable in an empty graph")

func test_removing_a_vertex_after_clear_is_a_no_op() -> void:
	# A pawn's PREDELETE calls path_manager.remove_vertex(self) during the same
	# teardown that cleared the graph; that has to land on the unknown-vertex
	# early return rather than error.
	var nodes: Array[Node2D] = _chain()
	graph.clear()
	graph.remove_vertex(nodes[1])
	assert_null(graph.get_vertex_for_path(nodes[1]), "still absent, and no error on the way")

func test_clear_does_not_announce_a_change() -> void:
	# It runs from _exit_tree while graph_changed's listeners are being torn down
	# in the same pass, so it must stay silent.
	_chain()
	watch_signals(graph)
	graph.clear()
	assert_signal_not_emitted(graph, "graph_changed")
