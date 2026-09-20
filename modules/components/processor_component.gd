class_name ProcessorComponent
extends ComponentBase

@export var recipe: RecipeData
## LEGACY (WI-47 M8): eligibility now lives on RecipeData.processor_tags, and
## get_available_recipes() assembles the list from the scanned index. This array
## is still unioned in so an unmigrated scene keeps working, and any entry that
## reaches the union warns. Delete it once every scene is clean - a mod cannot
## reach it, which is the whole reason eligibility moved.
@export var available_recipes: Array[RecipeData] = []

## Cache for get_available_recipes(). Not saved and never invalidated: a module's
## tags and the recipe index are both fixed for the life of the run.
var _resolved_recipes: Array[RecipeData] = []
var _recipes_resolved: bool = false
## The module's single bin (WI-65). Its ingredient slots are INPUT and its
## product slots are OUTPUT, both assigned by _sync_storages() from the recipe -
## which is why the roles are derived rather than saved.
@export var storage: StorageComponent
@export var time_to_process: float = 1
@export var power_consumer: PowerConsumptionComponent

## When true (WI-23), a batch still readies automatically (inputs withdrawn, held
## at partial progress) but progress only advances while a pawn is working at the
## module - the work job drives current_process_time via advance_work().
## Existing scenes default false = fully-automated, byte-for-byte the pre-WI-23
## behavior; refinery/forge opt in, solar/scrubber stay unmanned.
@export var requires_worker: bool = false
## Skill (WI-22) that gates a manned batch's work rate and earns xp. Only
## consulted when requires_worker.
@export var worker_skill: StringName = &"crafting"

## Food quality (WI-29): how much a max-level worker adds to a food recipe's
## output_quality_base. The operator's worker_skill level scales linearly from 0
## (unskilled: base unchanged) to this at MAX_LEVEL. Ignored for unmanned
## producers (no worker -> no shift) and non-food recipes (output_quality_base < 0).
@export var worker_quality_shift_at_max: float = 0.35

## Richness assumed for a variant-resource stack that carries no instance
## data (ore mined before variance existed, debug-added stock).
const DEFAULT_RICHNESS: float = 0.5

var processing: bool = false
var current_process_time: float = 0

## Work done since something last asked, measured in BATCH FRACTIONS (WI-60):
## 1.0 means one whole batch's worth of progress advanced, however long that
## took. HeatEmitterComponent drains it to bill waste heat.
##
## Fractions rather than seconds is the load-bearing part. A heat throttle
## multiplies get_process_time() up, so the same second of work buys a smaller
## fraction - which is exactly "heat proportional to how much it produces", and
## it makes the throttle self-limiting with no code that knows it is a loop.
## Counting seconds would keep billing full heat for a machine crawling at a
## quarter rate.
##
## Not saved: it is drained every heat pass, so at most a fraction of a game-hour
## of billing exists at any moment, and heat is not a resource the player owns.
var _work_accumulated: float = 0.0

## Weighted-average richness of the variant inputs consumed by the batch
## currently processing; -1 when the batch has no variant inputs, in which
## case outputs stay exactly recipe-sized.
var current_batch_richness: float = -1.0

## Fractional output units carried across batches (per output resource) so
## long-run yield matches the richness curve exactly - no rounding drift, and
## a poor batch whose output rounds to zero still credits its fraction
## forward instead of leaking it.
## Saved (WI-45 A2): every entry is under one unit by construction, but it is
## still output the player's inputs paid for, and a save/load is not something
## they did to discard it. A recipe switch dropping the entries the new recipe
## can't use stays as-is - that one is an explicit choice.
var _yield_residue: Dictionary[ResourceData, float] = {}

## Non-null while a batch is mid-process and the player picked a different
## recipe; applied when the batch completes so already-consumed inputs
## finish at the recipe they were withdrawn for.
var pending_recipe: RecipeData = null

## Manned processing (WI-23). The outstanding work job for this module -
## either sitting on the board unclaimed, being walked to, or actively advancing
## a batch. Live means "a worker is already accounted for", so _manned_processing
## won't post a second. The batch loop lives inside the driver (next_index_after
## re-enters the work action while work remains), so the operating pawn stays at
## the machine across batches with no board round-trip.
var _work_slot: JobSlot = JobSlot.new()
## Set by advance_work() each time a worker drives a batch; read and cleared by
## _manned_processing() once per frame to tell "actively worked" (progress bar
## live) from "waiting for a worker" (stalled, distinct from unpowered).
var _worked_this_frame: bool = false

