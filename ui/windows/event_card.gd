class_name EventCard
extends Control

## Modal event card (WI-13). Pauses the sim while open (restoring the prior
## pause state on close - UI stays real-time by design) and drains
## EventManager's pending queue sequentially, so two events forced in the
## same tick show one after the other. There is no close button: every event
## card is resolved through a choice, and authored events are validated to
## always keep at least one cost-free choice.

## This card's entry in [TimeManager]'s hold set (WI-53). A named hold rather
## than the old remembered-prior-state flag, so an event card and a critical
## alert can stop the sim at the same time without un-pausing each other.
const PAUSE_HOLD: StringName = &"event_card"

var _event: EventData = null

func _ready() -> void:
	visible = false
	SignalBus.event_triggered.connect(_on_event_triggered)

func _on_event_triggered(_triggered: EventData) -> void:
	# Notification-only events never enter the pending queue; card events
	# wait their turn if one is already showing.
	if not visible:
		_show_next()

func _show_next() -> void:
	var next: EventData = Global.event_manager.peek_pending()
	if next == null:
		if visible:
			visible = false
			Global.time_manager.release_pause(PAUSE_HOLD)
		return
	if not visible:
		Global.time_manager.hold_pause(PAUSE_HOLD)
		visible = true
	_event = next
	_populate()

func _populate() -> void:
	%TitleLabel.text = _event.title
	%BodyLabel.text = _event.body
	for child: Node in %ChoiceButtons.get_children():
		child.queue_free()
	for choice: EventChoice in _event.choices:
		if choice != null:
			%ChoiceButtons.add_child(_build_choice(choice))

func _build_choice(choice: EventChoice) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var button := Button.new()
	var affordable: bool = choice.can_afford()
	button.text = choice.label if choice.cost.is_empty() else "%s  (%s)" % [choice.label, choice.cost_text()]
	if not affordable:
		button.disabled = true
		button.text += "  — can't afford"
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(_on_choice_pressed.bind(choice))
	box.add_child(button)
	var detail: String = choice.description
	var effect_parts: Array[String] = []
	for effect: EventEffect in choice.effects:
		if effect != null and not effect.describe().is_empty():
			effect_parts.append(effect.describe())
	if not effect_parts.is_empty():
		detail += ("  " if not detail.is_empty() else "") + "[" + ", ".join(effect_parts) + "]"
	if not detail.is_empty():
		var detail_label := Label.new()
		detail_label.text = detail
		detail_label.add_theme_font_size_override("font_size", 14)
		detail_label.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(detail_label)
	return box

func _on_choice_pressed(choice: EventChoice) -> void:
	if Global.event_manager.resolve_choice(_event, choice):
		_show_next()
