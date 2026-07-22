class_name PawnBase
extends Node2D

@export var current_module: ModuleBase:
	set = _on_module_changed
@export var destination_cell: Vector2i
@export var destination_module: ModuleBase
@export var path: PackedVector2Array
@export var speed: float = 80.0
@export var carrying_capacity: int = 10
@export var animated_sprite: AnimatedSprite2D
@export var pawn_name: String = ""
## Stable per-pawn save id (WI-23), assigned once from a static counter and
## round-tripped through the save's pawn section. Workspace assignments
## (WorkspaceComponent) persist as these ids, since module save data loads
## before pawns exist and can't hold live references. 0 = unassigned; _ready
## allocates one lazily so scene-embedded and spawned pawns both get an id.
@export var pawn_id: int = 0
## Per-pawn identity tint (WI-22), rolled from CrewManager's palette at spawn.
## Unlike the cosmetic speed_jitter/lane_offset (reseeded from the instance id
## each load), this is identity - it's saved and restored so a pawn keeps its
## colour across sessions. Applied to the AnimatedSprite2D's modulate so it
## rides along through animation frame changes.
@export var tint: Color = Color.WHITE:
	set(value):
		tint = value
		_apply_tint()
## What this pawn cost to hire (WI-22), stored so WI-25 wages can read it.
## Starting crew get the base hire_cost; hires get their candidate's price.
@export var hire_price: int = 0
## Visitor pawns (WI-26 ARC inspector; WI-33 guests reuse this) are transient:
## not crew, never saved, never draw a wage. CrewManager.get_crew and the
## SaveManager pawn section both skip them, the same way both skip drones.
## WI-33 does save GUEST visitors (see SaveManager); the inspector stays unsaved.
@export var is_visitor: bool = false
## Personal wallet (WI-33). Crew accumulate this as WI-25 wages route to the pawn
## instead of vanishing, and spend it at shops/hotels/dining (money returns to
## station income, levy applies once at the register). Visitors arrive with a
## rolled balance and leave when it runs dry. Saved on both crew and guests.
@export var personal_credits: int = 0:
	set(value):
		var clamped: int = maxi(value, 0)
		if personal_credits != clamped:
			personal_credits = clamped
			personal_credits_changed.emit(personal_credits)
signal personal_credits_changed(new_total: int)
@export var collision: Area2D
## 24-hour WORK/REST schedule (WI-06). Null (drones, anything unscheduled)
## means always on duty. Duplicated per pawn in _ready so the schedule tab
## can paint one pawn without editing every pawn sharing the .tres.
@export var schedule: ScheduleData

var movement_component: PawnMovementComponent
var inventory_component: PawnInventoryComponent

## Cosmetic de-overlap (WI-16), both hashed from the instance id in _ready so
## they're stable per pawn without being saved. The lane offset moves only the
## sprite - logical position stays exactly on the path for pathfinding/save.
var speed_jitter: float = 1.0
var lane_offset: float = 0.0
var _sprite_base_position: Vector2 = Vector2.ZERO
## Set while walk_straight_to() drives the pawn so the suspended movement
## component doesn't stomp the walk animation with set_idle() every frame.
var in_manual_walk: bool = false

## Movement speed multiplier (WI-28). Default 1.0 = no-op for crew and normal
## pawns; a robot at zero energy sets this below 1.0 so it crawls to a charger
## on emergency backup power. PawnMovementComponent.move() folds it into travel.
var move_speed_scale: float = 1.0

## Monotonic source for pawn_id (WI-23). Static, so it lives on the script and
## survives the scene swap a load performs; load bumps it past every restored id.
static var _next_pawn_id: int = 1

## STAND anchor this pawn is parked on while idling (arrival spreading).
## Released when the pawn next moves anywhere else.
var _stand_anchor: AnchorDef = null
var _stand_anchor_path: PathComponent = null

## WORKSTATION anchor whose authored animation the pawn is currently playing
## (WI-23). Set by a work job when the pawn arrives at its claimed anchor;
## cleared when the pawn moves away (notify_movement_starting) or the job ends.
## While set, set_idle() plays the anchor's animation instead of idle.
var _work_anchor: AnchorDef = null

var current_layer: WorldManager.StructureLayer = WorldManager.StructureLayer.SPACE
var path_position_override: Node2D = null
var traveling: bool = false
var next_point: int = 0
var current_job: JobBase = null:
	set(new_job):
		if new_job != current_job:
			current_job = new_job
			job_changed.emit()
			