## The pawn currently operating this processor (WI-29 food quality). Set by the
## driven by the work job each Working tick and read at batch completion to
## shift food output quality by the worker's skill. Null for unmanned producers
## and between shifts - then food outputs deposit at the recipe's base quality.
var current_worker: PawnBase = null

signal processor_progress_changed(new_progress: float)
signal batch_richness_changed(new_richness: float)
signal recipe_changed(new_recipe: RecipeData)

## Effective time to complete one recipe, after upgrades. Falls back to the raw
## base value if this component isn't attached to a module yet.
func get_process_time() -> float:
	if owner_module != null:
		return owner_module.get_effective_stat(Stats.PROCESS_TIME, time_to_process)
	return time_to_process

## What this processor's scene needs and does not have (WI-72 §2). Four of these
## were `assert`s, which a release export strips - so the build a player runs had
## no check at all and a half-wired processor simply stood there.
func wiring_fault() -> String:
	if recipe == null:
		return "a processor with no recipe has nothing to make"
	if storage == null:
		return "a processor with no storage has nowhere to take inputs from or put outputs"
	if power_consumer == null:
		return "a processor with no power_consumer runs for free and never reads as unpowered"
	if time_to_process <= 0.0:
		return "time_to_process is %s - a batch would take no time at all" % time_to_process
	return recipe_role_conflict(recipe)

## The resource a recipe names as both an ingredient and a product, as a
## sentence, or "" when it names none.
##
## A slot has ONE role (WI-65), so such a recipe cannot be given a bin: whichever
## of INPUT and OUTPUT `_sync_storages` assigned last would win, and the other
## half of the recipe would quietly stop working. Static and pure so the recipe
## sweep can run it over every shipped recipe, not only the ones a scene is
## authored with.
static func recipe_role_conflict(recipe_to_check: RecipeData) -> String:
	if recipe_to_check == null:
		return ""
	for ingredient: ResourceData in recipe_to_check.inputs:
		if recipe_to_check.outputs.has(ingredient):
			return ("recipe '%s' names %s as both an input and an output, and a slot has one role"
				% [recipe_to_check.name, ingredient.name])
	return ""

func ready_preview() -> void:
	set_process(false)

func ready_blueprint() -> void:
	set_process(false)

func ready_constructed() -> void:
	add_to_group(Groups.PROCESSOR)
	set_process(true)
	# Changing this to always sync storage
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
	if requires_worker:
		_manned_processing(sim_delta)
	else:
		_stepwise_processing(sim_delta)

## Every recipe this processor can run: the ones claiming one of the owning
## module's tags (WI-47 M8), unioned with whatever the scene's legacy
## available_recipes array still holds, plus the authored default so a
## fixed-recipe processor always offers at least its own.
##
## Built lazily and cached rather than in _ready(): module_data isn't necessarily
## assigned by the time a component readies, and this is the only thing here that
## needs it.
func get_available_recipes() -> Array[RecipeData]:
	if not _recipes_resolved:
		_recipes_resolved = true
		_resolved_recipes = _resolve_available_recipes()
	return _resolved_recipes

