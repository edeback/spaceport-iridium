extends RefCounted

## The other half. Two preloads that a real mod cannot avoid:
##   - another script from the SAME mod, the substitute for class_name
##   - a vanilla script by path, the substitute for a vanilla class_name where
##     the vanilla script has none (statics live on class_name'd scripts here,
##     but a mod may still want a file that isn't in the class cache)
## Both are resolved when THIS script compiles, i.e. after the pack is mounted.

const Helper := preload("res://mods/spikemod/scripts/mod_helper.gd")
const VanillaScanner := preload("res://scripts/utility/resource_scanner.gd")

func helper_static() -> String:
	return Helper.marker()

func helper_instance() -> String:
	var helper := Helper.new()
	return helper.instance_marker()

func vanilla_static_count() -> int:
	# Calls a vanilla static through a preload rather than through its class_name.
	var found: Array[String] = VanillaScanner.scan_paths("res://data/jobs")
	return found.size()

func vanilla_by_class_name_count() -> int:
	# ...and the same thing through the baked vanilla class_name, which M9 says
	# mods may use freely.
	var found: Array[String] = ResourceScanner.scan_paths("res://data/jobs")
	return found.size()

func runtime_load_marker() -> String:
	# load() rather than preload(): resolved when CALLED, which is the pattern a
	# mod needs for optional cross-mod dependencies.
	var script := load("res://mods/spikemod/scripts/mod_helper.gd") as GDScript
	if script == null:
		return "<null>"
	return String(script.call("marker"))
