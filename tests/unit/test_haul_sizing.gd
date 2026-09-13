extends GutTest

## A haul is sized to the room its sink really has (2026-09-12).
##
## The bug: on the player's quicksave, the start module's catch-all bin (80) went
## from 55 to 87 while crew hauled ore out of a mining bay. find_sink() needs only
## ONE unit of room to pick a bin, a GENERAL deposit claim is bookkeeping (its bound
## is the component's pool, which StorageData cannot see), and the deposit half
## reserved whatever the withdraw half had settled on - a whole trip. So two
## sixteen-unit trips landed in twenty-five units of room.
##
## The reserve actions are the real ones, pulled out of the real drivers'
## make_actions() and run against real StorageComponents with the claim registry
## injected - both halves of the bookkeeping, no pawn, no world. TAKE and DEPOSIT
## need a pawn's inventory, so _deliver() stands in for them with the same storage
## calls and the same claim spending.

const WITHDRAW: ClaimSpec.Kind = ClaimSpec.Kind.STORAGE_WITHDRAW
const DEPOSIT: ClaimSpec.Kind = ClaimSpec.Kind.STORAGE_DEPOSIT
const DONE: ActionBase.Status = ActionBase.Status.DONE
const FAILED: ActionBase.Status = ActionBase.Status.FAILED

var registry: ClaimRegistry = null
var ore: ResourceData = null
var ice: ResourceData = null

func before_each() -> void:
	registry = ClaimRegistry.new()
	ore = _resource(&"iron_ore")
	ice = _resource(&"ice")

func after_each() -> void:
	registry.free()
	registry = null

# --- fixtures -------------------------------------------------------------------

func _resource(id: StringName) -> ResourceData:
	var resource := ResourceData.new()
	resource.id = id
	resource.name = String(id)
	return resource

## The start module's shape: a catch-all storeroom already holding `stock` of
## something other than ore.
func _storeroom(capacity: int, stock: int) -> StorageComponent:
	var bin: StorageComponent = autofree(StorageComponent.new())
	bin.include_in_stats = false
	bin.priority = 0
	bin.max_stored = capacity
	bin.allow_any_resource = true
	bin.default_role = StorageData.Role.GENERAL
	if stock > 0:
		bin.deposit(ice, stock)
	return bin

## A mining bay: no intake pool, its whole capacity an OUTPUT pool of ore.
func _mining_bay(stock: int) -> StorageComponent:
	var bay: StorageComponent = autofree(StorageComponent.new())
	bay.include_in_stats = false
	bay.priority = 1
	bay.max_stored = 0
	bay.output_capacity = 80
	bay.default_role = StorageData.Role.OUTPUT
	bay.add_stored_resource(ore, StorageData.Role.OUTPUT)
	bay.deposit(ore, stock)
	return bay

## A push of ore from `source` to `sink`. With no pawn, trip_cap() leaves the
## count alone, so `trip` stands in for what a pawn could carry.
func _haul(source: StorageComponent, sink: StorageComponent, trip: int) -> Job:
	var job := Job.create(JobData.new())
	job.registry = registry
	job.target_a = JobTarget.of_component(source)
	job.target_b = JobTarget.of_component(sink)
	job.resource = ore
	job.count = trip
	return job

## RESERVE_SOURCE then RESERVE_SINK, exactly as JobDriver_Haul builds them.
func _reserve(job: Job) -> ActionBase.Status:
	var actions: Array[ActionBase] = JobDriver_Haul.new().make_actions(job)
	var status: ActionBase.Status = actions[JobDriver_Haul.RESERVE_SOURCE].on_start(job)
	if status != DONE:
		return status
	return actions[JobDriver_Haul.RESERVE_SINK].on_start(job)

## TAKE then DEPOSIT without a pawn: the same storage calls, the same claims spent.
func _deliver(job: Job) -> void:
	var source: StorageComponent = job.target_a.component() as StorageComponent
	var sink: StorageComponent = job.target_b.component() as StorageComponent
	var source_bin: StorageData = source.claim_target_for(ore)
	var stacks: Array[ResourceStack] = source.withdraw_reserved(ore, job.count)
	job.consume_claim(source_bin, WITHDRAW)
	var sink_bin: StorageData = sink.claim_target_for(ore)
	sink.deposit_reserved(ore, stacks, _held(job, sink, DEPOSIT))
	job.consume_claim(sink_bin, DEPOSIT)

