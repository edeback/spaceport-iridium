class_name VisitorManager
extends Node

## Owns the visitor economy (WI-33): station reputation, arrival pacing, and the
## gates that decide when a guest may arrive. Registers as Global.visitor_manager;
## sits late in main.tscn's Managers node (it reads crew/raid/unlock/trader state).
##
## Reputation (0..1) drifts up on happy departures and down on unhappy ones, and
## feeds the expected arrival rate together with amenity capacity and the station
## tier. A pacing FLOOR guarantees a trickle of brave guests whenever capacity
## exists, so a bad-reputation station can still recover (no death spiral).
##
## Guests arrive by passenger shuttle at the docking bay (the crew/trader arrival
## pattern) and are excluded from the crew roster (is_visitor). They spawn only
## when: the station is at/above the visitor tier, a free hotel bunk exists, at
## least one shop is open, a bay exists, and no raid is underway.

@export var visitor_pawn_scene: PackedScene
## Reused ArrivalShuttle - the same passenger craft crew and traders ride in on.
@export var shuttle_scene: PackedScene
## How far off the bay the shuttle spawns/exits, in px (matches CrewManager).
@export var shuttle_approach_distance: float = 1200.0

# --- reputation ---------------------------------------------------------------
## 0..1 station standing. Starts middling so a fresh commerce station sees some
## traffic immediately once it qualifies.
@export var reputation: float = 0.5
@export var reputation_gain_happy: float = 0.04
@export var reputation_loss_unhappy: float = 0.06

# --- arrival pacing tunables --------------------------------------------------
## Minimum station tier (WI-26) before any guest arrives. Matches the shop/hotel
## unlock tier so guests appear once there's somewhere for them to spend/sleep.
@export var min_tier: int = 2
## Brave-trickle arrivals per cycle whenever capacity exists, independent of
## reputation - the anti-death-spiral floor.
@export var floor_arrivals_per_cycle: float = 0.6
## Extra arrivals per cycle at full reputation (added on top of the floor, then
## capped by lodging capacity).
@export var reputation_arrivals_per_cycle: float = 3.0
## Never let a stalled accumulator (raid, no bay) dump a flood once it clears.
@export var max_accumulator: float = 2.0

# --- guest rolls --------------------------------------------------------------
## Starting wallet is rolled uniformly in this band.
@export var wallet_band: Vector2i = Vector2i(70, 220)
## Visit length (game-hours) rolled uniformly in this band.
@export var stay_hours_band: Vector2 = Vector2(16.0, 36.0)

# --- disease (WI-31 hook) -----------------------------------------------------
## Chance an arriving guest carries a visitor-acquirable disease.
@export var arrival_infection_chance: float = 0.05

## Fractional arrivals banked toward the next spawn (the smooth trickle).
var _accumulator: float = 0.0
## Live guest count, for the UI/economy summary (kept in sync via signals).
var _visitor_count: int = 0

const SECONDS_PER_CYCLE: float = TimeManager.SECONDS_PER_HOUR * float(TimeManager.HOURS_PER_CYCLE)

func _ready() -> void:
	Global.visitor_manager = self
	# Reputation + arrival pacing only; the guest pawns themselves ride in the
	# pawns section. Independent of every other section's order.
	SaveManager.register_section(&"visitors", 160, get_save_data, load_save_data)
	Global.time_manager.slow_tick.connect(_on_slow_tick)

# --- pure pacing math (WI-19 testable, no Global) -----------------------------

## Expected guest arrivals per cycle. 0 unless the visitor tier is met AND there's
## both lodging (a hard cap - guests must be able to sleep) and at least one shop
## (somewhere to spend). Otherwise: a reputation-independent floor plus a
## reputation-scaled bonus, capped at the number of hotel bunks (can't host more
## guests than beds).
static func expected_arrivals_per_cycle(reputation_: float, hotel_capacity: int, shop_count: int, min_tier_met: bool, floor_rate: float, reputation_rate: float) -> float:
	if not min_tier_met or hotel_capacity <= 0 or shop_count <= 0:
		return 0.0
	var rep01: float = clampf(reputation_, 0.0, 1.0)
	var demand: float = floor_rate + reputation_rate * rep01
	return minf(demand, float(hotel_capacity))

