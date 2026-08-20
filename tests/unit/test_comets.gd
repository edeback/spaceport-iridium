extends GutTest

## Unit tests for WI-61: the crossing geometry, the profile rolls, the per-body
## despawn rule and the sprite orientation.
##
## Pure only, per the standing rule - SpaceGeometry and SpaceBodyProfile are
## constructed directly and touch neither Global nor SignalBus. AsteroidBase is a
## Node2D but `.new()` never runs _ready(), so a bare instance is safe here; the
## existing test_goto_lost_target.gd relies on the same thing.

const STATION := Rect2(Vector2(1000.0, 1000.0), Vector2(600.0, 400.0))

func _bounds_of(positions: Array[Vector2]) -> Rect2:
	return SpaceGeometry.station_bounds(positions)

# --- station bounds -----------------------------------------------------------

func test_bounds_of_nothing_is_degenerate_not_an_error() -> void:
	var bounds: Rect2 = _bounds_of([] as Array[Vector2])
	assert_eq(bounds, Rect2(), "no modules gives a zero rect rather than a crash")

func test_bounds_of_one_module_is_a_point() -> void:
	var bounds: Rect2 = _bounds_of([Vector2(320.0, 640.0)] as Array[Vector2])
	assert_eq(bounds.position, Vector2(320.0, 640.0), "anchored on the only module")
	assert_eq(bounds.size, Vector2.ZERO, "a one-module station has no extent")

func test_bounds_span_every_module() -> void:
	var bounds: Rect2 = _bounds_of([
		Vector2(100.0, 200.0), Vector2(-50.0, 900.0), Vector2(640.0, 40.0),
	] as Array[Vector2])
	assert_eq(bounds.position, Vector2(-50.0, 40.0), "top-left of the spread")
	assert_eq(bounds.end, Vector2(640.0, 900.0), "bottom-right of the spread")

# --- half extent / outward point ---------------------------------------------
#
# These two are the salvage effect's own inline math, extracted. The numbers
# below are PINNED to what EventEffectSpawnSalvage produced before the move: if
# they change, salvage piles moved, which is a regression and not a refactor.

func test_half_extent_on_the_axes() -> void:
	assert_almost_eq(SpaceGeometry.half_extent(STATION, Vector2.RIGHT), 300.0, 0.001,
			"horizontal box radius is half the width")
	assert_almost_eq(SpaceGeometry.half_extent(STATION, Vector2.UP), 200.0, 0.001,
			"vertical box radius is half the height")
	assert_almost_eq(SpaceGeometry.half_extent(STATION, Vector2.LEFT), 300.0, 0.001,
			"sign of the direction never matters")

func test_half_extent_on_a_diagonal_sums_both_axes() -> void:
	var diagonal: Vector2 = Vector2(1.0, 1.0).normalized()
	var expected: float = (300.0 + 200.0) / sqrt(2.0)
	assert_almost_eq(SpaceGeometry.half_extent(STATION, diagonal), expected, 0.001,
			"the box-radius form the salvage effect used, unchanged")

func test_outward_point_is_the_pinned_salvage_rule() -> void:
	# centre (1300, 1200) + right * (300 + 500)
	var point: Vector2 = SpaceGeometry.outward_point(STATION, Vector2.RIGHT, 500.0)
	assert_almost_eq(point.x, 2100.0, 0.001, "pushed clear of the box, then the band")
	assert_almost_eq(point.y, 1200.0, 0.001, "stays on the centre line")

func test_outward_point_of_a_pointlike_station_is_just_the_margin() -> void:
	var point: Vector2 = SpaceGeometry.outward_point(
			Rect2(Vector2(50.0, 50.0), Vector2.ZERO), Vector2.DOWN, 400.0)
	assert_almost_eq(point.distance_to(Vector2(50.0, 50.0)), 400.0, 0.001,
			"no extent to clear, so the margin is the whole distance")

# --- crossings ----------------------------------------------------------------

