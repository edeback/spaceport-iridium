class_name StorageOverlays
extends RefCounted

## The two storage dialogs WI-12 shipped, in one place (WI-56): the
## accepted-resource checklist and the dump-with-amount confirmation.
##
## They existed as two hidden sub-panels inside `ui_storage_component.tscn`, so
## they were reachable only from the inspector's storage tab - one module at a
## time, which is the access problem the Stores panel exists to fix. Duplicating
## them into a second surface would have meant two dump confirmations that could
## disagree about how much is actually vented, and *"dump destroys resources"* is
## not a rule to have two implementations of.
##
## So both are built here as modal dialogs, and both surfaces call in.
##
## ## Two rules these carry
##
## 1. **The confirmation states the amount, and the amount is the truth.**
##    WI-12's *auto*-dump already vents `stored − reserved_withdraw`
##    ([method StorageData.autodump_amount], hardened by WI-38 A4) - but its
##    *manual* dump capped at `stored` and withdrew against the reserve, so a
##    hauler already walking to the bin arrived to find the stock it had claimed
##    deleted. The dialog now caps at [method StorageData.available_to_withdraw]
##    and withdraws without touching reservations, so the two halves of "dump"
##    finally agree. Same `AVAIL ≠ HELD` distinction WI-55 drew for the trade
##    table.
## 2. **Auto-dump on a resource the station eats gets a warning** naming what will
##    starve - see [method StorageComponent.autodump_warning]. WI-12 noted this as
##    a kindness and skipped it; it matters now that the setting is one click from
##    a roster of every store on the station.
##
## Dialogs rather than in-panel overlays: invariant 1 says there is one panel and
## neither of these is a mode, and a question the player is halfway through
## answering must not be freed by the panel behind it closing (the same reason
## [CrewTabSet]'s fire confirmation parents to the HUD).

## Emitted through the callbacks rather than as signals: these are static builders,
## and a caller that wants to know something changed already knows - it asked.

## Both dialogs open at a **fixed** size and scroll their bodies.
##
## Not a minimum, a size (WI-58 follow-up). A [Window] takes the larger of the
## size it is popped at and `get_contents_minimum_size()`, and that measurement
## happens **once**, before any child has been given a width - which is exactly
## the case an autowrapped [Label] answers worst. `Label.get_minimum_size()` under
## `AUTOWRAP_WORD_SMART` reports the height of its text *at its current width*,
## and at that moment its width is zero, so it asks for one line per word. Four
## such notes drove the accepted-resources dialog off the bottom of the screen and
## took its `APPLY` and `CANCEL` buttons with it - the dialog was unusable, not
## merely ugly.
##
## The fix is structural rather than a tuned number: everything goes inside a
## [ScrollContainer], whose own vertical minimum is zero, so the contents minimum
## is the frame's fixed size and nothing inside can push it. This is WI-51's
## "measuring once is not enough" trap in the one place where re-measuring is not
## an option, because a Window sizes itself at popup.
const DIALOG_SIZE := Vector2i(520, 560)
const DUMP_SIZE := Vector2i(520, 460)

## Kept clear of the screen edges, so a dialog on a small display still shows its
## button bar.
const SCREEN_MARGIN: int = 80

# --- the accepted-resource checklist ------------------------------------------------

