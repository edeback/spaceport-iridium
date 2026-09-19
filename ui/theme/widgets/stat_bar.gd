@tool
class_name StatBar
extends VBoxContainer

## Label, value, and a hatched 8px bar (WI-49).
##
## This replaces every hand-built `ProgressBar` + `Label` pair in the codebase -
## `pawn_info_panel._make_stat_row`, `module_info_ingame_panel._build_hp_row`,
## the needs tab, the robot rows. Those all drew the same thing four slightly
## different ways, which is invariant 6 in miniature.
##
## The tint is the caller's decision, not the bar's: "amber below 50%" is a rule
## about the *stat*, and a bar that decided it for you would apply it to hull
## integrity and food alike. Callers that want the standard signed treatment
## pass [method UIPalette.sign_color].

const SCENE_PATH: String = "res://ui/theme/widgets/stat_bar.tscn"

var _label: Label
var _value: Label
var _bar: HatchBar

static func create() -> StatBar:
	return (load(SCENE_PATH) as PackedScene).instantiate() as StatBar

func _ready() -> void:
	_ensure_refs()

func _ensure_refs() -> void:
	if _label != null:
		return
	_label = get_node_or_null("Row/Label") as Label
	_value = get_node_or_null("Row/Value") as Label
	_bar = get_node_or_null("Bar") as HatchBar

## `fraction` is 0..1; `value_text` is whatever the player should read (a
## percentage, "34/120", "2.4 kPa") - the bar never formats a number, because
## the units are the caller's business.
func configure(label_text: String, fraction: float, value_text: String,
		tint: Color = UIPalette.LIVE) -> void:
	_ensure_refs()
	if _label == null:
		return
	_label.text = label_text.to_upper()
	_value.text = value_text
	_value.add_theme_color_override("font_color", tint)
	_bar.fill_color = tint
	_bar.fraction = fraction

## Updates only the moving parts, for a bar that refreshes on a tick.
func set_value(fraction: float, value_text: String, tint: Color = UIPalette.LIVE) -> void:
	_ensure_refs()
	if _bar == null:
		return
	_value.text = value_text
	_value.add_theme_color_override("font_color", tint)
	_bar.fill_color = tint
	_bar.fraction = fraction
