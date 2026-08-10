@tool
class_name ActionButton
extends Button

## The design's three button weights (WI-49), in one control.
##
## The reason this is a widget rather than "set a type variation yourself": the
## **destructive weight is outline only, never a filled button** is a stated
## invariant, and an invariant that lives only in a palette table is one every
## new panel gets to rediscover. Encoding it here means no panel can get it
## wrong, because there is no way to ask for a filled red button.
##
## Caps is a content decision (Godot has no text-transform), so it happens here,
## once, rather than as `.to_upper()` scattered through panel code. Use
## [method set_label] to change the text afterwards.

enum Weight {
	## The one thing this panel is for. LIVE-tinted fill, LIVE border.
	PRIMARY,
	## Everything else. Dim fill, control border.
	SECONDARY,
	## Demolish and fire. Outline only.
	DESTRUCTIVE,
}

const SCENE_PATH: String = "res://ui/theme/widgets/action_button.tscn"

@export var weight: Weight = Weight.SECONDARY:
	set(value):
		weight = value
		_apply_weight()

## Whether the label is upper-cased. On by default because every button in the
## design is caps; off for the rare button whose text is a proper noun.
@export var caps: bool = true:
	set(value):
		caps = value
		set_label(text)

static func create(label: String = "", button_weight: Weight = Weight.SECONDARY) -> ActionButton:
	var button: ActionButton = load(SCENE_PATH).instantiate() as ActionButton
	button.weight = button_weight
	button.set_label(label)
	return button

func _ready() -> void:
	_apply_weight()
	set_label(text)

## Sets the button's text, applying the caps rule. Assigning `text` directly
## bypasses it, which is legal but is how a lower-case button gets shipped.
func set_label(value: String) -> void:
	text = value.to_upper() if caps else value

func _apply_weight() -> void:
	match weight:
		Weight.PRIMARY:
			theme_type_variation = UIType.ACTION_PRIMARY
		Weight.DESTRUCTIVE:
			theme_type_variation = UIType.ACTION_DESTRUCTIVE
		_:
			theme_type_variation = UIType.ACTION_SECONDARY
