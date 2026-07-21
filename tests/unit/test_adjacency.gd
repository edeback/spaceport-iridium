extends GutTest

## Unit tests for the WI-30 adjacency propagation math: ModuleGraph.bfs_hops
## (hop-distance BFS over physical structure edges) and AdjacencyEffectSpec
## falloff, plus the multi-source field sum the AdjacencyManager builds on top of
## them. The manager itself touches Global/SignalBus so it's verified in-editor;
## here we pin the pure logic it delegates to - construct classes directly.
##
## Vertices are plain Node2D stand-ins for modules (bfs_hops only reads vertex
## identity and edges), autofreed at end of test.

var graph: ModuleGraph

func before_each() -> void:
	graph = ModuleGraph.new()

func _vertex(vertex_name: String = "v") -> Node2D:
	var node := Node2D.new()
	node.name = vertex_name
	autofree(node)
	return node

func _spec(effect: StringName, intensity: float, range_hops: int, falloff: float) -> AdjacencyEffectSpec:
	var spec := AdjacencyEffectSpec.new()
	spec.effect_id = effect
	spec.intensity = intensity
	spec.range_hops = range_hops
	spec.falloff = falloff
	return spec

# --- AdjacencyEffectSpec falloff ---------------------------------------------

func test_spec_falls_off_geometrically_per_hop() -> void:
	var spec := _spec(&"vibration", 1.0, 3, 0.5)
	assert_almost_eq(spec.level_at_hops(1), 0.5, 0.0001, "one hop = intensity * falloff^1")
	assert_almost_eq(spec.level_at_hops(2), 0.25, 0.0001, "two hops = intensity * falloff^2")
	assert_almost_eq(spec.level_at_hops(3), 0.125, 0.0001, "three hops = intensity * falloff^3")

func test_spec_is_zero_at_source_and_past_range() -> void:
	var spec := _spec(&"vibration", 1.0, 3, 0.5)
	assert_eq(spec.level_at_hops(0), 0.0, "a source never affects itself (hop 0)")
	assert_eq(spec.level_at_hops(4), 0.0, "beyond range_hops the field is zero")

func test_spec_intensity_scales_the_field() -> void:
	var spec := _spec(&"maintenance", 2.0, 2, 0.5)
	assert_almost_eq(spec.level_at_hops(1), 1.0, 0.0001, "intensity 2 doubles the one-hop level")

# --- bfs_hops shortest distances ---------------------------------------------

func test_bfs_hops_gives_shortest_hop_counts_along_a_chain() -> void:
	var s := _vertex("s")
	var a := _vertex("a")
	var b := _vertex("b")
	graph.add_vertex(s)
	graph.add_vertex(a)
	graph.add_vertex(b)
	graph.add_edge(s, a, 1.0)
	graph.add_edge(a, b, 1.0)
	var hops: Dictionary[Node2D, int] = graph.bfs_hops(s, 3)
	assert_eq(hops.get(a), 1, "a is one hop from s")
	assert_eq(hops.get(b), 2, "b is two hops from s")
	assert_false(hops.has(s), "bfs_hops excludes the source itself")

func test_bfs_hops_takes_the_shorter_of_two_routes() -> void:
	# s-a-t is 2 hops; s-t direct is 1 hop. BFS must report the 1.
	var s := _vertex("s")
	var a := _vertex("a")
	var t := _vertex("t")
	graph.add_vertex(s)
	graph.add_vertex(a)
	graph.add_vertex(t)
	graph.add_edge(s, a, 1.0)
	graph.add_edge(a, t, 1.0)
	graph.add_edge(s, t, 1.0)
	assert_eq(graph.bfs_hops(s, 3).get(t), 1, "the direct edge wins the hop count")

func test_bfs_hops_respects_range() -> void:
	var s := _vertex("s")
	var a := _vertex("a")
	var b := _vertex("b")
	graph.add_vertex(s)
	graph.add_vertex(a)
	graph.add_vertex(b)
	graph.add_edge(s, a, 1.0)
	graph.add_edge(a, b, 1.0)
	var hops: Dictionary[Node2D, int] = graph.bfs_hops(s, 1)
	assert_true(hops.has(a), "a is within range 1")
	assert_false(hops.has(b), "b at two hops is outside range 1")

