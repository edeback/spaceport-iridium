@tool
class_name SectionLabel
extends HBoxContainer

## Accent bar, caps label, trailing gradient rule (WI-49) - the divider that
## opens a section inside a panel.
##
## The rule *fades out* rather than running to the edge, so a section reads as
## opening rather than as being boxed off. That is the difference between this
## and an [HSeparator], and the reason panels should not use one.
##
## Upper-cases its own text, per the "caps lives in the widget that owns the
## label" rule (WI-49 §3).

const SCENE_PATH: String = "res://ui/theme/widgets/section_label.tscn"

@export var text: String = "SECTION":
	set(value):
		text = value
		_apply()

## Sections are normally cyan; an amber one marks a block the player is being
## asked to look at (an ARC demand, a failing subsystem).
@export var accent_color: Color = UIPalette.LIVE:
	set(value):
		accent_color = value
		_apply()

## A hotkey hint parked at the far end of the rule ("CATEGORIES ——— Q/E"). Same
## slot and the same weight as a panel header's hotkey, because it means the same
## thing: this block has a key. Empty hides it.
@export var hint: String = "":
	set(value):
		hint = value
		_apply()

var _accent: ColorRect
var _label: Label
var _rule: TextureRect
var _hint: Label

static func create(section_text: String = "") -> SectionLabel:
	var section: SectionLabel = (load(SCENE_PATH) as PackedScene).instantiate() as SectionLabel
	if not section_text.is_empty():
		section.text = section_text
	return section

func _ready() -> void:
	_ensure_refs()
	_apply()

func _ensure_refs() -> void:
	if _label != null:
		return
	_accent = get_node_or_null("Accent") as ColorRect
	_label = get_node_or_null("Label") as Label
	_rule = get_node_or_null("Rule") as TextureRect
	_hint = get_node_or_null("Hint") as Label

func _apply() -> void:
	_ensure_refs()
	if _label == null:
		return
	_label.text = text.to_upper()
	_accent.color = accent_color
	_accent.custom_minimum_size = Vector2(
		float(UIMetrics.ACCENT_BAR_WIDTH), float(UIMetrics.READOUT_ACCENT_HEIGHT))
	_rule.texture = UIPalette.section_rule_gradient()
	if _hint != null:
		_hint.text = hint
		_hint.visible = not hint.is_empty()