func _resolve_available_recipes() -> Array[RecipeData]:
	var tags: Array[String] = []
	if owner_module != null and owner_module.module_data != null:
		tags = owner_module.module_data.tags
	var out: Array[RecipeData] = RecipeData.for_tags(tags)
	# Transitional union (WI-47 M8): scenes that still author available_recipes
	# keep working, and the difference is reported once so the arrays can be
	# deleted with evidence rather than hope.
	var only_in_scene: Array[String] = []
	for legacy: RecipeData in available_recipes:
		if legacy != null and not out.has(legacy):
			out.append(legacy)
			only_in_scene.append(legacy.name)
	if not only_in_scene.is_empty():
		push_warning("Processor '%s': recipe(s) %s come only from the scene array, not from any processor_tags"
				% [_module_label(), ", ".join(PackedStringArray(only_in_scene))])
	# The authored default is always runnable, whatever the index says - a
	# processor whose recipe declares no tags must not end up with an empty list.
	if recipe != null and not out.has(recipe):
		out.append(recipe)
	# A recipe whose batch does not fit this bay's intake pool can never run
	# (WI-65 §6), so it must not be offerable - selecting it would leave the
	# module permanently idle with nothing on screen explaining why. Reported
	# rather than dropped quietly: for a mod this is the difference between "my
	# refinery does nothing" and a diagnosable mistake.
	var runnable: Array[RecipeData] = []
	for candidate: RecipeData in out:
		# A recipe that wants one resource on both sides cannot be given slots at
		# all (WI-72 §2). Filtered here rather than asserted in _sync_storages,
		# because a mod's recipe reaching a vanilla processor is content, not a
		# programming error - and an assert would not exist in a release build.
		var conflict: String = recipe_role_conflict(candidate)
		if not conflict.is_empty():
			push_error("Processor '%s' cannot run %s." % [_module_label(), conflict])
			continue
		if storage != null and not recipe_fits(candidate.inputs, storage.max_stored):
			push_error("Processor '%s' cannot run recipe '%s': one batch needs %d intake capacity, the bay holds %d."
					% [_module_label(), candidate.name, _batch_size(candidate.inputs), storage.max_stored])
			continue
		runnable.append(candidate)
	return runnable

func can_select_recipes() -> bool:
	return get_available_recipes().size() > 1

func _module_label() -> String:
	if owner_module != null and owner_module.module_data != null:
		return owner_module.module_data.name
	return name

## Player-facing recipe switch. Mid-batch the switch is queued and applied
## when the current batch completes, so inputs already consumed aren't wasted.
func select_recipe(new_recipe: RecipeData) -> void:
	if new_recipe == null or new_recipe == recipe:
		pending_recipe = null
		return
	# Fail soft rather than assert (WI-47 M8): the eligible set is now assembled
	# from scanned data, so a stale UI entry or a mod's recipe whose tag stopped
	# matching is a content problem, not a programming error, and must not take
	# the game down.
	if not get_available_recipes().has(new_recipe):
		push_warning("Processor '%s' can't run recipe '%s' - not eligible for this module's tags"
				% [_module_label(), new_recipe.name])
		return
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

## How many whole batches' worth of ingredients `pool` holds for `inputs` - the
## unit the input allocation is denominated in (WI-65 §6).
##
## Pure and static so the GUT suite can drive it over every shipped recipe. Zero
## means the bay cannot hold even one batch, which is an authoring error rather
## than a case to clamp: allocating one batch anyway would put the slot caps'
## SUM above the pool, which is precisely the state that lets one ingredient
## starve another - and the module still could not assemble a batch even if it
## filled perfectly. See [method recipe_fits].
static func runs_for(inputs: Dictionary[ResourceData, int], pool: int) -> int:
	var total: int = 0
	for qty: int in inputs.values():
		total += qty
	if total <= 0:
		return 0
	return pool / total

## Can `pool` units of intake capacity hold one batch of `inputs`? The predicate
## behind both the eligibility filter and the content sweep.
static func recipe_fits(inputs: Dictionary[ResourceData, int], pool: int) -> bool:
	return runs_for(inputs, pool) >= 1