## Jobs waiting for this specific pawn - chained followups (see
## JobBase.get_followup_job) and queued needs (see queue_job()) alike.
## Always checked before the shared board in start_job(), and never touched
## by other pawns or JobManager.
var job_queue: Array[JobBase] = []

## Start the very first job immediately
var job_length: float = 1

var components: Array[PawnComponentBase] = []

signal job_changed
## Emitted when current_module actually changes (WI-22): traits watch this to
## toggle the Spacer exterior modifier and re-evaluate Introvert solitude
## without per-frame group scans.
signal module_changed

func get_component_by_type(type: Variant) -> PawnComponentBase:
	for component: PawnComponentBase in components:
		if is_instance_of(component, type):
			return component
	return null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("pawn")
	# Stable save id (WI-23): fresh pawns take the next counter value; loaded
	# pawns arrive with pawn_id already set (before add_child) and just push the
	# counter past themselves so a later fresh pawn can't collide.
	if pawn_id == 0:
		pawn_id = _next_pawn_id
		_next_pawn_id += 1
	else:
		_next_pawn_id = maxi(_next_pawn_id, pawn_id + 1)
	if schedule != null:
		schedule = schedule.duplicate(true)
	# ±5-10% walk speed and a ±1-3px render lane, hashed so two pawns sharing a
	# route drift apart instead of marching as one sprite (WI-16).
	var h: int = absi(hash(get_instance_id()))
	speed_jitter = 1.0 + (0.05 + float(h % 100) * 0.0005) * (1.0 if (h >> 7) % 2 == 0 else -1.0)
	lane_offset = (1.0 + float((h >> 9) % 100) * 0.02) * (1.0 if (h >> 16) % 2 == 0 else -1.0)
	if animated_sprite != null:
		_sprite_base_position = animated_sprite.position
	# Re-apply in case tint was assigned (spawn/load) before animated_sprite
	# resolved - the setter no-ops until the sprite exists.
	_apply_tint()
	movement_component = PawnMovementComponent.new()
	movement_component.owner_pawn = self
	add_child(movement_component)
	inventory_component = PawnInventoryComponent.new()
	inventory_component.owner_pawn = self
	add_child(inventory_component)
	Global.path_manager.add_vertex(self, true, "", current_module == null)
	SignalBus.module_removed.connect(_on_module_removed)
	#SignalBus.module_selected.connect(_on_module_selected)
	pass # Replace with function body.
	

func _on_module_removed(module: ModuleBase) -> void:
	if current_module == module:
		current_module = null

func try_start_job(new_job: JobBase) -> bool:
	if current_job == null and new_job.can_do_job(self):
		current_job = new_job
		current_job.start_job(self)
		return true
	return false
		

func _process(delta: float) -> void:
	# Sprite playback tracks sim speed (WI-20): 4x pawns animate 4x instead of
	# gliding, and pause freezes the cycle. Re-applied per-frame rather than via
	# TimeManager's sim_animation group because pawns reparent constantly
	# (canvas layers, cab boarding) and group resyncs miss out-of-tree nodes.
	if animated_sprite != null:
		animated_sprite.speed_scale = Global.time_manager.animation_speed()
	var sim_delta: float = Global.time_manager.scale(delta)
	if sim_delta <= 0.0:
		return
	job_length += sim_delta
	if current_job != null:
		# is_ended() backstop: if a stale callback overwrote the terminal state
		# after cancel() (the _ended latch blocks re-cancelling, so the subclass
		# state can never be corrected), the latch itself is still authoritative -
		# drop the job instead of processing it forever.
		if current_job.is_ended() or current_job.is_failed() or current_job.is_finished():
			_end_current_job()
		else:
			current_job.process_job(sim_delta)
	elif job_length > 1.0:
		# We don't want to try to start new jobs more than once a second, such as
		# if a job fails but then is posted and picked up again in rapid succession.
		# This keeps us from doing things like running pathfinding every frame.
		job_length = 0
		start_job()

func _end_current_job() -> void:
	var finished_job: JobBase = current_job
	current_job = null
	# Skill xp on SUCCESSFUL completion only (WI-22) - cancelled/failed jobs
	# grant nothing (a job abandoned at 99% teaches nothing). Trickle-xp jobs
	# like mining keep whatever they earned mid-trip; those return 0 here.
	if finished_job.is_finished():
		grant_skill_xp(finished_job.get_skill(), finished_job.xp_reward())
	# Finalizer for jobs that reached Finished without going through cancel();
	# idempotent, so it's a no-op when cancel() already ended the job.
	finished_job.end_job()
	# Intentionally don't start the next job immediately
		

