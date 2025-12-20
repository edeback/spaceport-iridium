## Visual settings for TileCheckIndicator display.
class_name IndicatorVisualSettings
extends GBResource

## Texture for validation failure display.
@export var texture: Texture2D

## Color adjustment for the fail texture.
@export var modulate: Color = Color.WHITE

## Returns a fresh IndicatorVisualSettings configured for a "valid" state
static func get_valid_default() -> IndicatorVisualSettings:
	var s := IndicatorVisualSettings.new()
	s.texture = _create_default_texture(Color(0, 1, 0, 1), 16)
	s.modulate = Color(0, 1, 0, 1) # green
	return s

## NOTE: If a `RuleCheckIndicator` lacks `valid_settings`/`invalid_settings`,
## safe default visuals are auto-initialized at runtime. Prefer assigning
## polished visuals on the scene template; defaults are fallbacks.

## Returns a fresh IndicatorVisualSettings configured for an "invalid" state
static func get_invalid_default() -> IndicatorVisualSettings:
	var s := IndicatorVisualSettings.new()
	s.texture = _create_default_texture(Color(1, 0, 0, 1), 16)
	s.modulate = Color(1, 0, 0, 1) # red
	return s

## Internal helper: create a small white ImageTexture used as a fallback texture
static func _create_default_texture(p_color: Color, p_size: int = 16) -> ImageTexture:
	# Use static Image.create(...) to avoid static-on-instance issues and ensure a valid non-empty image
	var img: Image = Image.create(p_size, p_size, false, Image.FORMAT_RGBA8)
	img.fill(p_color)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	return tex

## Returns an array of issues found during editor validation
func get_editor_issues() -> Array[String]:
	var issues: Array[String] = []
	
	if texture == null:
		issues.append("IndicatorVisualSettings texture is not set")
	
	return issues

## Returns an array of issues found during runtime validation
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	issues.append_array(get_editor_issues())
	
	return issues
