extends GutTest

## Unit tests for the auto-generated report text (WI-44 stage 7) - the strings the
## pawn job tab and the board inspector put on screen.
##
## The point of composing them from `JobData.report_template` plus the job's own
## targets is that a NEW job type gets usable text without writing any UI code, so
## what matters here is that substitution is total (no placeholder survives into
## player-facing text) and that the two kinds of "unknown" stay distinguishable.
##
## Pure: CELL targets need no scene, so these construct definitions and jobs
## directly and never touch Global.

func _data(template: String, display: String = "Test Job") -> JobData:
	var data := JobData.new()
	data.id = &"test_job"
	data.display_name = display
	data.report_template = template
	return data

func _job(template: String, display: String = "Test Job") -> Job:
	return Job.create(_data(template, display))

func _ore(name_text: String = "Iron Ore") -> ResourceData:
	var resource := ResourceData.new()
	resource.id = &"test_ore"
	resource.name = name_text
	return resource

# --- substitution -------------------------------------------------------------

func test_targets_substitute_into_their_placeholders() -> void:
	var job: Job = _job("From {a} to {b} via {c}")
	job.target_a = JobTarget.of_cell(Vector2i(1, 2))
	job.target_b = JobTarget.of_cell(Vector2i(3, 4))
	job.target_c = JobTarget.of_cell(Vector2i(5, 6))
	assert_eq(job.report(), "From (1, 2) to (3, 4) via (5, 6)")

func test_resource_and_count_substitute() -> void:
	var job: Job = _job("Hauling {count} {resource}")
	job.resource = _ore()
	job.count = 12
	assert_eq(job.report(), "Hauling 12 Iron Ore")

func test_no_placeholder_survives_an_unset_job() -> void:
	# Every placeholder resolves to SOMETHING - a raw "{a}" reaching the player is
	# the failure this guards.
	var job: Job = _job("{a} {b} {c} {resource} {count}")
	var text: String = job.report()
	for placeholder: String in ["{a}", "{b}", "{c}", "{resource}", "{count}"]:
		assert_false(text.contains(placeholder), "'%s' was substituted" % placeholder)

func test_empty_template_falls_back_to_the_display_name() -> void:
	assert_eq(_job("", "Doing A Thing").report(), "Doing A Thing",
		"a definition with no template still reads sensibly")

func test_report_is_empty_without_a_definition() -> void:
	assert_eq(Job.new().report(), "", "no definition, nothing to say")

# --- the two kinds of unknown -------------------------------------------------
#
# A slot that was never filled means the job has not CHOSEN yet - its finder runs
# as the first action, and a half-specified haul (a bin posts a pull knowing only
# its own end) is the common case, on screen constantly. A slot whose target has
# since been destroyed is a different situation the player may want to act on.

func test_an_unfilled_slot_reads_as_not_yet_chosen() -> void:
	var job: Job = _job("Hauling to {b}")
	assert_eq(job.report(), "Hauling to somewhere")

func test_a_dead_target_reads_differently_from_an_unfilled_one() -> void:
	var job: Job = _job("Hauling to {b}")
	var doomed := Node2D.new()
	job.target_b = JobTarget.of_module(doomed as ModuleBase)
	doomed.free()
	assert_eq(job.report(), "Hauling to ?",
		"a target that died is not the same as one never picked")

func test_missing_resource_reads_as_a_generic_noun() -> void:
	assert_eq(_job("Hauling {resource}").report(), "Hauling resource")

# --- subtask ------------------------------------------------------------------

func test_subtask_is_empty_before_the_job_starts() -> void:
	assert_eq(_job("x").subtask_report(), "",
		"a board job has no current action, so no subtask line")

func test_category_name_is_readable() -> void:
	var data: JobData = _data("x")
	data.category = JobData.Category.HAUL
	assert_eq(Job.create(data).get_category_name(), "Haul")
