extends JobDriver

## M9 spike: a mod JobDriver, referenced by a vanilla JobData .tres through
## WI-44's `@export var driver: Script`. Deliberately has NO class_name - M9
## predicts a mod's class_name is never registered in an exported build, so
## everything a mod exposes must be reachable by path or uid.

func spike_marker() -> String:
	return "spikemod-driver-ok"

func is_valid(_job: Job) -> bool:
	# References the vanilla `Job` class_name in a signature, which is the other
	# half of "mod scripts can use vanilla class names freely".
	return true