func start_job() -> void:
	# If we have an inventory, try to store it ASAP
	if inventory_component != null and not inventory_component.is_empty():
		var return_job: Job_StoreInventory = Job_StoreInventory.new()
		if return_job.can_do_job(self):
			_begin_job(return_job)
			return
		# No storage will take what we're carrying right now — fall through and
		# look for a normal job anyway rather than stalling the pawn entirely.
	# Personal queue next - chained followups and queued needs. Checked once
	# here rather than polled every frame by whatever queued them.
	while not job_queue.is_empty():
		var queued_job: JobBase = job_queue.pop_front()
		if queued_job.is_valid() and queued_job.can_do_job(self):
			_begin_job(queued_job)
			return
		queued_job.cancel(true) # cancel implies end_job (lifecycle contract)
	if is_on_shift():
		current_job = Global.job_manager.find_job(self)
	else:
		# Off-shift (WI-06): no station work - only needs/errand categories,
		# which rarely sit on the shared board, so this usually falls through
		# to wandering. A running job is never interrupted by shift end; this
		# gate only applies when picking the NEXT job.
		var off_shift: Array[JobBase.Category] = [JobBase.Category.NEEDS, JobBase.Category.MOVE, JobBase.Category.MISC]
		current_job = Global.job_manager.find_job(self, off_shift)
	if current_job:
		current_job.start_job(self)
	else:
		# Wander!
		var idle_job: Job_IdleWander = Job_IdleWander.new()
		if idle_job.can_do_job(self):
			_begin_job(idle_job)
		else:
			# Can't even move anywhere, idle pose
			if animated_sprite != null:
				animated_sprite.play("idle")

func _begin_job(job: JobBase) -> void:
	current_job = job
	current_job.start_job(self)

## Adds a job to this pawn's personal queue, checked in start_job() ahead of
## the shared board. Use this for queued needs - queue once when the need
## arises instead of polling can_do_job() every frame. to_front = true jumps
## ahead of anything already queued (what chained followup jobs use) but
## still waits for the current job to finish - see interrupt_with_job() to
## preempt immediately instead.
func queue_job(job: JobBase, to_front: bool = false) -> void:
	if to_front:
		job_queue.push_front(job)
	else:
		job_queue.push_back(job)

## Removes a job from the personal queue if present (WI-28): used when a queued
## job is about to be promoted to current via interrupt_with_job, so it isn't
## also left sitting in the queue to be re-popped after it ends. No-op if absent.
func dequeue_job(job: JobBase) -> void:
	job_queue.erase(job)

## Moves an already-queued job to the queue front (critical-need promotion,
## WI-05). Deliberately does NOT interrupt the current job - see the
## starvation-lock comment in PawnNeedsComponent. No-op if the job isn't
## queued (it may already be running or ended).
func promote_queued_job(job: JobBase) -> void:
	var index: int = job_queue.find(job)
	if index > 0:
		job_queue.remove_at(index)
		job_queue.push_front(job)

## Stateless shift check (WI-06): derived from the current hour, so it's
## automatically correct after save/load mid-hour. No schedule = always on
## duty (drones).
func is_on_shift() -> bool:
	if schedule == null:
		return true
	return schedule.is_work_hour(Global.time_manager.hour)

## Happiness consequence v1 (WI-05): work-rate multiplier consulted by jobs
## (construction for now). Pawns without needs (drones) work at full speed.
func work_speed() -> float:
	var needs: PawnNeedsComponent = get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	if needs == null:
		return 1.0
	return lerpf(0.5, 1.1, needs.happiness)

## Lazily-resolved skills component (WI-22). Children run _ready after this
## pawn, so it can't be cached in _ready; the flag caches the (possibly null,
## for drones) lookup after the first job needs it.
var _skills_component: PawnSkillsComponent = null
var _skills_checked: bool = false
func get_skills_component() -> PawnSkillsComponent:
	if not _skills_checked:
		_skills_checked = true
		_skills_component = get_component_by_type(PawnSkillsComponent) as PawnSkillsComponent
	return _skills_component

## Lazily-resolved traits component (WI-22), null for drones. Same caching
## contract as get_skills_component().
var _traits_component: PawnTraitsComponent = null
var _traits_checked: bool = false
func get_traits_component() -> PawnTraitsComponent:
	if not _traits_checked:
		_traits_checked = true
		_traits_component = get_component_by_type(PawnTraitsComponent) as PawnTraitsComponent
	return _traits_component