## Reconfigures the bin's slots and their roles to match the current recipe.
##
## Ingredients become INPUT and products become OUTPUT, on ONE component - the
## roles are what let a single bin pull ore in while pushing iron out, and they
## are derived here rather than saved so a recipe that changed between builds
## cannot restore slots roled for a recipe that no longer exists.
func _sync_storages() -> void:
	# Belt and braces: the selector already filters a self-referencing recipe out,
	# and an authored one disables the processor at _ready. Reaching here anyway
	# would role half the bin wrong, so stop instead.
	var conflict: String = recipe_role_conflict(recipe)
	if not conflict.is_empty():
		push_error("Processor '%s': %s - leaving its slots alone." % [_module_label(), conflict])
		return
	# Retire slots the new recipe has no use for. An input's leftovers go to the
	# overflow pile (an INPUT slot cannot export); an output's stock is left
	# alone until it has drained, since it is already on its way out.
	for resource: ResourceData in storage.storage_data.keys():
		if recipe.inputs.has(resource) or recipe.outputs.has(resource):
			continue
		var data: StorageData = storage.storage_data[resource]
		if data.role == StorageData.Role.OUTPUT:
			if data.stored <= 0 and data.reserved_deposit <= 0:
				storage.remove_stored_resource(resource)
		else:
			_clear_input_slot(resource)
	# Whole runs, not a rounded ratio (WI-65 §6): every ingredient gets the SAME
	# integral number of batches' worth, so the caps sum to runs * total, which
	# is <= the pool by construction. Rounding each share up independently could
	# sum ABOVE the pool - two shipped recipes already did - and once `desired` is
	# a cap that overshoot is what lets one ingredient starve another.
	var runs: int = runs_for(recipe.inputs, storage.max_stored)
	if runs < 1:
		# Should be unreachable: get_available_recipes() filters these out. Loud
		# rather than silent, because the symptom is "my refinery does nothing".
		push_error("Recipe %s needs %d intake capacity but %s has %d - it can never run."
			% [recipe.name, _batch_size(recipe.inputs), owner_module.name if owner_module != null else name,
				storage.max_stored])
		runs = 1
	for ingredient: ResourceData in recipe.inputs:
		storage.add_stored_resource(ingredient, StorageData.Role.INPUT)
		# Role and desired are BOTH set explicitly, because add_stored_resource
		# leaves an existing slot alone: a slot can survive a recipe switch
		# holding stock, and a resource can change sides entirely (an ingredient
		# of the old recipe becoming a product of the new one). This function is
		# the authority on what a processor bin's slots are for.
		storage.storage_data[ingredient].role = StorageData.Role.INPUT
		storage.storage_data[ingredient].desired = runs * recipe.inputs[ingredient]
		# The cap just moved. A slot that survived the recipe switch holding more
		# than the new allocation is over it, and an INPUT slot cannot export its
		# way back down - so shed to the overflow pile (WI-65 §12).
		_shed_input_slot(ingredient, storage.storage_data[ingredient].desired)
	for output: ResourceData in recipe.outputs:
		storage.add_stored_resource(output, StorageData.Role.OUTPUT)
		storage.storage_data[output].role = StorageData.Role.OUTPUT
		# Outputs ship everything they hold (StorageData.exportable_surplus), so
		# desired is a capacity bound rather than a level to sit at. The whole
		# output pool: the products share it, deliberately, because a run
		# deposits atomically and per-product caps would let a run proceed with
		# only some of its outputs placed.
		storage.storage_data[output].desired = storage.output_capacity

static func _batch_size(inputs: Dictionary[ResourceData, int]) -> int:
	var total: int = 0
	for qty: int in inputs.values():
		total += qty
	return total

## Retires an input slot the current recipe no longer uses.
func _clear_input_slot(resource: ResourceData) -> void:
	_shed_input_slot(resource, 0)
	storage.remove_stored_resource(resource)

## Drains an INPUT slot down to `keep` units, into the module's overflow pile.
##
## Stock must not be destroyed (jobs invariant), and an INPUT slot does not post
## exports - so the pile is the route, and deliberately not a haul job. An export
## from an INPUT slot would post at the component's priority (a forge input sits
## at +1) and [StorageQuery.find_sink] demands a STRICTLY greater sink, so every
## ordinary storeroom at 0 would refuse it and the goods would have nowhere to go
## but a construction site. Pile collection passes ANY_PRIORITY and accepts any
## bin with room.
##
## Two callers, and the second is why this is not just the retire path: since
## WI-65 §11 an INPUT slot's `desired` is a hard cap, and the cap MOVES when the
## recipe changes. A resource the new recipe still uses but in a smaller ratio is
## suddenly over its cap, and left alone it would be stranded - which is the very
## deadlock the cap exists to prevent, relocated one step.
func _shed_input_slot(resource: ResourceData, keep: int) -> void:
	var data: StorageData = storage.storage_data.get(resource)
	if data == null:
		return
	# Cancel incoming hauls first: the pawns keep their cargo and
	# the cargo sweep re-homes it, and cancellation reconciles the slot's
	# reservations to zero so the drain below sees the true stored count.
	data.end_all_jobs()
	var excess: int = data.stored - keep
	if excess <= 0 or storage.owner_module == null:
		return
	var leftovers: Array[ResourceStack] = storage.withdraw_stacks(resource, excess, true)
	if not leftovers.is_empty():
		storage.owner_module.get_or_create_overflow_pile().add_stacks(resource, leftovers)

