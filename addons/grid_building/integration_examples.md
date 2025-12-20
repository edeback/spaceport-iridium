


# Grid Building Plugin: Integration Examples

## [b]How to Use These Examples[/b]
These code snippets show how to integrate the Grid Building Plugin with your main game code. Use them to:
- Connect to plugin signals and respond to build or manipulation events
- Read event data (success/failure, positions, reasons) for use in other systems (UI, game logic, analytics)
- Implement dependency injection for custom nodes using the plugin's container system
- Extract placement results and failure messages for debugging or player feedback


## Connect to signals on BuildingState
```gdscript
@export var state: BuildingState

func _ready():
    if state != null:
        state.success.connect(_on_build_success)

func _on_build_success(data: BuildActionData):
    # Handle build success event
```


## Create your own GBInjectable node (dependency injection interface)
Extend GBInjectable and implement the required interface for automatic injection:
```gdscript
extends GBInjectable

## Called automatically by GBInjectorSystem
func resolve_gb_dependencies(container: GBCompositionContainer) -> void:
    # Example: get a logger and a state from the container
    var logger: GBLogger = container.get_logger()
    var building_state: BuildingState = container.get_building_state()
    # Store or use dependencies as needed
```

## Create your own GBInjectable RefCounted (object not in scene tree, auto-freed when unreferenced)
Extend GBInjectable for objects that are not nodes and exist only in memory:
```gdscript
extends GBInjectable
class_name MyInjectedObject

## Called automatically by GBInjectorSystem (if created via factory)
func resolve_gb_dependencies(container: GBCompositionContainer) -> void:
    var logger: GBLogger = container.get_logger()
    var building_state: BuildingState = container.get_building_state()
    # Store or use dependencies as needed

## Static factory for injection
static func create_with_injection(container: GBCompositionContainer) -> MyInjectedObject:
    var obj := MyInjectedObject.new()
    container.inject(obj)
    return obj
```


## Read failure messages from BuildingSystem or ManipulationSystem placement (like build_log.gd)
When placement fails, you can read the failure message from the result:
```gdscript
func _on_build_failed(result: RuleResult):
    var message: String = result.reason
    # Display or log the failure message
    print("Placement failed: %s" % message)
```

Or, if handling a list of results (e.g. from validation):
```gdscript
func _on_build_failed(results: Array[RuleResult]):
    for result in results:
        if not result.success:
            print("Failure: %s" % result.reason)
```