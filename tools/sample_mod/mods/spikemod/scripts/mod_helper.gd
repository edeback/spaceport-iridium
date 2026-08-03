extends RefCounted

## Half of the mod-to-mod reference test: if class names are unavailable, mods
## need SOME way to share code between their own scripts. preload() by path is
## the candidate.

static func marker() -> String:
	return "spikemod-helper-ok"

func instance_marker() -> String:
	return "spikemod-helper-instance-ok"