## Reputation after a departure of the given mood. Pure so the drift is testable.
static func reputation_after_departure(reputation_: float, happy: bool, gain: float, loss: float) -> float:
	var delta: float = gain if happy else -loss
	return clampf(reputation_ + delta, 0.0, 1.0)

# --- pacing loop --------------------------------------------------------------

func _on_slow_tick(interval: float) -> void:
	if SaveManager.is_loading():
		return
	var expected: float = _expected_arrivals()
	if expected <= 0.0:
		# No demand right now: bleed the accumulator so demand can't bank forever.
		_accumulator = maxf(0.0, _accumulator - interval / SECONDS_PER_CYCLE)
		return
	_accumulator = minf(_accumulator + expected * interval / SECONDS_PER_CYCLE, max_accumulator)
	if _accumulator < 1.0:
		return
	# One arrival at a time; the spawn gate re-checks the runtime conditions.
	if _spawn_gate_open():
		_accumulator -= 1.0
		_spawn_visitor()

func _expected_arrivals() -> float:
	var tier: int = Global.unlock_manager.current_tier if Global.unlock_manager != null else 1
	return expected_arrivals_per_cycle(
		reputation,
		_hotel_capacity(),
		_open_shop_count(),
		tier >= min_tier,
		floor_arrivals_per_cycle,
		reputation_arrivals_per_cycle)

## Runtime spawn conditions checked at the moment of arrival (the accumulator only
## tracks demand). A free bunk must exist, a bay to dock at, and no active raid.
func _spawn_gate_open() -> bool:
	if visitor_pawn_scene == null:
		return false
	if Global.raid_manager != null and Global.raid_manager.active:
		return false
	if _find_arrival_bay() == null:
		return false
	if Global.crew_manager == null or Global.crew_manager.free_visitor_bunks() <= 0:
		return false
	return true

# --- capacity queries ---------------------------------------------------------

func _hotel_capacity() -> int:
	return Global.crew_manager.visitor_sleep_capacity() if Global.crew_manager != null else 0

## Count of built, open shops (somewhere to spend). Reads the "shop" group.
func _open_shop_count() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(Groups.SHOP):
		var shop: ShopComponent = node as ShopComponent
		if shop != null and shop.is_open():
			count += 1
	return count

## Nearest built docking bay to dock the passenger shuttle at (the crew gateway).
func _find_arrival_bay() -> ModuleBase:
	for node: Node in get_tree().get_nodes_in_group(Groups.CREW_RECRUITMENT):
		var bay: CrewRecruitmentComponent = node as CrewRecruitmentComponent
		if bay != null and bay.owner_module != null and bay.owner_module.is_complete():
			return bay.owner_module
	return null

# --- arrival ------------------------------------------------------------------

func _spawn_visitor() -> void:
	var bay: ModuleBase = _find_arrival_bay()
	if bay == null:
		return
	if shuttle_scene == null:
		_deliver_visitor(bay)
		return
	var shuttle: ArrivalShuttle = shuttle_scene.instantiate() as ArrivalShuttle
	Global.world_manager.pawn_layer.add_child(shuttle)
	var dock: Vector2 = DockingBay.dock_position_for(bay)
	shuttle.setup(dock, dock + Vector2(DockingBay.approach_sign_for(bay) * shuttle_approach_distance, 0.0))
	shuttle.docked.connect(_on_shuttle_docked.bind(shuttle, bay), CONNECT_ONE_SHOT)

func _on_shuttle_docked(shuttle: ArrivalShuttle, bay: ModuleBase) -> void:
	if is_instance_valid(bay):
		_deliver_visitor(bay)
	await Global.time_manager.sim_seconds(TimeManager.SECONDS_PER_HOUR)
	if is_instance_valid(shuttle):
		shuttle.depart()