## What `job` has booked on `storage`'s ore slot, of `kind`.
func _held(job: Job, storage: StorageComponent, kind: ClaimSpec.Kind) -> int:
	var bin: StorageData = storage.claim_target_for(ore)
	if bin == null:
		return 0
	var spec: ClaimSpec = job.find_claim(bin, kind)
	return spec.amount if spec != null else 0

# --- the observed over-fill ------------------------------------------------------

## The quicksave, replayed: 55/80, a hauler bringing sixteen at a time.
func test_serial_trips_fill_the_bin_to_capacity_and_no_further() -> void:
	var bay: StorageComponent = _mining_bay(80)
	var room: StorageComponent = _storeroom(80, 55)
	var first: Job = _haul(bay, room, 16)
	assert_eq(_reserve(first), DONE)
	assert_eq(first.count, 16, "sixteen fit in twenty-five")
	_deliver(first)
	var second: Job = _haul(bay, room, 16)
	assert_eq(_reserve(second), DONE, "nine units of room is still worth a trip")
	assert_eq(second.count, 9, "but the trip is cut to it - the extra seven are where 87 came from")
	_deliver(second)
	assert_eq(room.space_available(), 0, "exactly full, not over")
	var third: Job = _haul(bay, room, 16)
	assert_eq(_reserve(third), FAILED, "a full bin takes no reservation at all")
	registry.release_all(third)
	assert_eq(room.total_stored_by_resource(ore), 25)
	assert_eq(bay.total_stored_by_resource(ore), 55, "the rest of the ore stayed in the bay")
	assert_eq(bay.storage_data[ore].reserved_withdraw, 0, "with nothing left booked against it")

## Several hauls booked before any delivers: the room is shared out between them,
## not promised to each of them in full.
func test_concurrent_hauls_share_the_room_instead_of_each_booking_all_of_it() -> void:
	var bay: StorageComponent = _mining_bay(80)
	var room: StorageComponent = _storeroom(80, 55)
	var a: Job = _haul(bay, room, 16)
	var b: Job = _haul(bay, room, 16)
	var c: Job = _haul(bay, room, 16)
	assert_eq(_reserve(a), DONE)
	assert_eq(_reserve(b), DONE)
	assert_eq(_reserve(c), FAILED, "nothing is left for a third")
	registry.release_all(c)
	assert_eq(a.count + b.count, 25, "sixteen and nine")
	assert_eq(room.storage_data[ore].reserved_deposit, 25, "the storeroom promised its room once")
	assert_eq(room.room_for(ore, true), 0)
	assert_eq(bay.storage_data[ore].reserved_withdraw, 25,
		"and the bay has twenty-five booked out, not forty-eight")

# --- both halves agree ----------------------------------------------------------------

## The withdraw is booked before the sink is even known, so when the sink cuts the
## trip short, that booking has to come down with it - TAKE consumes the whole
## record, and anything left over would stay reserved in the bay forever.
func test_the_withdraw_already_booked_shrinks_with_the_trip() -> void:
	var bay: StorageComponent = _mining_bay(80)
	var room: StorageComponent = _storeroom(80, 68)
	var job: Job = _haul(bay, room, 30)
	assert_eq(_reserve(job), DONE)
	assert_eq(job.count, 12, "twelve units of room, twelve-unit trip")
	assert_eq(_held(job, bay, WITHDRAW), 12, "the withdraw record matches the trip")
	assert_eq(bay.storage_data[ore].reserved_withdraw, 12,
		"and so does the bay's own count - the other eighteen are free for the next trip")
	assert_eq(_held(job, room, DEPOSIT), 12, "the two halves agree")

func test_a_shortened_job_reconciles_both_ends_to_zero_when_it_ends() -> void:
	var bay: StorageComponent = _mining_bay(80)
	var room: StorageComponent = _storeroom(80, 68)
	var job: Job = _haul(bay, room, 30)
	_reserve(job)
	registry.release_all(job)
	assert_eq(bay.storage_data[ore].reserved_withdraw, 0, "the bay's booking all came back")
	assert_eq(room.storage_data[ore].reserved_deposit, 0, "and so did the storeroom's")

