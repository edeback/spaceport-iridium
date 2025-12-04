class_name ModuleData
extends Resource

@export var name: String = ""
@export var description: String = ""
@export var scene: PackedScene
@export var icon: Texture2D
@export var cost: int
@export var tags: Array[String]
## Can you click-drag to place multiples?
@export var multiplacement: bool = false
## If hidden, does not show in UI
@export var hidden: bool = false

@export var interaction_layer: WorldManager.InteractionLayer = WorldManager.InteractionLayer.MODULE
