extends ComponentBase

## Sample-mod component that OWNS SAVE STATE (WI-47 M2's acceptance path).
##
## Before stage 2 this was impossible: ModuleBase named every component type by
## hand in get_save_data()/load_save_data(), so a component it had never heard of
## had no seam to persist through at all. Now overriding the two hooks is the
## whole job - nothing in the core knows this file exists.
##
## No class_name: a mod's class names are never registered in an exported build
## (M9), so anything that needs this script references it by path.

## Shimmer skimmed out of the ambient dust, per game-hour.
@export var shimmer_per_hour: float = 1.5

## The accumulated haul. This is the state whose survival across save/load is the
## thing being proved.
var collected: float = 0.0

func _ready() -> void:
	super()
	if Global.time_manager != null:
		Global.time_manager.slow_tick.connect(_on_slow_tick)

func _on_slow_tick(interval: float) -> void:
	# Only a finished, powered-up collector skims anything - a blueprint is a
	# hole in the hull, not a machine.
	if owner_module == null or not owner_module.is_complete():
		return
	collected += shimmer_per_hour * interval / TimeManager.SECONDS_PER_HOUR

# --- persistence (WI-47 M2) -----------------------------------------------------

## Pinned rather than left to default to the node path, which is the mod-author
## rule ComponentBase.save_key() documents: the default key is this component's
## node path, so moving or renaming the node in a later version of the mod would
## orphan every block already written under the old path.
func save_key() -> StringName:
	return &"spikemod.shimmer_collector"

## save_order() is deliberately NOT overridden. The default restores after
## everything the base game does, so this sees a module that is already whole.

func get_save_data() -> Dictionary:
	# Nothing collected yet writes no block, keeping fresh stations lean - the
	# same convention every vanilla component follows.
	if is_zero_approx(collected):
		return {}
	return {"collected": collected}

func load_save_data(data: Dictionary) -> void:
	collected = float(data.get("collected", 0.0))