func test_crossing_entry_is_always_outside_the_station() -> void:
	for step: int in 24:
		var angle: float = TAU * float(step) / 24.0
		var crossing: SpaceGeometry.Crossing = SpaceGeometry.crossing(
				STATION, angle, 0.0, 600.0, 500.0)
		assert_false(STATION.has_point(crossing.entry),
				"entry at %.2f rad is outside the hull" % angle)
		var clearance: float = crossing.entry.distance_to(STATION.get_center()) \
				- SpaceGeometry.half_extent(STATION, Vector2.from_angle(angle))
		assert_almost_eq(clearance, 600.0, 0.001,
				"and exactly the entry margin clear of it")

func test_crossing_through_the_centre_aims_at_the_centre() -> void:
	var crossing: SpaceGeometry.Crossing = SpaceGeometry.crossing(
			STATION, 0.0, 0.0, 600.0, 500.0)
	var to_centre: Vector2 = (STATION.get_center() - crossing.entry).normalized()
	assert_almost_eq(crossing.direction.angle_to(to_centre), 0.0, 0.001,
			"lateral 0 heads straight through the middle")

func test_crossing_direction_is_normalised_at_every_angle_and_offset() -> void:
	for step: int in 16:
		for lateral: float in [-1.0, -0.4, 0.0, 0.4, 1.0]:
			var crossing: SpaceGeometry.Crossing = SpaceGeometry.crossing(
					STATION, TAU * float(step) / 16.0, lateral, 800.0, 400.0)
			assert_almost_eq(crossing.direction.length(), 1.0, 0.001,
					"heading is a unit vector")

func test_crossing_distance_always_clears_the_far_side() -> void:
	# The property the despawn rule depends on: a body that has travelled its
	# whole `distance` is past the station, not sitting on top of it. Anything
	# less and comets vanish in front of the player.
	for step: int in 24:
		for lateral: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var crossing: SpaceGeometry.Crossing = SpaceGeometry.crossing(
					STATION, TAU * float(step) / 24.0, lateral, 600.0, 500.0)
			var exit_point: Vector2 = crossing.entry + crossing.direction * crossing.distance
			var beyond: float = exit_point.distance_to(STATION.get_center()) \
					- SpaceGeometry.half_extent(STATION, crossing.direction)
			assert_gt(beyond, 0.0,
					"exit point is clear of the hull (step %d, lateral %.1f)" % [step, lateral])

func test_crossing_of_a_stationless_world_is_still_finite() -> void:
	# Degenerate on purpose: zero bounds AND zero margins is the only way entry,
	# centre and aim collapse onto one point.
	var crossing: SpaceGeometry.Crossing = SpaceGeometry.crossing(
			Rect2(), 0.0, 0.0, 0.0, 0.0)
	assert_almost_eq(crossing.direction.length(), 1.0, 0.001,
			"falls back to a real heading rather than a zero vector")
	assert_false(is_nan(crossing.distance), "and a real distance")

func test_lateral_offset_moves_the_aim_sideways() -> void:
	var centred: SpaceGeometry.Crossing = SpaceGeometry.crossing(STATION, 0.0, 0.0, 600.0, 500.0)
	var grazing: SpaceGeometry.Crossing = SpaceGeometry.crossing(STATION, 0.0, 1.0, 600.0, 500.0)
	assert_true(absf(centred.direction.angle_to(grazing.direction)) > 0.01,
			"a grazing crossing is a different heading from a bisecting one")

# --- the fixed-list ore mix ---------------------------------------------------

func _resource(id: StringName, variance: bool = false) -> ResourceData:
	var res := ResourceData.new()
	res.id = id
	res.name = String(id).capitalize()
	res.has_variance = variance
	return res

func _entry(res: ResourceData, weight: float, chance: float) -> BodyOreEntry:
	var entry := BodyOreEntry.new()
	entry.resource = res
	entry.weight = weight
	entry.chance = chance
	return entry

