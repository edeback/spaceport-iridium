class_name ModuleData
extends Resource

@export var name: String = ""
@export var scene: PackedScene
@export var icon: Texture2D
@export var tags: Array[String]
## Can you click-drag to place multiples?
@export var multiplacement: bool = false
## If hidden, does not show in UI
@export var hidden: bool = false
