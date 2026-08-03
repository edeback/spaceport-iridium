class_name PawnTraitsComponent
extends PawnComponentBase

## The 0-2 traits a pawn carries (WI-22). Traits never run their own process
## loop: this component applies their permanent happiness modifiers and toggles
## the exterior (Spacer) one on interior/exterior transitions, and the host
## systems (PawnHealthComponent, SocializeComponent) query the aggregate hook
## methods below. Only organic crew carry this; drones spawn without it, so
## PawnBase.get_traits_component() returns null and every query no-ops.

## Modifier id for the combined exterior (Spacer) happiness offset - one key so
## it toggles cleanly regardless of how many exterior traits a pawn has.
const EXTERIOR_MOD_ID: StringName = &"trait_exterior"

var traits: Array[TraitData] = []
## Cached sibling - component _ready order isn't guaranteed, so resolve lazily.
var _needs: PawnNeedsComponent = null

func _ready() -> void:
	super()
	# Spacer + Introvert care about interior/exterior; re-evaluate on the move
	# signal (prompt) and slow_tick (backstop), never per-frame. Connections die
	# with the node.
	owner_pawn.module_changed.connect(_on_module_changed)
	Global.time_manager.slow_tick.connect(_on_slow_tick)

func _needs_component() -> PawnNeedsComponent:
	if _needs == null:
		_needs = owner_pawn.get_component_by_type(PawnNeedsComponent) as PawnNeedsComponent
	return _needs

## Replaces the trait set and (re)applies its permanent happiness modifiers.
## Called at spawn (rolled) and on load (from the saved id list). Idempotent:
## clears the previous set's modifiers first so it's safe to call repeatedly.
func set_traits(new_traits: Array[TraitData]) -> void:
	_clear_happiness_modifiers()
	traits = new_traits.duplicate()
	_apply_happiness_modifiers()
	_update_exterior_modifier()

## Adds one trait if not already present (cheat / future hire flow) and
## re-applies. Does not enforce exclusive_group - callers that care roll via
## TraitData.roll_set.
func add_trait(trait_data: TraitData) -> void:
	if trait_data == null or has_trait(trait_data.id):
		return
	traits.append(trait_data)
	_apply_happiness_modifiers()
	_update_exterior_modifier()

func has_trait(trait_id: StringName) -> bool:
	for trait_data: TraitData in traits:
		if trait_data.id == trait_id:
			return true
	return false

# --- aggregate hook queries (read by host systems) ---------------------------

## Product of every trait's damage multiplier (Hardy 0.75, Weak 1.25); 1.0 with
## no relevant trait.
func damage_multiplier() -> float:
	var m: float = 1.0
	for trait_data: TraitData in traits:
		m *= trait_data.damage_multiplier
	return m

## Product of passive-social multipliers (Introvert 0, Extrovert 2); 1.0 normal.
func passive_social_multiplier() -> float:
	var m: float = 1.0
	for trait_data: TraitData in traits:
		m *= trait_data.passive_social_multiplier
	return m

## Extra percentage points on the passive-social recreation cap (Extrovert).
func passive_social_cap_bonus() -> float:
	var b: float = 0.0
	for trait_data: TraitData in traits:
		b += trait_data.passive_social_cap_bonus
	return b

## True if any trait recharges recreation while alone (Introvert).
func prefers_solitude() -> bool:
	for trait_data: TraitData in traits:
		if trait_data.solitude_recreation:
			return true
	return false

# --- happiness modifier plumbing ---------------------------------------------

func _apply_happiness_modifiers() -> void:
	var needs: PawnNeedsComponent = _needs_component()
	if needs == null:
		return
	for trait_data: TraitData in traits:
		if trait_data.happiness_offset != 0.0:
			# INF duration: a permanent modifier keyed by the trait id.
			needs.add_modifier(trait_data.id, trait_data.happiness_offset)

func _clear_happiness_modifiers() -> void:
	var needs: PawnNeedsComponent = _needs_component()
	if needs == null:
		return
	for trait_data: TraitData in traits:
		needs.remove_modifier(trait_data.id)
	needs.remove_modifier(EXTERIOR_MOD_ID)

func _exterior_offset() -> float:
	var o: float = 0.0
	for trait_data: TraitData in traits:
		o += trait_data.exterior_happiness_offset
	return o

## Adds the exterior happiness modifier while outside (current_module == null),
## removes it inside. No-op when no trait has an exterior offset.
func _update_exterior_modifier() -> void:
	var needs: PawnNeedsComponent = _needs_component()
	if needs == null:
		return
	var offset: float = _exterior_offset()
	if offset != 0.0 and owner_pawn.current_module == null:
		needs.add_modifier(EXTERIOR_MOD_ID, offset)
	else:
		needs.remove_modifier(EXTERIOR_MOD_ID)

func _on_module_changed() -> void:
	_update_exterior_modifier()

func _on_slow_tick(_interval: float) -> void:
	_update_exterior_modifier()

# --- persistence --------------------------------------------------------------
# Only the id list is saved; the happiness modifiers are re-applied from it on
# load via set_traits (NOT saved as modifiers), mirroring how station-wide
# effects are re-derived rather than persisted.

func save_order() -> int:
	return 40

func save_key() -> StringName:
	return &"traits"

## The block is `{"ids": [...]}`. It was a bare Array until WI-47 stage 2, and had
## to change: the shared hook is Dictionary-typed (GDScript forbids narrowing an
## overridden parameter, so one component cannot opt into a different shape), and
## a component that can't use the hook can't be walked generically. SaveManager
## wraps the legacy Array on the way in, so old saves are unaffected.
func get_save_data() -> Dictionary:
	var ids: Array = []
	for trait_data: TraitData in traits:
		ids.append(String(trait_data.id))
	if ids.is_empty():
		return {}
	return {"ids": ids}

func load_save_data(data: Dictionary) -> void:
	var restored: Array[TraitData] = []
	for entry: Variant in data.get("ids", []):
		var trait_data: TraitData = TraitData.by_id(StringName(entry))
		if trait_data != null:
			restored.append(trait_data)
	set_traits(restored)