func _comet_profile() -> SpaceBodyProfile:
	var profile := SpaceBodyProfile.new()
	profile.id = &"comet"
	profile.mix_mode = SpaceBodyProfile.MixMode.FIXED_LIST
	profile.fixed_ores = [
		_entry(_resource(&"ice"), 6.0, 1.0),
		_entry(_resource(&"carbon"), 3.0, 1.0),
		_entry(_resource(&"silicon_ore", true), 1.0, 0.35),
	]
	return profile

func test_certain_entries_appear_on_every_body() -> void:
	var profile: SpaceBodyProfile = _comet_profile()
	var ice: ResourceData = profile.fixed_ores[0].resource
	var carbon: ResourceData = profile.fixed_ores[1].resource
	for i: int in 200:
		var mix: Dictionary[ResourceData, float] = profile.roll_fixed_mix()
		assert_true(mix.has(ice), "chance 1.0 means always")
		assert_true(mix.has(carbon), "chance 1.0 means always")

func test_weights_land_unmodified() -> void:
	var profile: SpaceBodyProfile = _comet_profile()
	var mix: Dictionary[ResourceData, float] = profile.roll_fixed_mix()
	assert_eq(mix[profile.fixed_ores[0].resource], 6.0, "ice keeps its authored share")
	assert_eq(mix[profile.fixed_ores[1].resource], 3.0, "carbon keeps its authored share")

func test_chanced_entry_is_sometimes_absent_and_sometimes_present() -> void:
	var profile: SpaceBodyProfile = _comet_profile()
	var silicon: ResourceData = profile.fixed_ores[2].resource
	var hits: int = 0
	for i: int in 400:
		if profile.roll_fixed_mix().has(silicon):
			hits += 1
	# Wide band on purpose: this asserts the chance is applied at all, not that
	# 400 samples of a 0.35 coin landed on the nose.
	assert_between(hits, 90, 190, "a 0.35 entry lands on roughly a third of bodies")

func test_null_and_zero_weight_rows_are_skipped_not_crashed() -> void:
	var profile := SpaceBodyProfile.new()
	profile.mix_mode = SpaceBodyProfile.MixMode.FIXED_LIST
	var good: ResourceData = _resource(&"ice")
	profile.fixed_ores = [
		null,
		_entry(null, 5.0, 1.0),
		_entry(_resource(&"nothing"), 0.0, 1.0),
		_entry(good, 4.0, 1.0),
	]
	var mix: Dictionary[ResourceData, float] = profile.roll_fixed_mix()
	assert_eq(mix.size(), 1, "only the one usable row made it")
	assert_true(mix.has(good), "and it is the right one")

func test_weighted_pick_profile_rolls_no_fixed_mix() -> void:
	# The belt's mix needs the manager's ore pool, so this must stay empty here
	# rather than silently producing a body with nothing in it.
	var profile := SpaceBodyProfile.new()
	profile.mix_mode = SpaceBodyProfile.MixMode.WEIGHTED_PICK
	profile.fixed_ores = [_entry(_resource(&"ice"), 6.0, 1.0)]
	assert_true(profile.roll_fixed_mix().is_empty(), "WEIGHTED_PICK does not use fixed_ores")

func test_declared_yields_are_deduplicated_and_null_safe() -> void:
	var profile: SpaceBodyProfile = _comet_profile()
	var shared: ResourceData = profile.fixed_ores[0].resource
	profile.fixed_ores.append(_entry(shared, 1.0, 1.0))
	profile.fixed_ores.append(null)
	assert_eq(profile.declared_yields().size(), 3, "three distinct resources, listed once each")

# --- richness, speed and cadence rolls ----------------------------------------

func test_richness_range_stays_inside_zero_to_one() -> void:
	var profile := SpaceBodyProfile.new()
	profile.richness_band = Vector2(0.0, 1.0)
	profile.richness_spread = 0.4
	for i: int in 300:
		var range_rolled: Vector2 = profile.roll_richness_range()
		assert_between(range_rolled.x, 0.0, 1.0, "low end clamped")
		assert_between(range_rolled.y, 0.0, 1.0, "high end clamped")
		assert_true(range_rolled.x <= range_rolled.y, "and the range is not inverted")

