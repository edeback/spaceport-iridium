class_name TutorialTarget
extends RefCounted

## What a coach mark points at (WI-63 §3), parsed from the string a `.dialogue`
## file writes: `guide.point("console:build", "Open the Build panel")`.
##
## A grammar rather than a node path, for two reasons. A node path authored in
## content breaks the moment anybody reorganises `ui/`, silently, in a file no
## test opens. And a path cannot express *"the Build flyout's row for the mess
## hall"*, which does not exist until the flyout is built.
##
## Pure: parsing is here and tested; **resolution is [TutorialCoach]'s**, because
## it needs live nodes. The split is what makes the grammar testable at all.

enum Kind {
	## Unparseable. Never resolves; [TutorialCoach] draws no ring.
	INVALID,
	## A console mode button. Id is the mode's lowercase name (`build`, `trade`).
	CONSOLE,
	## A row on the Build panel's category rail. Id is a `BuildCategoryData` id.
	CATEGORY,
	## A row in the Build panel's module flyout. Id is a `ModuleData` id.
	MODULE,
	## A pinned chip on the console's vitals strip. Id is the chip's id.
	VITAL,
	## Whatever the current hint is about - the pawn or module the trigger handed
	## over. Takes no id.
	SUBJECT,
	## No ring at all: the plate alone, centred above the console. For advice that
	## is about the station rather than about a control.
	SCREEN,
}

## The scheme word each kind is written as. One table, so the parser and the
## error message can never disagree about what is legal.
const SCHEMES: Dictionary[String, Kind] = {
	"console": Kind.CONSOLE,
	"category": Kind.CATEGORY,
	"module": Kind.MODULE,
	"vital": Kind.VITAL,
	"subject": Kind.SUBJECT,
	"screen": Kind.SCREEN,
}

## The kinds written bare, with no `:id` after them. Writing `subject:something`
## is a mistake worth naming rather than ignoring.
const BARE_KINDS: Array[Kind] = [Kind.SUBJECT, Kind.SCREEN]

var kind: Kind = Kind.INVALID
var id: StringName = &""

func _init(new_kind: Kind = Kind.INVALID, new_id: StringName = &"") -> void:
	kind = new_kind
	id = new_id

## Parses `"<scheme>"` or `"<scheme>:<id>"`. An unrecognised scheme, a missing id
## where one is required, or an id where none is allowed all produce an INVALID
## target **and an error naming the string** - a target that silently resolved to
## nothing would leave the player staring at an unmarked screen with the sim held.
static func parse(text: String) -> TutorialTarget:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		push_error("TutorialTarget: empty target string")
		return TutorialTarget.new()
	# split_floats-style rsplit would break `module:mod.thing`; the scheme is
	# everything before the FIRST colon and the id is all the rest, so a
	# namespaced mod id survives intact.
	var separator: int = trimmed.find(":")
	var scheme: String = trimmed if separator < 0 else trimmed.substr(0, separator)
	var rest: String = "" if separator < 0 else trimmed.substr(separator + 1).strip_edges()
	if not SCHEMES.has(scheme):
		push_error("TutorialTarget: unknown target kind '%s' in '%s'" % [scheme, text])
		return TutorialTarget.new()
	var parsed_kind: Kind = SCHEMES[scheme]
	if BARE_KINDS.has(parsed_kind):
		if not rest.is_empty():
			push_error("TutorialTarget: '%s' takes no id, got '%s'" % [scheme, rest])
			return TutorialTarget.new()
		return TutorialTarget.new(parsed_kind)
	if rest.is_empty():
		push_error("TutorialTarget: '%s' needs an id, as '%s:something'" % [scheme, scheme])
		return TutorialTarget.new()
	return TutorialTarget.new(parsed_kind, StringName(rest))

func is_valid() -> bool:
	return kind != Kind.INVALID

## Whether this target names a piece of chrome (a control the coach can ring) as
## opposed to a world subject or the screen at large.
func is_chrome() -> bool:
	return kind == Kind.CONSOLE or kind == Kind.CATEGORY \
		or kind == Kind.MODULE or kind == Kind.VITAL

## Whether a ring is drawn at all. SCREEN is the plate on its own.
func wants_ring() -> bool:
	return is_valid() and kind != Kind.SCREEN

## Round-trips [method parse]. Used by error messages and by the probe's dumps.
func as_text() -> String:
	for scheme: String in SCHEMES:
		if SCHEMES[scheme] != kind:
			continue
		return scheme if BARE_KINDS.has(kind) else "%s:%s" % [scheme, id]
	return "<invalid>"
