extends GutTest

## R4 (WI-69 §4, from the first audit): a save written straight after a load is
## the save that was loaded.
##
## Two comparisons, because there are two claims:
## - **post-load against post-load is exact.** Both saves come from a game that
##   was just loaded, so every field has been through the same JSON round trip.
##   F13 (asteroid rotation drifting a float32 ulp per load) was the last value
##   that broke this, so any difference at all is a finding.
## - **live against post-load is exact up to one documented equivalence.** A
##   pawn's in-flight job is restored at the front of its queue rather than as its
##   current job; it resumes first either way (WI-68 F21). That rewrite is applied
##   to the live save before comparing, and nothing else is.
##
## The station is made busy first, so the saves carry an in-flight job and a
## pile rather than an idle starter station.

var fx: StationFixture

func before_each() -> void:
	fx = StationFixture.new(self)
	await fx.boot()

func after_each() -> void:
	await fx.finish()

func test_a_save_written_straight_after_a_load_is_the_save_that_was_loaded() -> void:
	assert_true(await _make_busy(), "a pawn is mid-way through a saveable job")
	assert_gt(_spin_asteroids_like_a_long_session(), 0, "there are asteroids to round-trip")
	assert_true(await fx.save_and_reload())
	var live: Dictionary = fx.read_save()
	assert_true(fx.save())
	var first_after_load: Dictionary = fx.read_save()
	assert_true(await fx.save_and_reload())
	assert_true(fx.save())
	var second_after_load: Dictionary = fx.read_save()

	assert_eq(StationFixture.diff(first_after_load["sections"], second_after_load["sections"]),
		PackedStringArray(), "post-load saves are identical")
	assert_eq(StationFixture.diff(StationFixture.restored_form(live["sections"]), first_after_load["sections"]),
		PackedStringArray(), "the live save differs only by where the in-flight job sits")
	assert_true(fx.check_invariants("after two reloads"))
	assert_true(await fx.tick(5.0), "and the reloaded station runs")

## The equivalence itself: the live save does record a current job, and the
## post-load save records it as the head of the queue instead.
func test_the_in_flight_job_moves_to_the_head_of_the_queue() -> void:
	assert_true(await _make_busy())
	assert_true(await fx.save_and_reload())
	var live: Dictionary = fx.read_save()
	assert_true(fx.save())
	var after_load: Dictionary = fx.read_save()
	var moved: int = 0
	var live_pawns: Array = live["sections"]["pawns"]
	var loaded_pawns: Array = after_load["sections"]["pawns"]
	for index: int in live_pawns.size():
		var before: Dictionary = live_pawns[index]
		if not before.has("current_job"):
			continue
		var after: Dictionary = loaded_pawns[index]
		assert_false(after.has("current_job"))
		var queue: Array = after.get("job_queue", [])
		if not queue.is_empty():
			assert_eq(StationFixture.diff(before["current_job"], queue[0]), PackedStringArray())
			moved += 1
	assert_gt(moved, 0, "at least one in-flight job was saved")

## A blueprint that needs hauling and a pile to collect, then sim until some pawn
## holds a job that saves.
func _make_busy() -> bool:
	fx.place(&"small_storage", Vector2i(14, 8), false)
	var canvas: CanvasLayer = Global.world_manager.get_canvas_for_layer(WorldManager.StructureLayer.MODULE)
	var pile := ResourcePile.spawn(canvas, Global.cell_to_world(Vector2i(16, 9), true))
	pile.add_amount(fx.resource(&"iron_ore"), 30)
	return await fx.tick_until(_someone_is_mid_job, 60.0)

## Spin accumulates without bound in play: the real quicksave's rocks had turned
## 3,457 degrees. At that size float32 has lost enough digits that a load/save
## round trip moved the value by an ulp (F13), which a young station's
## sub-360-degree rocks never show. So each rock is given a long session's worth
## of spin, at a different fraction, before anything is saved. Belt rocks arrive
## on a random clock, so three are spawned first rather than hoped for. Returns
## how many rocks there are.
func _spin_asteroids_like_a_long_session() -> int:
	var belt: SpaceBodyProfile = Global.asteroid_manager.profile_by_id(&"asteroid")
	for count: int in 3:
		Global.asteroid_manager.spawn_body(belt)
	var rocks: Array[Node] = get_tree().get_nodes_in_group(Groups.ASTEROID)
	for index: int in rocks.size():
		var rock: AsteroidBase = rocks[index] as AsteroidBase
		if rock != null and rock.sprite != null:
			rock.sprite.rotation_degrees += 3457.0 + 97.31 * index
	return rocks.size()

func _someone_is_mid_job() -> bool:
	for pawn: PawnBase in fx.pawns():
		if pawn.current_job != null and not pawn.current_job.to_dict().is_empty():
			return true
	return false