func test_richness_skew_biases_toward_the_poor_end() -> void:
	var poor := SpaceBodyProfile.new()
	poor.richness_band = Vector2(0.0, 1.0)
	poor.richness_spread = 0.0
	poor.richness_skew = 4.0
	var total: float = 0.0
	for i: int in 500:
		total += poor.roll_richness_range().x
	assert_lt(total / 500.0, 0.45, "a skew above 1 makes rich bodies the rare ones")

func test_speed_and_gap_rolls_respect_their_bands() -> void:
	var profile := SpaceBodyProfile.new()
	profile.speed_range = Vector2(15.0, 28.0)
	profile.spawn_gap_hours = Vector2(18.0, 60.0)
	for i: int in 200:
		assert_between(profile.roll_speed(), 15.0, 28.0, "speed inside its band")
		assert_between(profile.roll_spawn_gap_seconds(),
				18.0 * TimeManager.SECONDS_PER_HOUR, 60.0 * TimeManager.SECONDS_PER_HOUR,
				"gap converted from game-hours to sim-seconds")

func test_comet_speed_stays_well_under_drone_speed() -> void:
	# Not a style rule: drones chase a moving body at PawnBase.speed, so a body
	# anywhere near that turns every mining trip into a stern chase.
	var profile: SpaceBodyProfile = load("res://data/space_bodies/comet_profile.tres")
	assert_lt(profile.speed_range.y, 40.0, "shipped comet speed leaves the drone a margin")

# --- the body itself ----------------------------------------------------------

func _body() -> AsteroidBase:
	# .new() does not run _ready(), so nothing here reaches Global.
	return autofree(AsteroidBase.new()) as AsteroidBase

func test_despawn_predicate_at_its_boundary() -> void:
	var body: AsteroidBase = _body()
	body.despawn_anchor = Vector2(100.0, 100.0)
	body.despawn_distance = 500.0
	body.position = Vector2(100.0, 599.0)
	assert_false(body.should_despawn(), "just inside its route")
	body.position = Vector2(100.0, 600.0)
	assert_false(body.should_despawn(), "exactly at the limit is not yet past it")
	body.position = Vector2(100.0, 601.0)
	assert_true(body.should_despawn(), "one pixel beyond and it is gone")

func test_a_crossing_body_survives_its_whole_route() -> void:
	# The trap this item exists to avoid: the belt's old 2000px-from-the-marker
	# rule would have freed a comet on its first frame.
	var crossing: SpaceGeometry.Crossing = SpaceGeometry.crossing(
			STATION, 2.1, 0.3, 900.0, 500.0)
	var body: AsteroidBase = _body()
	body.despawn_anchor = crossing.entry
	body.despawn_distance = crossing.distance
	body.position = crossing.entry
	assert_false(body.should_despawn(), "alive at spawn")
	body.position = crossing.entry + crossing.direction * (crossing.distance * 0.5)
	assert_false(body.should_despawn(), "alive halfway across, over the station")
	body.position = crossing.entry + crossing.direction * (crossing.distance * 1.01)
	assert_true(body.should_despawn(), "and gone once the route is run")

func test_orientation_points_the_art_along_travel() -> void:
	var body: AsteroidBase = _body()
	var sprite := Sprite2D.new()
	body.sprite = sprite
	body.add_child(sprite)
	body.faces_travel_direction = true
	# blue_comet.png has its head at the bottom-left, i.e. its art already points
	# at 135 degrees. Travelling that way must leave the sprite unrotated.
	body.sprite_forward_offset_deg = 135.0
	body.direction = Vector2(-1.0, 1.0).normalized()
	assert_almost_eq(sprite.rotation, 0.0, 0.001, "art heading == travel heading = no rotation")
	for heading: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		body.direction = heading
		var pointed: Vector2 = Vector2(-1.0, 1.0).normalized().rotated(sprite.rotation)
		assert_almost_eq(pointed.angle_to(heading), 0.0, 0.001,
				"the art's own forward axis ends up on the heading")

