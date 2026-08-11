class_name RaidReadout
extends ReadoutPanel

## The live-raid readout (WI-53): ship count, the shrinking payoff, and the HAIL
## button that pays it.
##
## This is what became of WI-32's top-centre raid banner. WI-53 turns the raid
## *starting* into a critical alert, which is the part that has to be unmissable
## - but the banner also carried `RaidManager.pay_off()`, and that is a real
## action the player would otherwise lose for the length of three work items. So
## the state and the button move into the right column as a proper readout,
## stacked under the alert feed while a raid is on and gone the rest of the time,
## rather than staying a bespoke panel floating over the middle of the station.
##
## WI-57 gave ARC its own surface and put the payoff there too, in the Comms
## panel's ARC block - hailing raiders for terms is the same category of action as
## hailing ARC. **This readout stays**, deliberately: it is permanently on screen
## during a fight, and WI-57 §6 flags its own risk that a payoff buried one
## keypress deep is too slow while the beams are landing. Two entry points to one
## action, which is the pattern the crew roster and the alert feed already use for
## selection.

const SCENE_PATH: String = "res://ui/alerts/raid_readout.tscn"

var _ships: Label
var _payoff: Label
var _hail: ActionButton

static func create() -> RaidReadout:
	return load(SCENE_PATH).instantiate() as RaidReadout

func _ready() -> void:
	super()
	_build_body()
	SignalBus.raid_started.connect(_on_raid_started)
	SignalBus.raid_ended.connect(_on_raid_ended)
	# Ship count, payoff price and warning phase all move without a start/end
	# cycle, and this is the one signal that covers all three (WI-32).
	SignalBus.raid_state_changed.connect(refresh)
	refresh()

func _build_body() -> void:
	panel_width = UIMetrics.RIGHT_COLUMN_WIDTH
	content_padding = UIMetrics.READOUT_CONTENT_PAD
	content_height = UIMetrics.ALERT_RAID_HEIGHT - UIMetrics.READOUT_HEADER_HEIGHT
	label = "Hostiles"
	accent_color = UIPalette.ATTENTION

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	content().add_child(column)

	_ships = Label.new()
	_ships.theme_type_variation = UIType.ENTITY_NAME
	_ships.add_theme_color_override("font_color", UIPalette.ATTENTION_TEXT)
	column.add_child(_ships)

	_payoff = Label.new()
	_payoff.theme_type_variation = UIType.META_LINE
	_payoff.add_theme_color_override("font_color", UIPalette.ATTENTION_META)
	column.add_child(_payoff)

	_hail = ActionButton.create("Hail — pay off", ActionButton.Weight.SECONDARY)
	_hail.pressed.connect(_on_hail_pressed)
	column.add_child(_hail)

func _on_raid_started(_strength: float) -> void:
	refresh()

func _on_raid_ended(_outcome: StringName) -> void:
	refresh()

## Hides itself when no raid is on. A readout that is only sometimes there is
## normally a layout smell, but a raid is the one state the right column should
## visibly change shape for - and [UIMain] re-stacks the column around it, so
## nothing below jumps by an unaccounted amount.
func refresh() -> void:
	var manager: RaidManager = Global.raid_manager
	var active: bool = manager != null and manager.active
	visible = active
	if not active or _ships == null:
		return
	_ships.text = "%d hostile ship(s) closing" % manager.ship_count()
	var price: int = manager.current_payoff()
	_payoff.text = "PAYOFF %d CR · FALLING" % price
	_hail.set_label("Hail — pay %d cr" % price)
	_hail.disabled = not manager.can_pay_off()

func _on_hail_pressed() -> void:
	if Global.raid_manager != null:
		Global.raid_manager.pay_off()
