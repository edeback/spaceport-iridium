class_name ProcessorComponent
extends ComponentBase

@export var recipe: RecipeData
## When this holds 2+ recipes, the player can switch the processor between
## them (ore refinery). Empty or single-entry = fixed-recipe processor,
## exactly the pre-WI-09 behavior, and input storage is never touched.
@export var available_recipes: Array[RecipeData] = []
@export var input_storage: StorageComponent
@export var output_storage: StorageComponent
@export var time_to_process: float = 1
@export var power_consumer: PowerConsumptionComponent

## Stat key routed through the owner module's stat-modifier layer. A MULT < 1
## from a "faster processing" upgrade shortens the effective processing time.
const STAT_PROCESS_TIME := &"process_time"

## Richness assumed for a variant-resource stack that carries no instance
## data (ore mined before variance existed, debug-added stock).
const DEFAULT_RICHNESS: float = 0.5

var processing: bool = false
var current_process_time: float = 0

## Weighted-average richness of the variant inputs consumed by the batch
## currently processing; -1 when the batch has no variant inputs, in which
## case outputs stay exactly recipe-sized.
var current_batch_richness: float = -1.0

## Fractional output units carried across batches (per output resource) so
## long-run yield matches the richness curve exactly - no rounding drift, and
## a poor batch whose output rounds to zero still credits its fraction
## forward instead of leaking it.
var _yield_residue: Dictionary[ResourceData, float] = {}

## Non-null while a batch is mid-process and the player picked a different
## recipe; applied when the batch completes so already-consumed inputs
## finish at the recipe they were withdrawn for.
var pending_recipe: RecipeData = null

signal processor_progress_changed(new_progress: float)
signal batch_richness_changed(new_richness: float)
signal recipe_changed(new_recipe: RecipeData)

## Effective time to complete one recipe, after upgrades. Falls back to the raw
## base value if this component isn't attached to a module yet.
func get_process_time() -> float:
	if owner_module != null:
		return owner_module.get_effective_stat(STAT_PROCESS_TIME, time_to_process)
	return time_to_process

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	assert(recipe != null, "Processor must have recipe!")
	assert(input_storage != null, "Processor must have input_storage!")
	assert(output_storage != null, "Processor must have output_storage!")
	assert(power_consumer != null, "Processor must have power_consumer!")
	assert(time_to_process > 0, "Processor time_to_process must be > 0!")
	assert(available_recipes.is_empty() or available_recipes.has(recipe), "Default recipe must be among available_recipes!")
	super()

func ready_preview() -> void:
	set_process(false)

func ready_blueprint() -> void:
	set_process(false)

func ready_constructed() -> void:
	add_to_group("processor")
	set_process(true)
	if can_select_recipes():
		_sync_storages()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	if !power_consumer.powered:
		# Do nothing if unpowered
		last_error = "No power!"
		return
	_stepwise_processing(sim_delta)

func can_select_recipes() -> bool:
	return available_recipes.size() > 1

## Player-facing recipe switch. Mid-batch the switch is queued and applied
## when the current batch completes, so inputs already consumed aren't wasted.
func select_recipe(new_recipe: RecipeData) -> void:
	if new_recipe == null or new_recipe == recipe:
		pending_recipe = null
		return
	assert(available_recipes.has(new_recipe), "Selected recipe not in available_recipes!")
	if processing:
		pending_recipe = new_recipe
	else:
		_apply_recipe(new_recipe)

func _apply_recipe(new_recipe: RecipeData) -> void:
	pending_recipe = null
	recipe = new_recipe
	# Residue for outputs the new recipe doesn't produce is always < 1 unit;
	# drop it rather than crediting it to a much-later switch back.
	for output: ResourceData in _yield_residue.keys():
		if not recipe.outputs.has(output):
			_yield_residue.erase(output)
	_sync_storages()
	recipe_changed.emit(recipe)

## Reconfigures input/output storage slots to match the current recipe.
## Only ever called on selectable-recipe processors - fixed-recipe scenes
## keep whatever their storage was authored with.
func _sync_storages() -> void:
	for resource: ResourceData in input_storage.storage_data.keys():
		if not recipe.inputs.has(resource):
			_clear_input_slot(resource)
	for ingredient: ResourceData in recipe.inputs:
		input_storage.add_stored_resource(ingredient)
		# Explicit rather than relying on add_stored_resource: the slot may
		# survive a round-trip switch (had stock) with desired zeroed below.
		input_storage.storage_data[ingredient].desired = input_storage.max_stored
	for resource: ResourceData in output_storage.storage_data.keys():
		var data: StorageData = output_storage.storage_data[resource]
		if not recipe.outputs.has(resource) and data.stored <= 0 and data.reserved_deposit <= 0:
			output_storage.remove_stored_resource(resource)
	for output: ResourceData in recipe.outputs:
		output_storage.add_stored_resource(output)
		# Outputs are pure surplus - desired 0 keeps the export posting
		# pushing refined goods out to general storage.
		output_storage.storage_data[output].desired = 0