func _satisfies_recipe() -> bool:
	for ingredient in recipe.inputs:
		var amount := recipe.inputs[ingredient]
		if !storage.can_withdraw(ingredient, amount):
			last_error = "Missing input!"
			return false
	for output in recipe.outputs:
		var amount := recipe.outputs[output]
		if !storage.can_deposit(output, amount):
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
		var stacks: Array[ResourceStack] = storage.withdraw_stacks(ingredient, amount)
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

## Quality (0..1) to stamp on this recipe's food outputs (WI-29): the recipe's
## base plus the operating worker's skill-scaled shift. Unmanned or between
## shifts (current_worker null) -> just the base. A future inherit_input_quality
## flag could fold current_batch_richness in here for process-food recipes.
func _compute_output_quality() -> float:
	var shift: float = 0.0
	if current_worker != null and is_instance_valid(current_worker):
		var skills: PawnSkillsComponent = current_worker.get_skills_component()
		if skills != null:
			var t: float = clampf(float(skills.get_level(worker_skill)) / float(SkillData.MAX_LEVEL), 0.0, 1.0)
			shift = worker_quality_shift_at_max * t
	return clampf(recipe.output_quality_base + shift, 0.0, 1.0)

## Deposits `whole` units of `output`, attaching FoodInstanceData when the recipe
## is a food recipe (output_quality_base >= 0) and the resource carries variance -
## so quality flows through storage/hauling/save exactly like ore richness.
## Non-food outputs take the plain path unchanged. Room is pre-checked by the
## caller, so this never fails on space (asserts if it somehow does).
func _deposit_output(output: ResourceData, whole: int) -> bool:
	if recipe.output_quality_base >= 0.0 and output.has_variance:
		var stack := ResourceStack.new()
		stack.resource_data = output
		stack.amount = whole
		var food := FoodInstanceData.new()
		food.quality = _compute_output_quality()
		stack.instance_data = food
		var batch: Array[ResourceStack] = [stack]
		return storage.deposit_stacks(output, batch, false)
	return storage.deposit(output, whole)

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
		if whole > 0 and not storage.can_deposit(output, whole):
			last_error = "No space for output!"
			return false
		whole_amounts[output] = whole
		total_out += whole
	# can_deposit checks each output alone; two outputs can each fit but not
	# together, so check the combined room too before committing anything.
	if total_out > storage.space_available(false, StorageData.Role.OUTPUT):
		last_error = "No space for output!"
		return false
	for output in recipe.outputs:
		var with_residue: float = _scaled_output(recipe.outputs[output]) + _yield_residue.get(output, 0.0)
		var whole: int = whole_amounts[output]
		_yield_residue[output] = with_residue - whole
		if whole > 0:
			var doublecheck: bool = _deposit_output(output, whole)
			assert(doublecheck, "Somehow couldn't output items when there was room!")
	return true

func _stepwise_processing(delta: float) -> void:
	if processing:
		var effective_time: float = get_process_time()
		current_process_time += delta
		_accumulate_work(delta, effective_time)
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

# --- manned processing (WI-23) ----------------------------------------------

## Powered per-frame step for requires_worker processors. Readies a batch when
## inputs are available (withdrawing them, then holding at partial progress) and
## keeps a work job posted, but never advances progress itself - that's
## advance_work(), called by the operating pawn. _worked_this_frame tells a live
## worker from a stall so the alert reads "Waiting for worker" (not "No power!").
func _manned_processing(_delta: float) -> void:
	var worked: bool = _worked_this_frame
	_worked_this_frame = false
	if not processing:
		if _satisfies_recipe():
			_withdraw_inputs()
			processor_progress_changed.emit(0)
			processing = true
			current_process_time = 0
		# else: last_error was set by _satisfies_recipe (Missing input / no space).
	if processing:
		_ensure_work_job()
		if not worked:
			last_error = "Waiting for worker"

