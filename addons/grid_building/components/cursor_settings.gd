class_name CursorSettings
extends GBResource
## Set of cursor textures for use with grid builder plugin

## Cursor for info mode
@export var info: Texture = preload("uid://kvyhj5gt5201")

## Cursor for build mode
@export var build: Texture = preload("uid://8336o2tpme2x")

## Cursor for move mode
@export var move: Texture = preload("uid://5kmk28req3jq")

## Cursor for demolish mode
@export var demolish: Texture = preload("uid://bq3kvob3eai1r")

## Returns an array of issues found during editor validation
func get_editor_issues() -> Array[String]:
	var issues: Array[String] = []
	
	if info == null:
		issues.append("CursorSettings info texture is not set")
	
	if build == null:
		issues.append("CursorSettings build texture is not set")
	
	if move == null:
		issues.append("CursorSettings move texture is not set")
	
	if demolish == null:
		issues.append("CursorSettings demolish texture is not set")
	
	return issues

## Returns an array of issues found during runtime validation
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	
	issues.append_array(get_editor_issues())
	
	return issues
