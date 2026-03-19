class_name ModuleTurbolift
extends ModuleBase

@export var collision_upper: CollisionShape2D

func _ready() -> void:
	add_to_group("turbolifts")
	super()
	SignalBus.module_added.connect(set_sprite)
	SignalBus.module_removed.connect(set_sprite)
	set_sprite(null)

func on_select(new_selected: bool) -> void:
	super(new_selected)
	#if new_selected:
		#Global.ui_in_game.change_input_mode(UIInGame.InputMode.Turbolift)
	#else:
		#Global.ui_in_game.change_input_mode(UIInGame.InputMode.None)
	
func set_sprite(_module: ModuleBase) -> void:
	if _module == null or _module is ModuleTurbolift or _module is CorridorModule:
		if Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.CORRIDOR, module_cell) == null:
			# No corridor behind, this is just a shaft
			sprite.region_rect.position.x = Global.CELL_SIZE.x * 2
			collision_upper.disabled = false
		else:
			if Global.world_manager.get_module_by_cell(WorldManager.StructureLayer.TURBOLIFT, module_cell + Vector2i(0, -1)) is ModuleTurbolift:
				# There is a turbolift above this
				sprite.region_rect.position.x = Global.CELL_SIZE.x * 1
				collision_upper.disabled = false
			else:
				# Either there is no turbolift on either side (up or down) or there is just a turbolift below (in which case it will handle changing)
				sprite.region_rect.position.x = 0
				collision_upper.disabled = true
		queue_redraw()