## Bank progress as a fraction of a batch (WI-60). Called from both processing
## paths, so a manned forge and an unmanned refinery bill heat identically.
func _accumulate_work(advanced: float, effective_time: float) -> void:
	if effective_time > 0.0:
		_work_accumulated += advanced / effective_time

## Work done since the last call, in batch fractions, and reset. Drained rather
## than read so the same progress can never be billed twice - HeatEmitterComponent
## is the only caller.
func take_work_fraction() -> float:
	var done: float = _work_accumulated
	_work_accumulated = 0.0
	return done

## True when a fresh batch could be readied right now (inputs present, output
## room). Used by the work driver's batch loop to decide whether to keep going.
func can_ready_batch() -> bool:
	return not processing and _satisfies_recipe()

## True while a batch is ready or mid-progress and thus needs an operator.
func has_active_batch() -> bool:
	return processing

## Ensures exactly one work job is outstanding for this module. No-op while one
## is still live (on the board, being walked to, or working); posts a fresh board
## job otherwise.
func _ensure_work_job() -> void:
	if _work_slot.is_live():
		return
	if owner_module == null or not owner_module.is_complete():
		return
	var job: Job = Job.of(&"work_processor").with_target_a(JobTarget.of_component(self))
	# The gate itself is re-read off the module by the driver; this copy is what
	# gives an assignee the priority bonus on the board (WI-23).
	job.workspace = owner_module.get_component_by_type(WorkspaceComponent) as WorkspaceComponent
	_work_slot.post(job)
	Global.job_manager.add_job(job)

## The operator's job, restored from a save (WI-70 §3). Without this the slot was
## empty after a load, a second work job went up beside the restored one, and a
## second crew member walked to the machine to fail on its one operator slot (F26).
func adopt_restored_job(job: Job) -> bool:
	return job.is_type(&"work_processor") and _work_slot.adopt(job)

## WI-44 operator slot: exactly one pawn works a machine at a time. A SlotPool of
## capacity 1 rather than a bespoke flag, so Action_ClaimSlot works unchanged and
## the claim is released by the runner on every exit path like any other.
var _operator_slot: SlotPool = null

func claim_pool() -> SlotPool:
	if _operator_slot == null:
		_operator_slot = SlotPool.new()
	_operator_slot.capacity = 1
	return _operator_slot


## Advances the current batch by `amount` sim-seconds (already folded with the
## worker's happiness x skill rate). Returns true when the batch completes this
## call. Deposits outputs and applies any pending recipe on completion, exactly
## like the unmanned path; holds at full progress if the output has no room.
func advance_work(amount: float) -> bool:
	# The worker drives this directly from its job, bypassing the _process power
	# gate - so re-check power here, or an unpowered manned processor would keep
	# producing for free while someone stands at it. The job should already have
	# been canceled by now, though - we don't want someone stuck here
	if power_consumer != null and not power_consumer.powered:
		return false
	if not processing:
		# No batch readied yet this frame (the processor's own _process readies it),
		# or one just completed - nothing to advance. "Not complete", so the worker
		# stays put and tries again next frame instead of falsely finishing.
		_worked_this_frame = true
		return false
	_worked_this_frame = true
	last_error = ""
	var effective_time: float = get_process_time()
	current_process_time += amount
	_accumulate_work(amount, effective_time)
	processor_progress_changed.emit(current_process_time / effective_time)
	if current_process_time < effective_time:
		return false
	if not _try_deposit_outputs():
		# Batch is done but the output is full - hold at completion (progress
		# capped) until room frees up; the worker keeps "working" meanwhile.
		current_process_time = effective_time
		return false
	processor_progress_changed.emit(0)
	processing = false
	current_process_time = 0
	current_batch_richness = -1.0
	batch_richness_changed.emit(current_batch_richness)
	if pending_recipe != null:
		_apply_recipe(pending_recipe)
	return true

# --- persistence ------------------------------------------------------------
# The selected recipe is saved because input/output storage configuration
# depends on it. For UNMANNED processors mid-batch progress and residue are
# still deliberately dropped (pre-existing behavior). For MANNED processors a
# mid-batch state IS saved (WI-23): a pawn invested time and the inputs are
# already withdrawn, so losing it would strand the withdrawn stock and let the
# reload re-withdraw a second batch (double-withdrawal). Restoring processing +
# progress + richness resumes the exact same batch, and _manned_processing sees
# processing == true so it won't withdraw again.

