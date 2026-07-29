class_name JobDriver_Deconstruct
extends JobDriver_Construct

## Take a module apart (WI-44). Identical to building it, with the work counter
## running backwards - which is exactly how the pre-WI-44 job expressed it too
## (`work_seconds_done += -delta`).
##
## A separate driver and a separate .tres rather than a flag on the job, so
## make_actions() branches on the TYPE and never on mutable state. The saved
## action index has to mean the same thing after a load, and a driver that could
## produce two different sequences for the same definition would break that.

func reversed() -> bool:
	return true
