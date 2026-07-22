class_name PirateShipHud
extends Node2D

## Untinted overlay for a PirateShip (WI-32): draws the laser beam flash and a
## current/max HP bar. Lives as a child so the parent's hostile-red self_modulate
## (which tints the ship sprite) doesn't wash out the beam colours or the HP text.

const BEAM_FLASH_SECONDS: float = 0.14

var _beam_time: float = 0.0
var _beam_from := Vector2.ZERO
var _beam_to := Vector2.ZERO
var _beam_absorbed: bool = false

## Flash a beam from `from` to `to`; `absorbed` colours it as a shield hit.
func flash_beam(from: Vector2, to: Vector2, absorbed: bool) -> void:
	_beam_time = BEAM_FLASH_SECONDS
	_beam_from = from
	_beam_to = to
	_beam_absorbed = absorbed
	queue_redraw()

func _process(delta: float) -> void:
	# Cosmetic, so it fades on wall-clock time and ignores pause.
	if _beam_time > 0.0:
		_beam_time = maxf(_beam_time - delta, 0.0)
		queue_redraw()

func _draw() -> void:
	var ship: PirateShip = get_parent() as PirateShip
	if ship == null:
		return
	if _beam_time > 0.0:
		var alpha: float = _beam_time / BEAM_FLASH_SECONDS
		var beam_color: Color = Color(0.5, 0.9, 1.0, alpha) if _beam_absorbed else Color(1.0, 0.3, 0.25, alpha)
		draw_line(to_local(_beam_from), to_local(_beam_to), beam_color, 3.0, true)
		draw_circle(to_local(_beam_to), 7.0 * alpha, beam_color)
	if ship.max_hp > 0.0:
		var frac: float = clampf(ship.hp / ship.max_hp, 0.0, 1.0)
		var width: float = 44.0
		var origin := Vector2(-width * 0.5, -50.0)
		draw_rect(Rect2(origin, Vector2(width, 5.0)), Color(0.0, 0.0, 0.0, 0.65))
		var fill: Color = Color(0.4, 0.85, 0.4)
		if frac <= 0.25:
			fill = Color(0.9, 0.3, 0.25)
		elif frac <= 0.5:
			fill = Color(0.9, 0.8, 0.3)
		draw_rect(Rect2(origin, Vector2(width * frac, 5.0)), fill)
		var label: String = "%d/%d" % [ceili(maxf(ship.hp, 0.0)), int(ship.max_hp)]
		draw_string(ThemeDB.fallback_font, origin + Vector2(0.0, -3.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, width, 11, Color(1.0, 1.0, 1.0, 0.9))
