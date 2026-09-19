extends GutTest

## [ModuleGraphVertex]: one node in a [ModuleGraph]. F19 (the first audit) listed
## it as one of three classes with no suite; WI-69 §5 adds it.
##
## `test_module_graph.gd` covers the graph's behaviour through its public API.
## This covers the vertex's own contract - one edge per destination, the
## distance fallback for a vertex whose node is gone, and the ownership rule
## that made F3 a leak: **an edge holds its destination strongly**, so two
## linked vertices keep each other alive until someone empties their edges.

func test_a_new_vertex_is_an_ordinary_interior_stop() -> void:
	var vertex := ModuleGraphVertex.new()
	assert_eq(vertex.edges.size(), 0)
	assert_false(vertex.blocked)
	assert_eq(vertex.group, &"")
	assert_false(vertex.no_group_stop)
	assert_false(vertex.is_exterior)
	assert_false(vertex.endpoint)

func test_an_edge_records_its_cost_and_data() -> void:
	var a := ModuleGraphVertex.new()
	var b := ModuleGraphVertex.new()
	a.add_edge(b, 3.5, &"door_left")
	assert_true(a.edges.has(b))
	assert_eq(a.edges[b].cost, 3.5)
	assert_eq(a.edges[b].data, &"door_left")

func test_edges_are_one_way() -> void:
	var a := ModuleGraphVertex.new()
	var b := ModuleGraphVertex.new()
	a.add_edge(b, 1.0)
	assert_false(b.edges.has(a), "the graph adds the reverse edge itself; a vertex never does")

func test_a_second_edge_to_the_same_destination_replaces_the_first() -> void:
	var a := ModuleGraphVertex.new()
	var b := ModuleGraphVertex.new()
	a.add_edge(b, 1.0, &"old")
	a.add_edge(b, 7.0, &"new")
	assert_eq(a.edges.size(), 1, "one edge per destination")
	assert_eq(a.edges[b].cost, 7.0)
	assert_eq(a.edges[b].data, &"new")

func test_edges_to_different_destinations_are_kept_apart() -> void:
	var a := ModuleGraphVertex.new()
	var b := ModuleGraphVertex.new()
	var c := ModuleGraphVertex.new()
	a.add_edge(b, 1.0)
	a.add_edge(c, 2.0)
	assert_eq(a.edges.size(), 2)
	assert_eq(a.edges[c].cost, 2.0)

func test_distance_is_measured_between_the_nodes() -> void:
	var a := ModuleGraphVertex.new()
	var b := ModuleGraphVertex.new()
	a.node = add_child_autofree(Node2D.new()) as Node2D
	b.node = add_child_autofree(Node2D.new()) as Node2D
	b.node.global_position = Vector2(30.0, 40.0)
	assert_almost_eq(a.dist_to(b), 50.0, 0.001)
	assert_almost_eq(a.dist_squared_to(b), 2500.0, 0.001)
	assert_almost_eq(b.dist_to(a), 50.0, 0.001, "symmetric")

func test_a_vertex_with_no_node_is_infinitely_far() -> void:
	# The sentinel is what keeps A* from preferring a vertex whose node has gone,
	# rather than an error mid-search.
	var a := ModuleGraphVertex.new()
	var b := ModuleGraphVertex.new()
	b.node = add_child_autofree(Node2D.new()) as Node2D
	assert_eq(a.dist_to(b), 99999999.0)
	assert_eq(b.dist_squared_to(a), 99999999.0)

func test_a_vertex_whose_node_was_freed_is_infinitely_far() -> void:
	var a := ModuleGraphVertex.new()
	var b := ModuleGraphVertex.new()
	a.node = add_child_autofree(Node2D.new()) as Node2D
	b.node = Node2D.new()
	b.node.free()
	assert_eq(a.dist_to(b), 99999999.0)
	assert_eq(a.dist_squared_to(b), 99999999.0)

## The mechanism behind F3: a vertex is kept alive by any vertex with an edge to
## it, so a graph whose vertices point at each other never frees on its own.
## `ModuleGraph.clear()` empties the edges for exactly this reason.
func test_an_edge_keeps_its_destination_alive_until_the_edges_are_emptied() -> void:
	var holder := ModuleGraphVertex.new()
	var held := ModuleGraphVertex.new()
	holder.add_edge(held, 1.0)
	var watch: WeakRef = weakref(held)
	held = null
	assert_not_null(watch.get_ref(), "the edge alone keeps the destination alive")
	holder.edges.clear()
	assert_null(watch.get_ref(), "and emptying the edges releases it")

func test_two_linked_vertices_are_a_cycle() -> void:
	var a := ModuleGraphVertex.new()
	var b := ModuleGraphVertex.new()
	a.add_edge(b, 1.0)
	b.add_edge(a, 1.0)
	var watch_a: WeakRef = weakref(a)
	var watch_b: WeakRef = weakref(b)
	var keep: ModuleGraphVertex = a
	a = null
	b = null
	assert_not_null(watch_b.get_ref(), "b is held by a")
	# Break the cycle the way ModuleGraph.clear() does, then drop the last handle.
	var other: ModuleGraphVertex = watch_b.get_ref() as ModuleGraphVertex
	keep.edges.clear()
	other.edges.clear()
	other = null
	keep = null
	assert_null(watch_a.get_ref(), "with the edges emptied, both are released")
	assert_null(watch_b.get_ref())
