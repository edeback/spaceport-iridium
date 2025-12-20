## Centralized enums used across the Grid Building plugin.
##
## Collects shared enum types (modes, actions, statuses, tile types) used by systems, UI, and tests.
class_name GBEnums

## Defines what building operation is being performed
enum Mode { OFF, INFO, BUILD, MOVE, DEMOLISH }  ## Building systems are offline  ## Targeting objects for information purposes only  ## Objects currently being placed  ## Changing Position, Rotation, or Size of Existing Objects  ## Destroying destructible objects from the scene

## Defines what moves are allowed for purposes like AStarGrid2D pathing
enum MoveDirection {
	SINGLE,  ## Only allow moves in a single direction up, down, left, right
	ALLOW_DIAGONOL,  ## Allow diagonal moves that go in both X, Y axis at the same time
}

## Actions that can be taken within the building system
enum Action { BUILD, MOVE, ROTATE, FLIP_H, FLIP_V, DEMOLISH }  # Place object in location  # Move object to new location  # Rotate object left or right  # Flip horizontally  # Flip vertically  # Destroy a scene object

## Type of build operation being performed
enum BuildType {
	SINGLE,  ## Single click/confirmation build
	DRAG,    ## Continuous drag-building across multiple tiles
	AREA     ## Future: Build across a defined area (e.g., fence line from point A to B)
}

## Status for a build / manipulation action
enum Status { CREATED, STARTED, FAILED, FINISHED, CANCELED }  # Data for action has been created  # Action has been started and is running  # Action failed to execute. Some actions can continue to attempt to finish after initial failing.  # Action has finished executing successfully,  # Action was manually canceled before finishing execution

## Projection methods for screen to world conversion
enum ProjectionMethod { UNPROJECT, SCREEN_TO_WORLD, CAMERA_INVERSE, EVENT_GLOBAL, EVENT_POS }

## Manual recenter targets for GridPositioner2D input actions
enum CenteringMode { CENTER_ON_SCREEN, CENTER_ON_MOUSE }  ## Center on the middle of the active viewport  ## Center on the current mouse cursor position

## Convert Mode enum to a stable string for diagnostics and UI
static func mode_to_string(mode: Mode) -> String:
	match mode:
		Mode.OFF:
			return "OFF"
		Mode.INFO:
			return "INFO"
		Mode.BUILD:
			return "BUILD"
		Mode.MOVE:
			return "MOVE"
		Mode.DEMOLISH:
			return "DEMOLISH"
		_:
			return str(int(mode))

## Convert ProjectionMethod enum to string
static func projection_method_to_string(method: ProjectionMethod) -> String:
	match method:
		ProjectionMethod.UNPROJECT:
			return "unproject_position"
		ProjectionMethod.SCREEN_TO_WORLD:
			return "screen_to_world"
		ProjectionMethod.CAMERA_INVERSE:
			return "camera_inverse"
		ProjectionMethod.EVENT_GLOBAL:
			return "event.global_position"
		ProjectionMethod.EVENT_POS:
			return "event.position"
		_:
			return str(int(method))