func test_bfs_hops_empty_for_zero_range_or_isolated_source() -> void:
	var s := _vertex("s")
	var island := _vertex("island")
	graph.add_vertex(s)
	graph.add_vertex(island)
	assert_eq(graph.bfs_hops(s, 0).size(), 0, "range 0 reaches nothing")
	assert_eq(graph.bfs_hops(s, 3).size(), 0, "an unconnected source has no neighborhood")

# --- truss conduction --------------------------------------------------------

func test_field_conducts_across_a_truss_gap() -> void:
	# Deconstructing a module between a source and receiver leaves a truss, which
	# is a normal structural vertex - the field must still reach across it, one
	# extra hop out. source - truss - receiver.
	var source := _vertex("source")
	var truss := _vertex("truss")
	var receiver := _vertex("receiver")
	graph.add_vertex(source)
	graph.add_vertex(truss)
	graph.add_vertex(receiver)
	graph.add_edge(source, truss, 1.0)
	graph.add_edge(truss, receiver, 1.0)
	var hops: Dictionary[Node2D, int] = graph.bfs_hops(source, 3)
	assert_eq(hops.get(receiver), 2, "the receiver is two hops away, conducting through truss")
	var spec := _spec(&"vibration", 1.0, 3, 0.5)
	assert_almost_eq(spec.level_at_hops(hops.get(receiver)), 0.25, 0.0001,
		"field persists across the truss at the two-hop level")

# --- adjacency ignores the pawn-traversal cliques ----------------------------

func test_bfs_hops_ignores_implicit_group_clique() -> void:
	# Two modules sharing a turbolift group but with no real structural edge are
	# reachable for pawns but NOT structurally adjacent - vibration must not jump
	# the implicit clique.
	var a := _vertex("a")
	var b := _vertex("b")
	graph.add_vertex(a, false, &"shaft")
	graph.add_vertex(b, false, &"shaft")
	assert_true(graph.is_reachable(a, b), "same group -> pawn-reachable")
	assert_eq(graph.bfs_hops(a, 3).size(), 0, "but bfs_hops follows real edges only")

func test_bfs_hops_ignores_exterior_clique() -> void:
	var a := _vertex("a")
	var b := _vertex("b")
	graph.add_vertex(a, false, &"", 0, true)
	graph.add_vertex(b, false, &"", 0, true)
	assert_true(graph.is_reachable(a, b), "both exterior -> in the space clique")
	assert_eq(graph.bfs_hops(a, 3).size(), 0, "vibration doesn't cross vacuum")

# --- multi-source field sum (what AdjacencyManager builds) --------------------

func test_field_is_the_sum_over_sources() -> void:
	# s1 - r - s2: the receiver r sits one hop from each source, so its field is
	# the sum of both one-hop contributions.
	var s1 := _vertex("s1")
	var r := _vertex("r")
	var s2 := _vertex("s2")
	graph.add_vertex(s1)
	graph.add_vertex(r)
	graph.add_vertex(s2)
	graph.add_edge(s1, r, 1.0)
	graph.add_edge(r, s2, 1.0)
	var spec := _spec(&"vibration", 1.0, 3, 0.5)
	var from_s1: Dictionary[Node2D, int] = graph.bfs_hops(s1, spec.range_hops)
	var from_s2: Dictionary[Node2D, int] = graph.bfs_hops(s2, spec.range_hops)
	var field_at_r: float = spec.level_at_hops(from_s1.get(r, 0)) + spec.level_at_hops(from_s2.get(r, 0))
	assert_almost_eq(field_at_r, 1.0, 0.0001, "0.5 from each source sums to 1.0 at the receiver")

func test_field_zero_when_receiver_disconnected() -> void:
	var s := _vertex("s")
	var island := _vertex("island")
	graph.add_vertex(s)
	graph.add_vertex(island)
	var spec := _spec(&"vibration", 1.0, 3, 0.5)
	assert_eq(spec.level_at_hops(graph.bfs_hops(s, spec.range_hops).get(island, 0)), 0.0,
		"an unconnected module sits in no field")