func test_a_tumbling_body_is_never_oriented() -> void:
	var body: AsteroidBase = _body()
	var sprite := Sprite2D.new()
	body.sprite = sprite
	body.add_child(sprite)
	sprite.rotation = 1.234
	body.faces_travel_direction = false
	body.direction = Vector2.RIGHT
	assert_almost_eq(sprite.rotation, 1.234, 0.001, "asteroids keep tumbling freely")

func test_has_variable_yield_tracks_the_mix() -> void:
	var body: AsteroidBase = _body()
	var ice: ResourceData = _resource(&"ice")
	var silicon: ResourceData = _resource(&"silicon_ore", true)
	body.resource_weighted_values = {ice: 6.0}
	assert_false(body.has_variable_yield(), "ice alone has no richness to report")
	body.resource_weighted_values = {ice: 6.0, silicon: 1.0}
	assert_true(body.has_variable_yield(), "one variance ore is enough")

func test_save_data_carries_the_fields_a_reload_cannot_re_derive() -> void:
	var body: AsteroidBase = _body()
	body.profile_id = &"comet"
	body.despawn_anchor = Vector2(-400.0, 250.0)
	body.despawn_distance = 6100.0
	var data: Dictionary = body.get_save_data()
	assert_eq(data["profile"], "comet",
			"without this every restored comet comes back as a rock")
	assert_eq(data["despawn_anchor"], [-400.0, 250.0], "route anchor round-trips")
	assert_eq(data["despawn_distance"], 6100.0, "route length round-trips")

# --- shipped data -------------------------------------------------------------

func test_shipped_profiles_load_and_are_distinct() -> void:
	var belt: SpaceBodyProfile = load("res://data/space_bodies/asteroid_belt_profile.tres")
	var comet: SpaceBodyProfile = load("res://data/space_bodies/comet_profile.tres")
	assert_eq(belt.id, &"asteroid", "the belt keeps the legacy id a pre-WI-61 save restores to")
	assert_eq(comet.id, &"comet")
	assert_eq(belt.trajectory, SpaceBodyProfile.Trajectory.BELT)
	assert_eq(comet.trajectory, SpaceBodyProfile.Trajectory.CROSSING)

## Pins the belt to exactly the numbers AsteroidManager held as @exports before
## WI-61 moved them into data. A refactor that changes any of these changed the
## game, which was not the deal.
func test_belt_profile_reproduces_the_pre_wi61_manager() -> void:
	var belt: SpaceBodyProfile = load("res://data/space_bodies/asteroid_belt_profile.tres")
	assert_eq(belt.max_population, 15, "the old `asteroids.size() < 15` gate")
	assert_eq(belt.spawn_gap_hours, Vector2(0.5, 0.5),
			"a flat half game-hour == the old `last_spawn > 5` sim-seconds")
	assert_eq(belt.speed_range, Vector2(10.0, 30.0), "the old randf_range(10, 30)")
	assert_eq(belt.belt_despawn_distance, 2000.0, "sqrt of the old 4000000 threshold")
	assert_eq(belt.belt_jitter, 200.0, "the old +/-200 marker jitter")
	assert_eq(belt.weighted_type_count, Vector2i(1, 3), "the old min/max_ore_types")
	assert_eq(belt.richness_band, Vector2(0.15, 1.0))
	assert_almost_eq(belt.richness_spread, 0.1, 0.0001)
	assert_almost_eq(belt.richness_skew, 1.6, 0.0001)
	assert_eq(belt.mix_mode, SpaceBodyProfile.MixMode.WEIGHTED_PICK)