## Opens the accepted-resource checklist for `component`, calling `on_applied`
## once the player confirms.
##
## Newly checked resources are added; newly unchecked ones are removed, and
## anything they were still holding is dumped to the module's **overflow pile**
## rather than destroyed. That is WI-12's shipped behaviour and the reason its
## `draining` flag was dropped - see [01_Technical_Specification] §2.1. The rule
## it preserves is the standing one: unchecking a box is not an explicit action to
## lose resources, so the stock survives on the floor.
##
## A storage with `allow_any_resource` (a mining bay's output) has no fixed
## accepted list, so the checklist renders read-only - exactly as WI-12 specified.
static func open_edit(host: Node, component: StorageComponent, on_applied: Callable) -> void:
	if host == null or component == null:
		return
	var editable: bool = StoresModel.contents_editable(component) and not component.allow_any_resource
	var dialog := ConfirmationDialog.new()
	dialog.title = "Accepted resources · %s" % component.name
	dialog.ok_button_text = "Apply" if editable else "Close"

	var column: VBoxContainer = _dialog_body(dialog, DIALOG_SIZE)
	_section(column, "This bin", _edit_note(component))

	# The fill-meter toggle lives here rather than on the card: it is a display
	# preference, and putting it on a row of forty cards would spend a control slot
	# on the least interesting setting in the panel.
	#
	# **Never disabled**, whatever the bin's editability says: it is a preference
	# about the player's own screen, not a property of the bin. It also sits
	# *above* the resource list rather than under it, because the list is eighteen
	# rows and scrolls - a control that is always available must not be the one
	# below the fold.
	_section(column, "Display")
	var meter := CheckBox.new()
	meter.text = "Show the fill meter on the station"
	meter.button_pressed = component.display_storage_ui
	column.add_child(meter)

	_section(column, "Resources")
	var boxes: Dictionary[ResourceData, CheckBox] = {}
	for resource: ResourceData in _storable_resources():
		var box := CheckBox.new()
		box.text = resource.name
		box.icon = resource.icon
		box.add_theme_constant_override("icon_max_width", 24)
		box.button_pressed = component.storage_data.has(resource)
		box.disabled = not editable
		column.add_child(box)
		boxes[resource] = box

	dialog.confirmed.connect(func() -> void:
		if is_instance_valid(component):
			component.display_storage_ui = meter.button_pressed
			if editable:
				_apply_checklist(component, boxes)
		if on_applied.is_valid():
			on_applied.call()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	_show(host, dialog, DIALOG_SIZE)

static func _edit_note(component: StorageComponent) -> String:
	if component.allow_any_resource:
		return "This bay accepts anything, so its list is not editable."
	if not StoresModel.contents_editable(component):
		return StoresModel.locked_reason(component)
	return "Unchecking a stocked resource moves it to this module's overflow pile — it is not destroyed."

## Reconciles the component's stored-resource set with the boxes. Removals dump to
## the overflow pile first, which is the one thing this must not skip.
static func _apply_checklist(component: StorageComponent, boxes: Dictionary[ResourceData, CheckBox]) -> void:
	for resource: ResourceData in boxes:
		var checked: bool = boxes[resource].button_pressed
		var stored: bool = component.storage_data.has(resource)
		if checked and not stored:
			component.add_stored_resource(resource)
		elif not checked and stored:
			var amount: int = component.storage_data[resource].stored
			if amount != 0:
				dump_to_pile(component, resource, amount)
			component.remove_stored_resource(resource)

## Moves `amount` of `resource` out of the bin and onto the module's overflow
## pile. Shared because both the checklist above and the per-line remove button in
## the inspector's storage tab need exactly this, and getting it half-right loses
## the stock.
##
## `use_reserve = true` here, unlike the vent: this runs immediately before
## [method StorageComponent.remove_stored_resource], which cancels the bin's jobs
## and erases the slot outright - so a reservation-respecting withdraw that
## refused would leave stock in a slot about to be deleted. Everything must come
## out, and the claims die with the slot anyway.
static func dump_to_pile(component: StorageComponent, resource: ResourceData, amount: int) -> void:
	var withdrawn: Array[ResourceStack] = component.withdraw_stacks(resource, amount, true)
	if withdrawn.is_empty():
		return
	if component.owner_module != null:
		component.owner_module.get_or_create_overflow_pile().add_stacks(resource, withdrawn)
	else:
		# Components are always on modules; this is the completeness branch the
		# original had, kept so the stock cannot silently evaporate either way.
		var pile: ResourcePile = ResourcePile.spawn(
			Global.world_manager.pawn_layer, component.global_position)
		pile.add_stacks(resource, withdrawn)

static func _storable_resources() -> Array[ResourceData]:
	if Global.resource_manager == null:
		return [] as Array[ResourceData]
	return Global.resource_manager.storable_resources

# --- the dump confirmation -----------------------------------------------------------

## Opens the per-resource settings for one bin: **desired amount**, a one-off
## vent, and the auto-dump toggle - the three things WI-12 gave a resource line
## and which the Stores panel reaches through its content chip.
##
## **Dump destroys resources.** The standing rule is that the player never loses
## resources without an explicit action that loses them, with no "too small to
## matter" threshold - so this keeps its confirmation and the confirmation states
## the amount.
##
## The amount it can state is `stored − reserved_withdraw`: a hauler already
## walking here has claimed some of this stock. Capping at `stored` would quote a
## number the vent cannot honestly reach.
static func open_resource(host: Node, component: StorageComponent, resource: ResourceData,
		on_applied: Callable) -> void:
	if host == null or component == null or resource == null:
		return
	var data: StorageData = component.storage_data.get(resource)
	if data == null:
		return
	var ventable: int = data.available_to_withdraw()
	# The bin's own rule, not this dialog's (WI-58). It used to ask nothing, so the
	# Stores card - which disables its stepper and prints "set by the module" -
	# nonetheless wired every content chip straight into a dialog that writes
	# `desired` and destroys stock. Because [method StoresModel.lists] deliberately
	# keeps live construction sites, that reached a blueprint's construction import
	# bin, where it let the player rewrite the build's requirements and vent its
	# delivered materials. Read-only here means the contents and the averages are
	# still worth opening for; only the writes are gone.
	var editable: bool = StoresModel.contents_editable(component)

	var dialog := ConfirmationDialog.new()
	dialog.title = "%s in %s" % [resource.name, component.name]
	dialog.ok_button_text = "Apply" if editable else "Close"

	var column: VBoxContainer = _dialog_body(dialog, DUMP_SIZE)
	if not editable:
		# Named, not merely greyed: a blocked control says what blocks it (WI-57).
		var locked: Label = _note(StoresModel.locked_reason(component))
		locked.add_theme_color_override("font_color", UIPalette.ATTENTION_TEXT)
		column.add_child(locked)

	_section(column, "Held")
	var held := Label.new()
	held.theme_type_variation = UIType.METRIC
	held.text = "%d STORED · %d UNRESERVED" % [data.stored, ventable]
	column.add_child(held)
	if ventable < data.stored:
		column.add_child(_note(
			"A hauler has already claimed %d of this — only the unreserved stock is vented."
				% (data.stored - ventable)))

	# Desired is the *routing* half of this dialog and comes first: it is what
	# posts pull jobs (below it) and push jobs (above it), so it decides whether
	# there is ever a surplus for the two dump controls to act on.
	_section(column, "Keep", "Haulers top this bin up to here and carry the surplus away.")
	var desired: Stepper = Stepper.create()
	desired.configure(data.desired, 0, component.max_stored, 1, false)
	desired.editable = editable
	column.add_child(desired)

	_section(column, "Vent now",
		"Vented resources are destroyed. Only the unreserved stock can go.")
	var amount: Stepper = Stepper.create()
	amount.configure(0, 0, ventable, 1, false)
	amount.editable = editable and ventable > 0
	column.add_child(amount)

	var destroyed: Label = _note("")
	destroyed.add_theme_color_override("font_color", UIPalette.ATTENTION_TEXT)
	destroyed.visible = false
	column.add_child(destroyed)
	# The live restatement of what APPLY will do. Driven off `value_previewed`
	# rather than `value_changed`, because this is a readout and the stepper's
	# commit rule exists for work, not for text.
	var restate: Callable = func(value: int) -> void:
		destroyed.text = "%d %s will be destroyed. This cannot be undone." % [value, resource.name]
		destroyed.visible = value > 0
	amount.value_previewed.connect(restate)
	amount.value_changed.connect(restate)

	_section(column, "Automatically")
	var autodump := CheckBox.new()
	autodump.text = "Keep dumping the surplus automatically"
	autodump.button_pressed = data.autodump_enabled()
	autodump.disabled = not editable
	column.add_child(autodump)

	# The threshold, separate from `desired` since WI-65: `desired` is where
	# hauling stops filling this bin, and this is where the station starts
	# destroying what it could not move. The gap between them is the grace an
	# export job gets to find somewhere useful for the surplus first - with one
	# number the two raced and which won depended on whether a hauler was free.
	var above_row := HBoxContainer.new()
	above_row.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	column.add_child(above_row)
	above_row.add_child(_note("Auto-dump above"))
	var above := Stepper.create()
	# Floored at `desired`, not at zero: a threshold below the level hauling is
	# actively trying to reach would vent stock the bin has just asked for.
	above.configure(maxi(data.autodump_above, data.desired),
		data.desired, component.pool_for(data.role), 1, false)
	above.editable = editable
	above_row.add_child(above)

	# The warning is built up front and shown reactively rather than re-queried on
	# each toggle: it is a station scan, and the answer cannot change while a modal
	# is up (the sim keeps running, but a reactor is not built in that window).
	var warning: Label = _note(component.autodump_warning(resource))
	warning.add_theme_color_override("font_color", UIPalette.ATTENTION_TEXT)
	warning.visible = data.autodump_enabled() and not warning.text.is_empty()
	column.add_child(warning)
	var sync_autodump: Callable = func(pressed: bool) -> void:
		warning.visible = pressed and not warning.text.is_empty()
		above_row.visible = pressed
	sync_autodump.call(autodump.button_pressed)
	autodump.toggled.connect(sync_autodump)

	dialog.confirmed.connect(func() -> void:
		# The editability check is repeated here rather than relying on the disabled
		# controls: OK is still a real button on the read-only dialog (it says CLOSE),
		# and a write path that is only guarded by a widget's `disabled` flag is one
		# input-synthesis bug away from firing anyway.
		if editable and is_instance_valid(component) and component.storage_data.has(resource):
			component.storage_data[resource].desired = desired.value
			if amount.value > 0:
				# Gone forever - the explicit action that loses resources.
				#
				# `use_reserve = false`, deliberately: with `true` the withdraw
				# checks against `stored` and then *decrements* reserved_withdraw,
				# which would let the vent eat stock a hauler has already claimed
				# and credit that hauler's reservation back at the same time. The
				# stepper is capped at the unreserved figure, so the honest call is
				# the one that also asserts it.
				component.withdraw_stacks(resource, amount.value, false)
			# -1 is the disabled sentinel, so there is one field rather than a
			# bool beside a threshold that could disagree with it.
			component.storage_data[resource].autodump_above = \
				above.value if autodump.button_pressed else -1
		if on_applied.is_valid():
			on_applied.call()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	_show(host, dialog, DUMP_SIZE)

# --- shared bits ----------------------------------------------------------------------

static func _note(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = UIType.BODY
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
	label.text = text
	return label

## Builds a dialog's body and returns the column callers fill.
##
## The shape is fixed frame → scroll → column, for the reason
## [constant DIALOG_SIZE] documents: it is what stops an autowrapped note from
## sizing the window. Callers add rows to the column and never think about it
## again.
static func _dialog_body(dialog: ConfirmationDialog, size: Vector2i) -> VBoxContainer:
	var frame := VBoxContainer.new()
	frame.name = "Frame"
	frame.custom_minimum_size = Vector2(float(size.x), float(size.y))
	dialog.add_child(frame)

	var scroll := ScrollContainer.new()
	scroll.name = "Body"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", UIMetrics.ROW_GAP)
	scroll.add_child(column)
	return column

## Pops the dialog at the size it asked for, clamped to the viewport so its button
## bar is always reachable.
static func _show(host: Node, dialog: ConfirmationDialog, size: Vector2i) -> void:
	host.add_child(dialog)
	# A read-only dialog's OK button says CLOSE, which leaves CANCEL standing
	# beside it as a second control that does the same nothing.
	if dialog.get_cancel_button() != null:
		dialog.get_cancel_button().visible = dialog.ok_button_text != "Close"
	var screen: Vector2i = UIMetrics.SCREEN_SIZE
	var viewport: Viewport = host.get_viewport()
	if viewport != null:
		screen = Vector2i(viewport.get_visible_rect().size)
	dialog.popup_centered(Vector2i(
		mini(size.x, maxi(screen.x - SCREEN_MARGIN, 320)),
		mini(size.y, maxi(screen.y - SCREEN_MARGIN, 240))))

## A labelled block: the section rule, then whatever the block is about, then its
## explanation underneath.
##
## Stacked rather than laid out as caption-control-note in a row, which is what
## the dump dialog did and why it read as malformed: an autowrapped note sharing
## an [HBoxContainer] with a [Stepper] gets whatever width is left after the
## stepper's fixed 106px, wraps to five or six lines, and drags the row's height
## up around a control sitting centred in the middle of it.
static func _section(column: VBoxContainer, title: String, note: String = "") -> void:
	if column.get_child_count() > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size.y = float(UIMetrics.ROW_GAP)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(spacer)
	column.add_child(SectionLabel.create(title))
	if not note.is_empty():
		column.add_child(_note(note))
