## Camera and viewport projection utilities for world coordinate calculations.
##
## Pure, static helpers used across systems (e.g., GridPositioner) and tests.
## These functions are deterministic and do not touch the scene tree beyond
## reading data from provided Camera2D/Viewport instances.
class_name GBCameraUtils
extends RefCounted

## Projection methods for screen to world conversion
const ProjectionMethod = GBEnums.ProjectionMethod

## Convert a projection method enum to a readable string label
static func proj_method_to_string(p_method: ProjectionMethod) -> String:
	match p_method:
		ProjectionMethod.EVENT_POS: return "event.position"
		ProjectionMethod.EVENT_GLOBAL: return "event.global_position"
		ProjectionMethod.UNPROJECT: return "unproject_position"
		ProjectionMethod.SCREEN_TO_WORLD: return "screen_to_world"
		ProjectionMethod.CAMERA_INVERSE: return "camera_inverse"
		_: return "unknown"

## Helper to get the center of the camera's viewport rectangle
static func get_center_of_camera_viewport(cam : Camera2D) -> Vector2:
	var vp_rect : Rect2 = cam.get_viewport_rect()
	return vp_rect.position + (vp_rect.size / 2)