## Skill multiplier (WI-22) for `skill`; 1.0 for pawns without a skills
## component (drones) or an empty/unknown skill - same no-op contract as
## work_speed() for needless pawns.
func skill_mult(skill: StringName) -> float:
	var skills: PawnSkillsComponent = get_skills_component()
	if skills == null:
		return 1.0
	return skills.skill_mult(skill)

## Combined work rate a job should scale progress by (WI-22): happiness times
## skill, floored so a miserable unskilled pawn still inches forward rather
## than effectively stalling. Unskilled jobs (skill &"") get work_speed() alone.
func work_rate(skill: StringName) -> float:
	return maxf(0.3, work_speed() * skill_mult(skill))

## Personal wallet spend (WI-33): deducts `amount` if affordable and returns true,
## else leaves the wallet untouched and returns false. Shops/hotels/dining call
## this at the register; the deducted amount is then booked as station income.
func spend_credits(amount: int) -> bool:
	if amount <= 0:
		return true
	if personal_credits < amount:
		return false
	personal_credits -= amount
	return true

## Adds `amount` to the wallet (WI-33 wage routing / visitor arrival funding).
func earn_credits(amount: int) -> void:
	if amount > 0:
		personal_credits += amount

## Routes an xp grant to the skills component if present (WI-22). No-op for
## drones or an empty skill, so jobs can call it unconditionally.
func grant_skill_xp(skill: StringName, amount: float) -> void:
	if skill == &"" or amount <= 0.0:
		return
	var skills: PawnSkillsComponent = get_skills_component()
	if skills != null:
		skills.add_xp(skill, amount)

## Ends the current job right now - gracefully, not as a failure, so
## anything the pawn is carrying is left for Job_StoreInventory to sweep up
## afterward instead of lost - and starts new_job immediately. For needs
## that can't wait, e.g. a pawn about to collapse from hunger.
## While the pawn is Conveyed (riding a turbolift cab, WI-20) the job swap
## still happens immediately, but the new job's first movement only starts
## once the carrier releases the pawn at its next floor stop - carriers never
## dump a pawn between floors.
func interrupt_with_job(new_job: JobBase) -> void:
	if current_job != null:
		var interrupted: JobBase = current_job
		current_job = null
		interrupted.cancel(false) # cancel implies end_job (lifecycle contract)
	job_length = 0
	_begin_job(new_job)


#func _exit_tree() -> void:
	#Global.path_manager.remove_vertex(self)
	#if current_job != null:
		#current_job.cancel(true)
		#current_job = null
		
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		release_stand_anchor()
		if is_instance_valid(Global.path_manager):
			Global.path_manager.remove_vertex(self)
		if current_job != null:
			current_job.cancel(true)
			current_job = null
		# Cancel queued jobs too (WI-23): a queued job that never runs otherwise
		# never reaches _on_end, leaking its reservations/claims - e.g. a chained
		# Job_WorkProcessor would pin its processor's outstanding-job slot forever
		# and deadlock the machine. cancel() is idempotent and releases cleanly.
		for queued_job: JobBase in job_queue:
			queued_job.cancel(true)
		job_queue.clear()
		# TODO: We don't have pawn death in any meaningful way yet, so just conclude
		# if we're being destroyed, dump our inventory. Skipped during game
		# teardown (managers already gone) and when there's nothing to dump.
		if not is_instance_valid(inventory_component) or inventory_component.is_empty():
			return
		if not is_instance_valid(Global.world_manager) or not is_instance_valid(Global.world_manager.pawn_layer):
			return
		var pile := ResourcePile.spawn(Global.world_manager.pawn_layer, global_position, current_module)
		inventory_component.dump_all_to_pile(pile)

func move_to(new_pos: Vector2, use_exact_position: bool = false) -> void:
	if animated_sprite != null:
		if position.x == new_pos.x:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("walk")
			animated_sprite.flip_h = new_pos.x < position.x
			animated_sprite.rotation_degrees = abs(animated_sprite.rotation_degrees) * (-1 if animated_sprite.flip_h else 1)
		# Render-only lane offset, perpendicular to travel (WI-16). Applied to
		# the sprite, never global_position - the logical path stays exact.
		var travel: Vector2 = new_pos - global_position
		if use_exact_position:
			animated_sprite.position = _sprite_base_position
		elif travel.length_squared() > 0.01:
			animated_sprite.position = _sprite_base_position + travel.orthogonal().normalized() * lane_offset
	global_position = new_pos

