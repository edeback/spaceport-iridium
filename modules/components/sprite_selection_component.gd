class_name SpriteSelectionComponent
extends ComponentBase

@export var sprite: Sprite2D

const UP_BLOCKED: int = 0b0001
const DOWN_BLOCKED: int = 0b0010
const LEFT_BLOCKED: int = 0b0100
const RIGHT_BLOCKED: int = 0b1000

const OFFSET_DICT: Dictionary[int, Vector2] = {
	DOWN_BLOCKED: Vector2(0, 0),
	UP_BLOCKED + DOWN_BLOCKED: Vector2(0, 64),
	UP_BLOCKED: Vector2(0, 128),
	0: Vector2(0, 192),
	
	DOWN_BLOCKED + RIGHT_BLOCKED: Vector2(64, 0),
	DOWN_BLOCKED + RIGHT_BLOCKED + UP_BLOCKED: Vector2(64, 64),
	UP_BLOCKED + RIGHT_BLOCKED: Vector2(64, 128),
	RIGHT_BLOCKED: Vector2(64, 192),
	
	DOWN_BLOCKED + RIGHT_BLOCKED + LEFT_BLOCKED: Vector2(128, 0),
	UP_BLOCKED + DOWN_BLOCKED + LEFT_BLOCKED + RIGHT_BLOCKED: Vector2(128, 64),
	UP_BLOCKED + LEFT_BLOCKED + RIGHT_BLOCKED: Vector2(128, 128),
	LEFT_BLOCKED + RIGHT_BLOCKED: Vector2(128, 192),
	
	DOWN_BLOCKED + LEFT_BLOCKED: Vector2(192, 0),
	UP_BLOCKED + DOWN_BLOCKED + LEFT_BLOCKED: Vector2(192, 64),
	UP_BLOCKED + LEFT_BLOCKED: Vector2(192, 128),
	LEFT_BLOCKED: Vector2(192, 192),
}


func _ready() -> void:
	super()
	SignalBus.module_added.connect(set_sprite)
	SignalBus.module_removed.connect(set_sprite)
	set_sprite(null)

func set_sprite(_module: ModuleBase) -> void:
	var blocked_value: int = 0
	var up_cell: Vector2i = owner_module.module_cell - Vector2i(0, 1)
	if Global.world_manager.get_module_by_cell(owner_module.module_data.interaction_layer, up_cell) != null:
		blocked_value += UP_BLOCKED
	var down_cell: Vector2i = owner_module.module_cell + Vector2i(0, owner_module.size.y)
	if Global.world_manager.get_module_by_cell(owner_module.module_data.interaction_layer, down_cell) != null:
		blocked_value += DOWN_BLOCKED
	var left_cell: Vector2i = owner_module.module_cell - Vector2i(1, 0)
	if Global.world_manager.get_module_by_cell(owner_module.module_data.interaction_layer, left_cell) != null:
		blocked_value += LEFT_BLOCKED
	var right_cell: Vector2i = owner_module.module_cell + Vector2i(owner_module.size.x, 0)
	if Global.world_manager.get_module_by_cell(owner_module.module_data.interaction_layer, right_cell) != null:
		blocked_value += RIGHT_BLOCKED
	sprite.region_rect.position = OFFSET_DICT[blocked_value]
	sprite.region_rect.position.x *= owner_module.size.x
	sprite.region_rect.position.y *= owner_module.size.y
	sprite.region_rect.size = Vector2(owner_module.size * Global.CELL_SIZE)
