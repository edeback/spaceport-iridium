class_name JobTarget
extends RefCounted

## One of a Job's target slots (WI-44) - RimWorld's LocalTargetInfo, widened to
## cover everything this game's jobs actually point at.
##
## This class exists so that job serialization can be GENERIC. Before WI-44 every
## job hand-wrote get_save_data()/restore() because only the job knew what kind
## of thing its targets were; moving that knowledge here means Job.to_dict() is
## the same three lines for every job type, forever.
##
## Encoding delegates to the SaveManager ref helpers that already existed for
## WI-21 (module_ref / component_ref / asteroid_ref / pile_ref) plus pawn_ref.
## Encoding is pure; only resolution needs a live world.

enum Kind { NONE, MODULE, COMPONENT, PAWN, ASTEROID, PILE, CELL }

## Which slot of a Job this target occupies. Actions take one of these rather
## than a JobTarget directly, so an action can be constructed before the target
## it will operate on is known (Action_FindBestTarget writes into a slot).
enum Slot { A, B, C }

var kind: Kind = Kind.NONE
## Node-ish targets. Always reached through the typed accessors, which
## instance-validity check first - a freed Node compares != null.
var _object: Object = null
var _cell: Vector2i = Vector2i.ZERO

## When true (the default) the Job fails the moment this target stops being
## alive - the declarative replacement for the 11 hand-wired
## SignalBus.module_removed handlers. Set false for a target the job can
## legitimately outlive (e.g. the mining bay a drone has already left).
var fail_on_lost: bool = true

# --- construction -------------------------------------------------------------

static func none() -> JobTarget:
	return JobTarget.new()

static func of_module(module: ModuleBase) -> JobTarget:
	var t := JobTarget.new()
	t.kind = Kind.MODULE
	t._object = module
	return t

static func of_component(component: ComponentBase) -> JobTarget:
	var t := JobTarget.new()
	t.kind = Kind.COMPONENT
	t._object = component
	return t

static func of_pawn(pawn: PawnBase) -> JobTarget:
	var t := JobTarget.new()
	t.kind = Kind.PAWN
	t._object = pawn
	return t

static func of_asteroid(asteroid: AsteroidBase) -> JobTarget:
	var t := JobTarget.new()
	t.kind = Kind.ASTEROID
	t._object = asteroid
	return t

static func of_pile(pile: ResourcePile) -> JobTarget:
	var t := JobTarget.new()
	t.kind = Kind.PILE
	t._object = pile
	return t

static func of_cell(cell: Vector2i) -> JobTarget:
	var t := JobTarget.new()
	t.kind = Kind.CELL
	t._cell = cell
	return t

# --- access -------------------------------------------------------------------

func is_set() -> bool:
	return kind != Kind.NONE

## Live and still meaningful. A CELL is always alive (a coordinate can't be
## freed); everything else must still be a valid instance.
func is_alive() -> bool:
	match kind:
		Kind.NONE:
			return false
		Kind.CELL:
			return true
		_:
			return _object != null and is_instance_valid(_object)

func module() -> ModuleBase:
	if not is_alive():
		return null
	if kind == Kind.MODULE:
		return _object as ModuleBase
	# A component's module is the natural "where is this" answer, so callers that
	# want a module don't have to care which slot kind they were handed.
	if kind == Kind.COMPONENT:
		var component: ComponentBase = _object as ComponentBase
		return component.owner_module if component != null else null
	return null

func component() -> ComponentBase:
	return _object as ComponentBase if kind == Kind.COMPONENT and is_alive() else null

func pawn() -> PawnBase:
	return _object as PawnBase if kind == Kind.PAWN and is_alive() else null

func asteroid() -> AsteroidBase:
	return _object as AsteroidBase if kind == Kind.ASTEROID and is_alive() else null

func pile() -> ResourcePile:
	return _object as ResourcePile if kind == Kind.PILE and is_alive() else null

func cell() -> Vector2i:
	return _cell

