## [auto] GridTargetingDebugText class in the Grid Building system.
## Methods: 6, Properties: 1, Constants: 8.
class_name GridTargetingDebugText
extends GBControl

@export var collisions_count_prefix := "Collisions:" # Descriptive collision count prefix
@export var debug_output : RichTextLabel
@export_enum("VERTICAL", "HORIZONTAL") var display_mode := "VERTICAL" # VERTICAL = labels + value lines; HORIZONTAL = single line per category

# Aggregated debug value state (labels applied during rendering)
var _lines := {
	"mouse": "",           # e.g. M 10.0,20.0
	"map": "",             # map name
	"indicator": "",       # indicator coordinates
	"collision_count": "", # numeric collision count
	"blocking": "",        # blocking summary
	"status": "uninitialized" # status text w/out label
}

const MAX_BLOCKING_NAMES := 4
const PLACEHOLDER_VALUE := "-"
const LABEL_STATUS := "Dependencies:"
const LABEL_MOUSE := "Mouse:"
const LABEL_MAP := "Target Map:"
const LABEL_INDICATOR := "Indicator:"
const LABEL_COLLISIONS := "Collisions:"
const LABEL_BLOCKING := "Blocking:"

var _last_rendered: String = ""
var _indicator_context: IndicatorContext
var _targeting_state: GridTargetingState
var _debug_settings: GBDebugSettings

func _ready() -> void:
	assert(debug_output != null, "Must set a RichTextLabel as debug_output to render output text")
	
	# Ensure BBCode parsing is enabled so header styling renders (Godot 4 uses bbcode_enabled property).
	if debug_output:
		debug_output.bbcode_enabled = true

func _process(_delta: float) -> void:
	# Always update mouse line; cheaper than relying on input events only.
	var viewport := get_viewport()
	if viewport:
		var _mp := viewport.get_mouse_position()
		_lines.mouse = "(%.1f,%.1f)" % [_mp.x, _mp.y]
	else:
		_lines.mouse = "(N/A,N/A)"
	# Refresh collision + indicator lines if manager present.
	if _indicator_context and _indicator_context.has_manager():
		var mgr: IndicatorManager = _indicator_context.get_manager()
		update_collision_labels(mgr)
		_update_indicator_line(mgr)
	_render_debug()

func resolve_gb_dependencies(p_container: GBCompositionContainer) -> void:
	assert(p_container, "Must pass a Grid Building composition root into resolve dependencies to source any needed dependencies.")
	_indicator_context = p_container.get_contexts().indicator
	_targeting_state = p_container.get_states().targeting
	_debug_settings = p_container.get_debug_settings()
	_lines.status = ("OK" if _indicator_context.has_manager() else "Missing Manager")
	# Listen for manager assignment changes so UI can reflect availability.
	if _indicator_context and not _indicator_context.manager_changed.is_connected(_on_manager_changed):
		_indicator_context.manager_changed.connect(_on_manager_changed)
	# Listen for map change to update map name line.
	if _targeting_state and not _targeting_state.target_map_changed.is_connected(_on_target_map_changed):
		_targeting_state.target_map_changed.connect(_on_target_map_changed)
	_update_map_line()
	_render_debug()
	# Force an immediate collision update if manager already exists.
	if _indicator_context.has_manager():
		update_collision_labels(_indicator_context.get_manager())
		_update_indicator_line(_indicator_context.get_manager())
		_render_debug()
	else:
		_lines.collision_count = "(no manager yet)"
		_lines.blocking = ""
		_render_debug()

func _on_manager_changed(new_manager: IndicatorManager) -> void:
	_lines.status = "OK"
	update_collision_labels(new_manager)
	_render_debug()

func set_indicator_position(p_position: Vector2) -> void:
	# Accepts either Vector2 or something convertible
	_lines.indicator = str(p_position)
	_render_debug()


func clear_indicator_position() -> void:
	_lines.indicator = ""
	_render_debug()