## Retires an input slot the current recipe no longer uses. Stock must not be
## destroyed (jobs invariant), and the refinery input doesn't post exports
## (accepts_exports = false), so leftovers go to the module's overflow pile,
## whose collection jobs haul them to any storeroom with space.
func _clear_input_slot(resource: ResourceData) -> void:
	var data: StorageData = input_storage.storage_data[resource]
	# Cancel incoming hauls first: the pawns keep their cargo and
	# Job_StoreInventory re-homes it, and cancellation reconciles the slot's
	# reservations to zero so the drain below sees the true stored count.
	data.end_all_jobs()
	if data.stored > 0 and input_storage.owner_module != null:
		var leftovers: Array[ResourceStack] = input_storage.withdraw_stacks(resource, data.stored, true)
		if not leftovers.is_empty():
			input_storage.owner_module.get_or_create_overflow_pile().add_stacks(resource, leftovers)
	input_storage.remove_stored_resource(resource)

func _satisfies_recipe() -> bool:
	for ingredient in recipe.inputs:
		var amount := recipe.inputs[ingredient]
		if !input_storage.can_withdraw(ingredient, amount):
			last_error = "Missing input!"
			return false
	for output in recipe.outputs:
		var amount := recipe.outputs[output]
		if !output_storage.can_deposit(output, amount):
			last_error = "No space for output!"
			return false
	return true

## Withdraws the batch's inputs as real stacks and records their
## amount-weighted average richness (variant inputs only).
func _withdraw_inputs() -> void:
	var variant_units: int = 0
	var richness_weighted: float = 0.0
	for ingredient in recipe.inputs:
		var amount := recipe.inputs[ingredient]
		var stacks: Array[ResourceStack] = input_storage.withdraw_stacks(ingredient, amount)
		var withdrawn: int = 0
		for stack: ResourceStack in stacks:
			withdrawn += stack.amount
			if ingredient.has_variance:
				var richness: float = DEFAULT_RICHNESS
				if stack.instance_data != null:
					richness = stack.instance_data.get_primary_value()
				richness_weighted += richness * stack.amount
				variant_units += stack.amount
		assert(withdrawn == amount, "Somehow couldn't withdraw items that were available!")
	current_batch_richness = richness_weighted / variant_units if variant_units > 0 else -1.0
	batch_richness_changed.emit(current_batch_richness)

func _scaled_output(base_amount: int) -> float:
	if current_batch_richness < 0.0:
		return float(base_amount)
	return base_amount * lerpf(recipe.min_yield_mult, recipe.max_yield_mult, current_batch_richness)

## Deposits the batch's outputs, scaled by batch richness. Whole units only;
## the fractional remainder per output carries in _yield_residue toward the
## next batch (so a scaled 0.7 yields nothing now but 1 extra soon). Returns
## false without touching residue when the output storage lacks room - safe
## to retry next frame.
func _try_deposit_outputs() -> bool:
	var whole_amounts: Dictionary[ResourceData, int] = {}
	var total_out: int = 0
	for output in recipe.outputs:
		var with_residue: float = _scaled_output(recipe.outputs[output]) + _yield_residue.get(output, 0.0)
		var whole: int = int(with_residue)
		if whole > 0 and not output_storage.can_deposit(output, whole):
			last_error = "No space for output!"
			return false
		whole_amounts[output] = whole
		total_out += whole
	# can_deposit checks each output alone; two outputs can each fit but not
	# together, so check the combined room too before committing anything.
	if total_out > output_storage.space_available():
		last_error = "No space for output!"
		return false
	for output in recipe.outputs:
		var with_residue: float = _scaled_output(recipe.outputs[output]) + _yield_residue.get(output, 0.0)
		var whole: int = whole_amounts[output]
		_yield_residue[output] = with_residue - whole
		if whole > 0:
			var doublecheck: bool = output_storage.deposit(output, whole)
			assert(doublecheck, "Somehow couldn't output items when there was room!")
	return true

func _stepwise_processing(delta: float) -> void:
	if processing:
		var effective_time: float = get_process_time()
		current_process_time += delta
		processor_progress_changed.emit(current_process_time / effective_time)
		if current_process_time >= effective_time:
			if not _try_deposit_outputs():
				return
			processor_progress_changed.emit(0)
			processing = false
			current_process_time = 0
			current_batch_richness = -1.0
			batch_richness_changed.emit(current_batch_richness)
			if pending_recipe != null:
				_apply_recipe(pending_recipe)
		last_error = ""
	else:
		if _satisfies_recipe():
			_withdraw_inputs()
			processor_progress_changed.emit(0)
			processing = true
			current_process_time = 0
			last_error = ""

# --- persistence ------------------------------------------------------------
# Mid-batch progress and residue are deliberately not saved (matching the
# pre-existing behavior of losing in-progress batches); only the selected
# recipe is, because input/output storage configuration depends on it.

func get_save_data() -> Dictionary:
	if not can_select_recipes() or recipe == null:
		return {}
	return {"recipe": recipe.resource_path}

func load_save_data(data: Dictionary) -> void:
	var path: String = data.get("recipe", "")
	if path == "" or not can_select_recipes():
		return
	# load() returns the cached instance, so equality against
	# available_recipes entries holds.
	var loaded: RecipeData = load(path) as RecipeData
	if loaded == null or not available_recipes.has(loaded):
		push_warning("Saved processor recipe not available, keeping default: " + path)
		return
	select_recipe(loaded)

func has_ui() -> bool:
	return true

func get_ui() -> ModuleComponentUI:
	var ui: ProcessorComponentUI = ui_info_panel_element.instantiate() as ProcessorComponentUI
	ui.set_processor_component(self)
	return ui
