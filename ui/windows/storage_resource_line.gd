class_name StorageResourceLine
extends HBoxContainer

## One resource in the inspector's storage tab: its name, how much is held
## against how much the bin wants, and the two controls that change either.
##
## **Converted to the design system in WI-58.** It was the worst single file in
## the seam WI-51 deviations 7-8 left un-ported: four Kenney placeholder
## textures, two 16px font overrides, a raw crimson `self_modulate`, a **12x12**
## destructive [TextureButton] - the smallest interactive control in the HUD, and
## one that dumps a resource's whole stock to a pile - and a bare [SpinBox].
##
## The [SpinBox] was the load-bearing one. `base_theme.tres` has no `SpinBox/*`
## entries and [SpinBox] extends [Range], not [LineEdit], so Godot resolved its
## arrows from the engine's default **light** theme inside a dark console. It is
## a [Stepper] now, which also buys the commit rule for free: the old box fired
## `value_changed` on every step, so dragging a desired amount across its range
## wrote a value per pixel.

@export var stored_resource_name: Label
@export var stored_resource_value: Label
@export var remove_resource_button: ActionButton
## Desired amount. Named for what it is rather than for the control it used to
## be - it has not been a [SpinBox] since WI-58.
@export var desired_stepper: Stepper
@export var debug_add_button: ActionButton
@export var dump_button: ActionButton
## The `⌦` glyph, in amber, when this slot is auto-dumping. The same glyph the
## Stores card's chips use, so a silently destroying setting reads the same way
## on both surfaces.
@export var autodump_indicator: Label

func _ready() -> void:
	if autodump_indicator != null:
		autodump_indicator.add_theme_color_override("font_color", UIPalette.ATTENTION)

## Renders the line read-only, for a bin whose contents are decided by the module
## rather than by the player ([method StoresModel.contents_editable]).
##
## **Every control that promises an action goes**, including `DUMP`: a button that
## offers to vent a resource the player is not allowed to vent is worse than no
## button, and the dialog behind it has nothing left to change on such a bin. The
## amount and the desired figure stay, because those are what the line is for -
## locked is a state, not an absence (WI-54), and the state here is the number.
##
## Note this says nothing about the bin's **priority**, which is on the tab rather
## than the line and is always the player's ([method StoresModel.priority_editable]).
func set_editable(editable: bool) -> void:
	if remove_resource_button != null:
		remove_resource_button.visible = editable
	if dump_button != null:
		dump_button.visible = editable
	if desired_stepper != null:
		desired_stepper.editable = editable
