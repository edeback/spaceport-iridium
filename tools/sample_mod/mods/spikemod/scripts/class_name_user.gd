extends RefCounted

## M9 spike, NEGATIVE control: one mod script referencing ANOTHER mod script by
## class_name. Expected to fail to compile in an exported build. If it loads,
## M9's central constraint is wrong and mods get a much nicer authoring story.

func make() -> SpikeShimmerData:
	return SpikeShimmerData.new()
