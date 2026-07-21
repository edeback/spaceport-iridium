class_name ConveyorLane
extends RefCounted

## One independent transfer link inside a ConveyorComponent (WI-27): its own
## source, destination, resource, and rate-limited buffer. A base conveyor runs a
## single lane; the "Extra Belt" local upgrade adds more (up to 4 total), so one
## conveyor can shuttle several resources between several storage pairs at once.
##
## Endpoints are ComponentBase (a StorageComponent or another ConveyorComponent);
## the owning ConveyorComponent branches on the concrete type when moving goods.

var source: ComponentBase = null
var destination: ComponentBase = null
var resource: ResourceData = null
## Goods physically in transit on this lane. Real stacks, so instance data
## (ore richness) survives the hop and the pile-on-removal keeps it.
var buffer: ResourceStackContainer = ResourceStackContainer.new()
## Fractional units carried between ticks so a slow rate still moves whole units.
var intake_credit: float = 0.0
## Player-facing status line for this lane ("Destination full", "Source removed", ...).
var status: String = ""

func is_configured() -> bool:
	return resource != null and (source != null or destination != null)