## Instantiates a guest inside the bay with a rolled wallet + stay timer. Public
## so the spawn cheat and (later) the save-loader can reuse the setup.
func spawn_visitor_at(bay: ModuleBase, wallet: int = -1, stay_hours: float = -1.0) -> VisitorPawn:
	if bay == null or visitor_pawn_scene == null:
		return null
	return _deliver_visitor(bay, wallet, stay_hours)

func _deliver_visitor(bay: ModuleBase, wallet: int = -1, stay_hours: float = -1.0) -> VisitorPawn:
	# Which KIND of guest (WI-47 M10). An empty data/pawns/ falls through to the
	# authored fallback scene, so the base game works either way.
	var kind: PawnData = PawnData.roll_for_role(PawnData.Role.VISITOR)
	var scene: PackedScene = kind.scene if kind != null and kind.scene != null else visitor_pawn_scene
	if scene == null:
		return null
	var visitor: VisitorPawn = scene.instantiate() as VisitorPawn
	if visitor == null:
		push_warning("Visitor scene for '%s' is not a VisitorPawn" % (kind.id if kind != null else &"<fallback>"))
		return null
	Global.world_manager.pawn_layer.add_child(visitor)
	visitor.current_module = bay
	visitor.global_position = Global.cell_to_world(bay.module_cell, true)
	visitor.pawn_name = NameGenerator.random_name()
	visitor.setup(
		wallet if wallet >= 0 else _roll_wallet(),
		stay_hours if stay_hours >= 0.0 else _roll_stay_hours())
	_maybe_infect_arrival(visitor)
	_visitor_count += 1
	SignalBus.visitor_arrived.emit(visitor)
	SignalBus.visitors_changed.emit()
	return visitor

func _roll_wallet() -> int:
	return randi_range(wallet_band.x, maxi(wallet_band.x, wallet_band.y))

func _roll_stay_hours() -> float:
	return randf_range(stay_hours_band.x, maxf(stay_hours_band.x, stay_hours_band.y))

## Arrival infection roll (WI-31 hook): a small chance the guest brings a
## visitor-acquirable disease unlocked at the current tier.
func _maybe_infect_arrival(visitor: VisitorPawn) -> void:
	if arrival_infection_chance <= 0.0 or randf() >= arrival_infection_chance:
		return
	var pool: Array[DiseaseData] = _visitor_disease_pool()
	if pool.is_empty():
		return
	var disease: DiseaseData = pool.pick_random()
	var comp: PawnDiseaseComponent = visitor.get_component_by_type(PawnDiseaseComponent) as PawnDiseaseComponent
	if comp != null:
		comp.infect(disease.id)

func _visitor_disease_pool() -> Array[DiseaseData]:
	var tier: int = Global.unlock_manager.current_tier if Global.unlock_manager != null else 1
	var out: Array[DiseaseData] = []
	for disease: DiseaseData in DiseaseData.unlocked_at_tier(tier):
		if disease.has_acquisition(&"visitor"):
			out.append(disease)
	return out

# --- departure ----------------------------------------------------------------

## Called by a VisitorPawn as it walks out (a real exit was reachable). Drifts
## reputation by the departure mood and updates the live count.
func on_visitor_departed(pawn: VisitorPawn, happy: bool) -> void:
	reputation = reputation_after_departure(reputation, happy, reputation_gain_happy, reputation_loss_unhappy)
	_visitor_count = maxi(_visitor_count - 1, 0)
	SignalBus.visitor_departed.emit(pawn, happy)
	SignalBus.visitors_changed.emit()

# --- queries (UI) -------------------------------------------------------------

## Live guest count derived from the pawn group (authoritative), not the counter -
## the counter can drift if a guest is freed without a clean departure.
func visitor_count() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(Groups.PAWN):
		if node is VisitorPawn and not (node as VisitorPawn).is_queued_for_deletion():
			count += 1
	return count

# --- persistence --------------------------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"reputation": reputation,
		"accumulator": _accumulator,
	}

func load_save_data(data: Dictionary) -> void:
	reputation = clampf(float(data.get("reputation", 0.5)), 0.0, 1.0)
	_accumulator = float(data.get("accumulator", 0.0))
	SignalBus.visitors_changed.emit()