func test_comet_population_matches_the_brief() -> void:
	var comet: SpaceBodyProfile = load("res://data/space_bodies/comet_profile.tres")
	assert_eq(comet.max_population, 2, "the brief's ceiling of two at once")
	assert_gt(comet.spawn_gap_hours.x, TimeManager.HOURS_PER_CYCLE * 0.5,
			"a gap long enough that the floor of zero is real, not theoretical")

func test_comet_yields_are_the_three_the_brief_names() -> void:
	var comet: SpaceBodyProfile = load("res://data/space_bodies/comet_profile.tres")
	var ids: Array[StringName] = []
	for entry: BodyOreEntry in comet.fixed_ores:
		ids.append(entry.resource.id)
	assert_eq(ids, [&"ice", &"carbon", &"silicon_ore"] as Array[StringName])
	assert_eq(comet.fixed_ores[0].chance, 1.0, "ice always")
	assert_eq(comet.fixed_ores[1].chance, 1.0, "carbon always")
	assert_lt(comet.fixed_ores[2].chance, 1.0, "silicon sometimes")
	assert_gt(comet.fixed_ores[0].weight, comet.fixed_ores[1].weight, "ice a lot")
	assert_gt(comet.fixed_ores[1].weight, comet.fixed_ores[2].weight, "carbon moderate")

## The guard that matters most in this item (WI-61 §6a).
##
## The mining bay's output storage is `allow_any_resource = false` with an
## authored slot list, and Action_DumpInventory silently keeps whatever the bin
## refuses. A body yielding something with no slot therefore fills its drone's
## hold trip by trip until can_do() refuses every future mining job - a permanent
## soft-lock with no alert and no error. Nothing else in the codebase would catch
## it, so it is caught here, against the shipped data.
##
## A text sweep of the scene rather than an instantiation, which is the idiom
## test_ui_theme.gd established: instantiating a module scene reaches Global.
func test_every_shipped_yield_fits_in_the_mining_bay() -> void:
	var scene_text: String = FileAccess.get_file_as_string(
			"res://modules/resource_gathering/mining_bay.tscn")
	assert_false(scene_text.is_empty(), "read the mining bay scene")
	if scene_text.contains("allow_any_resource = true"):
		pass_test("the bay takes anything, so no slot can be missing")
		return
	var slot_block: String = _storage_data_block(scene_text)
	assert_false(slot_block.is_empty(), "found the bay's storage_data block")
	for path: String in ContentPaths.scan(ContentPaths.SPACE_BODIES):
		var profile: SpaceBodyProfile = load(path) as SpaceBodyProfile
		if profile == null:
			continue
		for resource: ResourceData in profile.declared_yields():
			var ext_id: String = _ext_resource_id(scene_text, resource.resource_path)
			assert_false(ext_id.is_empty(),
					"%s ('%s') is referenced by the mining bay at all" % [profile.id, resource.id])
			assert_true(slot_block.contains('ExtResource("%s")' % ext_id),
					"%s can put down its %s - otherwise its drones soft-lock"
							% [profile.id, resource.id])

## The `storage_data = Dictionary[...]({ ... })` body, or "" if it isn't there.
func _storage_data_block(scene_text: String) -> String:
	var start: int = scene_text.find("storage_data = Dictionary")
	if start < 0:
		return ""
	var open_brace: int = scene_text.find("({", start)
	var close_brace: int = scene_text.find("})", open_brace)
	if open_brace < 0 or close_brace < 0:
		return ""
	return scene_text.substr(open_brace, close_brace - open_brace)

## The ext_resource id a scene bound to `resource_path`, or "" if it never
## references it.
func _ext_resource_id(scene_text: String, resource_path: String) -> String:
	var marker: String = 'path="%s" id="' % resource_path
	var at: int = scene_text.find(marker)
	if at < 0:
		return ""
	var id_start: int = at + marker.length()
	var id_end: int = scene_text.find('"', id_start)
	return scene_text.substr(id_start, id_end - id_start)