## Before storage: restoring the selected recipe reconfigures the input/output
## slots, and the storage block then restores contents on top of that layout.
func save_order() -> int:
	return 20

func save_key() -> StringName:
	return &"processor"

func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	if can_select_recipes() and recipe != null:
		data["recipe"] = recipe.resource_path
		# A switch queued mid-batch is a player choice that hasn't taken effect
		# yet; without this it's silently dropped and the machine keeps running
		# the old recipe forever (WI-45 A2).
		if pending_recipe != null:
			data["pending_recipe"] = pending_recipe.resource_path
	# Both paths withdraw the batch's inputs up front, so both have to save the
	# batch or those inputs are destroyed by a save/load. WI-23 added this for
	# the manned path only; the unmanned one (most processors) went unnoticed
	# until the WI-45 sweep.
	if processing:
		data["processing"] = true
		data["process_time"] = current_process_time
		data["batch_richness"] = current_batch_richness
	# Fractional yield carried toward the next batch. Sub-1-unit per output, but
	# it IS output the player's inputs already paid for, and nothing they did
	# discarded it - so it survives a save. (A recipe switch still drops the
	# entries the new recipe can't use; that one is an explicit player action.)
	var residue: Dictionary = {}
	for output: ResourceData in _yield_residue:
		if output.id != &"" and _yield_residue[output] > 0.0:
			residue[String(output.id)] = _yield_residue[output]
	if not residue.is_empty():
		data["yield_residue"] = residue
	return data

func load_save_data(data: Dictionary) -> void:
	# Residue before the recipe: when the restored recipe differs from what the
	# scene authored, _apply_recipe prunes the entries it can't use - the same
	# drop a live switch does, which is the one loss that IS intended.
	_load_yield_residue(data.get("yield_residue", {}))
	if can_select_recipes():
		_load_recipe(String(data.get("recipe", "")), false)
	# Mid-batch resume. Set after the recipe so the batch's inputs were already
	# withdrawn against the right recipe before the save.
	if bool(data.get("processing", false)):
		processing = true
		current_process_time = float(data.get("process_time", 0.0))
		current_batch_richness = float(data.get("batch_richness", -1.0))
		batch_richness_changed.emit(current_batch_richness)
		processor_progress_changed.emit(current_process_time / get_process_time())
	# After `processing` is restored: select_recipe() re-queues rather than
	# applies while a batch is live, which is exactly what a saved pending
	# switch means. A batch that is no longer running applies it outright.
	if can_select_recipes():
		_load_recipe(String(data.get("pending_recipe", "")), true)

## Restores the fractional carry-over, resolving output ids the same way storage
## and conveyors do. An id that no longer exists is dropped with a warning - the
## resource it accrued toward is gone, so there is nothing to carry it to.
func _load_yield_residue(data: Dictionary) -> void:
	if data.is_empty():
		return
	_yield_residue.clear()
	for id_str: String in data:
		var output: ResourceData = Global.save_manager.get_resource_by_id(StringName(id_str))
		if output == null:
			push_warning("Unknown resource id in saved yield residue, skipping: " + id_str)
			continue
		_yield_residue[output] = float(data[id_str])

## Shared recipe restore. Warns and keeps whatever is in place when the saved
## path no longer resolves or is no longer eligible for this module (a renamed or
## removed .tres, or a recipe whose mod is uninstalled), rather than clearing the
## machine's recipe out from under it.
func _load_recipe(path: String, queued: bool) -> void:
	if path == "":
		return
	# load() returns the cached instance, so equality against the resolved
	# eligible set holds.
	var loaded: RecipeData = load(path) as RecipeData
	if loaded == null or not get_available_recipes().has(loaded):
		push_warning("Saved processor %s not available, ignoring: %s" % ["pending recipe" if queued else "recipe", path])
		return
	select_recipe(loaded)

func has_ui() -> bool:
	return true

func get_ui() -> ModuleComponentUI:
	var ui: ProcessorComponentUI = ui_info_panel_element.instantiate() as ProcessorComponentUI
	ui.set_processor_component(self)
	return ui