## Straight-line cosmetic walk (WI-16) for short legs that happen while the
## movement component is suspended in a path hook (turbolift queue spots, cab
## boarding). Interiors are open boxes, so the straight line is safe.
func walk_straight_to(dest: Vector2) -> void:
	var tree: SceneTree = get_tree()
	in_manual_walk = true
	while true:
		if not is_instance_valid(self) or not is_inside_tree():
			in_manual_walk = false
			return
		var sim_delta: float = Global.time_manager.scale(get_process_delta_time())
		if sim_delta > 0.0:
			move_to(global_position.move_toward(dest, speed * speed_jitter * sim_delta))
			if global_position.distance_squared_to(dest) < 0.25:
				break
		await tree.process_frame
	in_manual_walk = false
	set_idle()

## Claim a STAND spot in the current module for idle spreading; returns null
## when the module has no free spot (caller just stays put - never block on
## anchor scarcity). The claim is released automatically on the next movement.
func claim_stand_anchor() -> AnchorDef:
	release_stand_anchor()
	if current_module == null or current_module.get_path_component() == null:
		return null
	var pc: PathComponent = current_module.get_path_component()
	_stand_anchor = pc.claim_anchor(AnchorDef.AnchorType.STAND, self)
	if _stand_anchor != null:
		_stand_anchor_path = pc
	return _stand_anchor

func release_stand_anchor() -> void:
	if _stand_anchor_path != null and is_instance_valid(_stand_anchor_path):
		_stand_anchor_path.release_anchor(self)
	_stand_anchor_path = null
	_stand_anchor = null

## Called by the movement component when a new movement starts: any parked
## stand claim is stale unless this movement IS the walk to that claim.
func notify_movement_starting(anchor: AnchorDef) -> void:
	if _stand_anchor != null and anchor != _stand_anchor:
		release_stand_anchor()
	# Leaving a workstation drops its animation (unless we're walking to it);
	# the move animation takes over immediately once travel begins (WI-23).
	if _work_anchor != null and anchor != _work_anchor:
		_work_anchor = null

## Parks the pawn on a WORKSTATION anchor and plays its authored animation
## (WI-23). Called by a work job the moment its pawn arrives at the anchor.
func begin_anchor_animation(anchor: AnchorDef) -> void:
	_work_anchor = anchor
	_play_work_or_idle()

## Stops any anchor animation and returns to idle (WI-23). Called by a work job
## when it ends so a pawn that stays put doesn't keep working an empty machine.
func end_anchor_animation() -> void:
	_work_anchor = null
	_play_work_or_idle()

## Plays the active work anchor's animation if the sprite defines it, else idle.
func _play_work_or_idle() -> void:
	if animated_sprite == null:
		return
	if _work_anchor != null and _work_anchor.animation != &"" \
			and animated_sprite.sprite_frames != null \
			and animated_sprite.sprite_frames.has_animation(_work_anchor.animation):
		animated_sprite.play(_work_anchor.animation)
	else:
		animated_sprite.play("idle")

func set_idle() -> void:
	_play_work_or_idle()

## Pushes the identity tint (WI-22) onto the sprite. Safe to call before the
## sprite resolves - it just no-ops, and _ready re-applies once it exists.
func _apply_tint() -> void:
	if animated_sprite != null:
		animated_sprite.modulate = tint

func _on_module_changed(new_module: ModuleBase) -> void:
	if current_module != new_module:
		current_module = new_module
		update_layer_and_sprite()
		module_changed.emit()

func update_layer_and_sprite() -> void:
	if current_module == null:
		if current_layer != WorldManager.StructureLayer.SPACE:
			current_layer = WorldManager.StructureLayer.SPACE
			reparent(Global.world_manager.get_canvas_for_layer(current_layer))
		Global.path_manager.set_exterior(self, true)
		animated_sprite.rotation_degrees = 90
	else:
		Global.path_manager.set_exterior(self, false)
		animated_sprite.rotation_degrees = 0
		if current_layer != current_module.module_data.interaction_layer:
			current_layer = current_module.module_data.interaction_layer
			reparent(Global.world_manager.get_canvas_for_layer(current_layer))

#func _find_next_job() -> void:
	#if current_job == null:
		#current_job = Global.job_manager.find_job()
	#pass

func _on_collision_clicked(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event.is_action_pressed("build"):
		get_viewport().set_input_as_handled()
		Global.ui_main.pawn_clicked(self)
