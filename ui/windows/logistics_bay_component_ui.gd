class_name LogisticsBayComponentUI
extends ModuleComponentUI

## Info-panel tab for a Logistics Bay (WI-27): shows the robot count against the
## effective cap and a buy button that spends credits. Code-generated like
## LocalUpgradesTab so the info panel can add it like any other component UI.

var bay: LogisticsBayComponent
var _robots_label: Label
var _buy_button: Button

func set_logistics_bay(component: LogisticsBayComponent) -> void:
	bay = component
	name = "Logistics Bay"

	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_robots_label = Label.new()
	_robots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_robots_label)

	_buy_button = Button.new()
	_buy_button.pressed.connect(_on_buy_pressed)
	vbox.add_child(_buy_button)

	_refresh()

func _process(_delta: float) -> void:
	# Count and affordability drift over time (robots bought, credits earned);
	# cheap enough to just poll while the panel is open (mirrors MiningComponentUI).
	if bay != null:
		_refresh()

func _refresh() -> void:
	_robots_label.text = "Hauler robots: %d / %d" % [bay.robots.size(), bay.effective_max_robots()]
	_buy_button.text = "Buy robot (%d cr)" % bay.robot_cost
	_buy_button.disabled = not bay.can_buy_robot()

func _on_buy_pressed() -> void:
	bay.buy_robot()
	_refresh()
