class_name RideRequest
extends RefCounted

var pawn: PawnBase
var from_floor: ModuleTurbolift
var to_floor: ModuleBase           ## null once cancelled — "get off wherever, don't hold this stop"
var stand_position: Marker2D
var actual_dropoff_floor: ModuleBase = null
var cancelled: bool = false
signal finished(success: bool)