## The live object this target names, whatever its kind - the module, component,
## pawn, asteroid or pile - or null for a cell, an unset slot or a freed object.
## What Job.offer_to_owner() hands a restored job back to (WI-70).
func object() -> Object:
	if kind == Kind.CELL or not is_alive():
		return null
	return _object

## The node a movement action should path to. For a component that's its owning
## module (you walk to the module, not to the child node); for a module, itself;
## for a free-floating pile or an asteroid, the thing itself, which is how
## ModuleGraph.pathfind_to_node_in_space already expects to be called.
func move_node() -> Node2D:
	match kind:
		Kind.MODULE, Kind.COMPONENT:
			return module()
		Kind.PILE:
			var p: ResourcePile = pile()
			if p == null:
				return null
			# A pile inside a module is not a graph vertex - path to the module.
			return p.parent_module if p.parent_module != null else p
		Kind.PAWN:
			return pawn()
		Kind.ASTEROID:
			return asteroid()
	return null

## Whether reaching this target means going outside (the `in_space` flag that
## PawnMovementComponent.move_to takes).
func is_exterior() -> bool:
	match kind:
		Kind.ASTEROID:
			return true
		Kind.PILE:
			var p: ResourcePile = pile()
			return p != null and p.parent_module == null
	return false

## Player-facing name, used by the {a}/{b}/{c} report substitutions.
func describe() -> String:
	if not is_alive():
		return "?"
	match kind:
		Kind.MODULE, Kind.COMPONENT:
			var m: ModuleBase = module()
			if m != null and m.module_data != null:
				return m.module_data.name
			return "module"
		Kind.PAWN:
			var p: PawnBase = pawn()
			return p.pawn_name if p != null else "someone"
		Kind.ASTEROID:
			return "asteroid"
		Kind.PILE:
			return "resource pile"
		Kind.CELL:
			return "(%d, %d)" % [_cell.x, _cell.y]
	return "?"

# --- persistence --------------------------------------------------------------

## Encoded form. An unset or dead target encodes as {} and decodes back to an
## unset target, which the Job's restore path treats as "drop this job" when the
## slot was required.
func to_dict() -> Dictionary:
	if not is_alive():
		return {}
	var out: Dictionary = {}
	match kind:
		Kind.MODULE:
			out = SaveRefs.module_ref(_object as ModuleBase)
		Kind.COMPONENT:
			out = SaveRefs.component_ref(_object as ComponentBase)
		Kind.PAWN:
			out = SaveRefs.pawn_ref(_object as PawnBase)
		Kind.ASTEROID:
			out = SaveRefs.asteroid_ref(_object as AsteroidBase)
		Kind.PILE:
			out = SaveRefs.pile_ref(_object as ResourcePile)
		Kind.CELL:
			out = {"cell": [_cell.x, _cell.y]}
	if out.is_empty():
		return {}
	out["kind"] = int(kind)
	if not fail_on_lost:
		out["soft"] = true
	return out

static func from_dict(data: Dictionary) -> JobTarget:
	var t := JobTarget.new()
	if data.is_empty():
		return t
	var decoded_kind: Kind = int(data.get("kind", int(Kind.NONE))) as Kind
	t.fail_on_lost = not bool(data.get("soft", false))
	match decoded_kind:
		Kind.MODULE:
			t._object = SaveRefs.resolve_module_ref(data)
		Kind.COMPONENT:
			t._object = SaveRefs.resolve_component_ref(data)
		Kind.PAWN:
			t._object = SaveRefs.resolve_pawn_ref(data)
		Kind.ASTEROID:
			t._object = SaveRefs.resolve_asteroid_ref(data)
		Kind.PILE:
			t._object = SaveRefs.resolve_pile_ref(data)
		Kind.CELL:
			var cell_arr: Array = data.get("cell", [])
			if cell_arr.size() == 2:
				t.kind = Kind.CELL
				t._cell = Vector2i(int(cell_arr[0]), int(cell_arr[1]))
			return t
		_:
			return t
	# Anything whose ref no longer resolves stays NONE, so is_set() is false and
	# the job's restore path drops it - the same "null propagates as drop this
	# job" contract WI-21 established.
	if t._object != null:
		t.kind = decoded_kind
	return t
