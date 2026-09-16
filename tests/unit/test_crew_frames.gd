extends GutTest

## Content sweep over the two crew wardrobes (WI-67).
##
## PawnBase.set_sprite_frames carries the CURRENT animation name, frame index and
## sub-frame progress across a swap, so the two sets have to agree on all three or
## a suit coming off mid-stride lands on an animation that does not exist (or on a
## frame past the end of one that does). Nothing at runtime would say so: the pawn
## would simply stop animating.
##
## Pure in the sense that matters - it loads two resources and compares them, with
## no Global, no SignalBus and no tree.

const SUITED_PATH: String = "res://pawns/frames/crew_suited_frames.tres"
const UNSUITED_PATH: String = "res://pawns/frames/crew_unsuited_frames.tres"

## Every pose the pawn code can ask for by name. `idle` and `walk` come from
## PawnBase's movement; the rest are AnchorDef animations authored on modules.
const REQUIRED: Array[StringName] = [
	&"idle", &"idle_sit", &"interact", &"interact_back", &"interact_sit",
	&"lay_down", &"walk",
]

func _suited() -> SpriteFrames:
	return load(SUITED_PATH) as SpriteFrames

func _unsuited() -> SpriteFrames:
	return load(UNSUITED_PATH) as SpriteFrames

func test_both_wardrobes_load() -> void:
	assert_not_null(_suited(), "the suited frames resource loads")
	assert_not_null(_unsuited(), "the helmetless frames resource loads")

func test_both_carry_every_pose_the_game_asks_for() -> void:
	for frames: SpriteFrames in [_suited(), _unsuited()]:
		for pose: StringName in REQUIRED:
			assert_true(frames.has_animation(pose), "carries '%s'" % pose)

func test_the_two_sets_agree_animation_for_animation() -> void:
	var suited: SpriteFrames = _suited()
	var unsuited: SpriteFrames = _unsuited()
	var suited_names: PackedStringArray = suited.get_animation_names()
	var unsuited_names: PackedStringArray = unsuited.get_animation_names()
	assert_eq(suited_names.size(), unsuited_names.size(),
		"the same number of animations in both wardrobes")
	for name: String in suited_names:
		var anim: StringName = StringName(name)
		assert_true(unsuited.has_animation(anim), "helmetless carries '%s' too" % name)
		if not unsuited.has_animation(anim):
			continue
		# Frame count is the one that bites: set_sprite_frames clamps the index, so a
		# shorter animation silently truncates a pose rather than erroring.
		assert_eq(suited.get_frame_count(anim), unsuited.get_frame_count(anim),
			"'%s' has the same frame count in both" % name)
		assert_almost_eq(suited.get_animation_speed(anim), unsuited.get_animation_speed(anim),
			0.001, "'%s' plays at the same speed in both" % name)
		assert_eq(suited.get_animation_loop(anim), unsuited.get_animation_loop(anim),
			"'%s' loops the same way in both" % name)

func test_the_helmetless_set_actually_uses_the_helmetless_art() -> void:
	# The cheapest possible guard against the wardrobes being copies of each other,
	# which would make every test above pass while the feature showed nothing.
	var unsuited: SpriteFrames = _unsuited()
	var checked: int = 0
	for name: String in unsuited.get_animation_names():
		var anim: StringName = StringName(name)
		for i: int in unsuited.get_frame_count(anim):
			var texture: Texture2D = unsuited.get_frame_texture(anim, i)
			assert_not_null(texture, "'%s' frame %d has art" % [name, i])
			if texture == null:
				continue
			assert_true(texture.resource_path.contains("noHelmet"),
				"'%s' frame %d is helmetless art" % [name, i])
			checked += 1
	assert_gt(checked, 0, "something was actually checked")

func test_the_suited_set_uses_the_original_art() -> void:
	var suited: SpriteFrames = _suited()
	for name: String in suited.get_animation_names():
		var anim: StringName = StringName(name)
		for i: int in suited.get_frame_count(anim):
			var texture: Texture2D = suited.get_frame_texture(anim, i)
			assert_not_null(texture, "'%s' frame %d has art" % [name, i])
			if texture != null:
				assert_false(texture.resource_path.contains("noHelmet"),
					"'%s' frame %d is the suited art" % [name, i])