func update_collision_labels(p_indicator_manager: IndicatorManager) -> void:
	if not is_instance_valid(p_indicator_manager):
		_lines.collision_count = "Collisions: (no manager)"
		_lines.blocking = "Blocking: (no manager)"
		return

	var collision_count: int = p_indicator_manager.get_colliding_indicators().size()
	_lines.collision_count = "%d" % collision_count

	var bodies: Array[Node2D] = p_indicator_manager.get_colliding_nodes()
	if bodies.is_empty():
		_lines.blocking = "0"
	else:
		var names: PackedStringArray = []
		for body in bodies:
			if body != null:
				var n := str(body.name)
				if n.is_empty():
					n = body.get_class()
				names.append(n)
				if names.size() == MAX_BLOCKING_NAMES:
					break
		var total := bodies.size()
		var omitted := total - names.size()
		var parts: Array[String] = []
		# First line: total count
		parts.append(str(total))
		# Each blocking name on its own line for readability
		for n in names:
			parts.append(n)
		if omitted > 0:
			parts.append("+%d more" % omitted)
		_lines.blocking = "\n".join(parts)

func _render_debug() -> void:
	if debug_output == null:
		return
	var composed := ""
	var b := func(label: String) -> String: return "[b]%s[/b]" % label
	if display_mode == "VERTICAL":
		var ordered: Array[String] = []
		if _should_show_dependencies():
			ordered.append_array([
				b.call(LABEL_STATUS),
				_lines.status if _lines.status != "" else PLACEHOLDER_VALUE,
			])
		ordered.append_array([
			b.call(LABEL_MOUSE),
			_lines.mouse if _lines.mouse != "" else PLACEHOLDER_VALUE,
			b.call(LABEL_MAP),
			_lines.map if _lines.map != "" else PLACEHOLDER_VALUE,
			b.call(LABEL_INDICATOR),
			_lines.indicator if _lines.indicator != "" else PLACEHOLDER_VALUE,
			b.call(LABEL_COLLISIONS),
			_lines.collision_count if _lines.collision_count != "" else PLACEHOLDER_VALUE,
			b.call(LABEL_BLOCKING),
			_lines.blocking if _lines.blocking != "" else PLACEHOLDER_VALUE
		])
		composed = "\n".join(ordered)
	else: # HORIZONTAL
		var blocking_single_line: String = _lines.blocking.replace("\n", ", ") if _lines.blocking != "" else PLACEHOLDER_VALUE
		var ordered_h: Array[String] = []
		if _should_show_dependencies():
			ordered_h.append("%s %s" % [b.call(LABEL_STATUS), _lines.status if _lines.status != "" else PLACEHOLDER_VALUE])
		ordered_h.append_array([
			"%s %s" % [b.call(LABEL_MOUSE), _lines.mouse if _lines.mouse != "" else PLACEHOLDER_VALUE],
			"%s %s" % [b.call(LABEL_MAP), _lines.map if _lines.map != "" else PLACEHOLDER_VALUE],
			"%s %s" % [b.call(LABEL_INDICATOR), _lines.indicator if _lines.indicator != "" else PLACEHOLDER_VALUE],
			"%s %s" % [b.call(LABEL_COLLISIONS), _lines.collision_count if _lines.collision_count != "" else PLACEHOLDER_VALUE],
			"%s %s" % [b.call(LABEL_BLOCKING), blocking_single_line]
		])
		composed = "\n".join(ordered_h)
	if composed == _last_rendered:
		return
	_last_rendered = composed
	debug_output.text = composed

# -- Internal helpers -------------------------------------------------------

func _should_show_dependencies() -> bool:
	if _debug_settings == null:
		return false
	return _debug_settings.level >= GBDebugSettings.LogLevel.VERBOSE

func _update_map_line() -> void:
	if _targeting_state and _targeting_state.target_map:
		_lines.map = _targeting_state.target_map.name
	else:
		_lines.map = ""

func _on_target_map_changed(new_map: TileMapLayer) -> void:
	_lines.map = (new_map.name if new_map else "")
	_render_debug()

## Update indicator line only (no tile coordinates).
func _update_indicator_line(p_manager: IndicatorManager) -> void:
	if p_manager == null:
		return
	var count := 0
	if p_manager.has_method("get_colliding_indicators"):
		# Total indicators (colliding + non-colliding) provides more context; try to access internal indicator manager.
		if p_manager.has_method("get"):
			var im = p_manager.get("_indicator_manager")
			if im and im.has_method("get_indicators"):
				var arr = im.get_indicators()
				if typeof(arr) == TYPE_ARRAY:
					count = arr.size()
		# Fallback to colliding count if total unavailable
		if count == 0:
			var colliding: Array = p_manager.get_colliding_indicators()
			if typeof(colliding) == TYPE_ARRAY:
				count = colliding.size()
	_lines.indicator = str(count)