func test_a_trip_that_fits_is_left_alone() -> void:
	var bay: StorageComponent = _mining_bay(80)
	var room: StorageComponent = _storeroom(200, 0)
	var job: Job = _haul(bay, room, 30)
	assert_eq(_reserve(job), DONE)
	assert_eq(job.count, 30)
	assert_eq(_held(job, bay, WITHDRAW), 30)
	assert_eq(_held(job, room, DEPOSIT), 30)

# --- refusing before promising ------------------------------------------------------------

func test_a_bin_with_no_room_refuses_without_growing_a_slot() -> void:
	var bay: StorageComponent = _mining_bay(80)
	var room: StorageComponent = _storeroom(80, 80)
	var job: Job = _haul(bay, room, 16)
	assert_eq(_reserve(job), FAILED)
	assert_false(room.storage_data.has(ore), "no empty ore slot left behind in a full storeroom")
	registry.release_all(job)

## The last units, already promised to a haul on its way, count as taken.
func test_room_another_haul_has_promised_is_not_room() -> void:
	var bay: StorageComponent = _mining_bay(80)
	var room: StorageComponent = _storeroom(80, 55)
	var first: Job = _haul(bay, room, 25)
	assert_eq(_reserve(first), DONE)
	var second: Job = _haul(bay, room, 16)
	assert_eq(_reserve(second), FAILED, "the storeroom's room is all spoken for")
	registry.release_all(second)

## A deposit into an over-filled bin is refused outright - a restored save can
## arrive this way, and adding the trip's own count back must not invent room.
func test_an_over_filled_bin_takes_no_trip() -> void:
	var bay: StorageComponent = _mining_bay(80)
	var room: StorageComponent = _storeroom(80, 87)
	var job: Job = _haul(bay, room, 16)
	assert_eq(_reserve(job), FAILED)
	registry.release_all(job)

func test_an_input_slot_caps_the_trip_at_its_share() -> void:
	var bay: StorageComponent = _mining_bay(80)
	var forge: StorageComponent = autofree(StorageComponent.new())
	forge.include_in_stats = false
	forge.priority = 1
	forge.max_stored = 100
	forge.add_stored_resource(ore, StorageData.Role.INPUT)
	forge.storage_data[ore].desired = 10
	forge.deposit(ore, 4)
	var job: Job = _haul(bay, forge, 16)
	assert_eq(_reserve(job), DONE)
	assert_eq(job.count, 6, "the recipe's remaining share, not the pool's hundred")

# --- a pile collection --------------------------------------------------------------------

## A collection books the pile before the sink as well. If the sink cuts the trip,
## the pile's units have to be given back - TakeFromPile settles against job.count
## and would strand the rest as reserved.
func test_a_pile_reservation_shrinks_with_the_trip() -> void:
	var pile: ResourcePile = autofree(ResourcePile.new())
	# Filled directly: add_stacks() would post a collection job to a board that
	# does not exist here.
	var heap := ResourceStackContainer.new()
	heap.resource_data = ore
	heap.add_amount(30)
	pile.contents[ore] = heap
	var room: StorageComponent = _storeroom(80, 75)
	var job := Job.create(JobData.new())
	job.registry = registry
	job.target_a = JobTarget.of_pile(pile)
	job.target_b = JobTarget.of_component(room)
	job.resource = ore
	job.count = 20
	assert_not_null(job.claim(pile.claim_target_for(ore), ClaimSpec.Kind.PILE, 20),
		"fixture: the pile half is already booked, as RESERVE_PILE leaves it")
	var actions: Array[ActionBase] = JobDriver_CollectPile.new().make_actions(job)
	assert_eq(actions[JobDriver_CollectPile.RESERVE_SINK].on_start(job), DONE)
	assert_eq(job.count, 5, "five units of room, five-unit trip")
	assert_eq(int(pile.reserved.get(ore, 0)), 5, "the pile has five booked, not twenty")
	assert_eq(pile.get_available(ore), 25, "the other twenty-five are free for the next trip")
	registry.release_all(job)
	assert_eq(int(pile.reserved.get(ore, 0)), 0, "and it all comes back when the job ends")
