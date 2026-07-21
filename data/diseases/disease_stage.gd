class_name DiseaseStage
extends Resource

## One stage of a DiseaseData's progression (WI-31). A disease advances through
## its stages in order; each stage drains health, dulls skills, and dents mood
## for duration_hours before worsening to the next. The final stage's duration
## is ignored - it persists (and keeps draining) until the disease is treated.
## Authored as sub-resources inside a DiseaseData .tres, so balance lives in data.

## Game-hours this stage lasts before advancing to the next. Ignored on the
## final stage (terminal until cured).
@export var duration_hours: float = 24.0
## Health points drained per game-hour while this stage is active. Stacks with
## starvation/suffocation in PawnHealthComponent and, like them, suppresses
## passive regen while any drain is active.
@export var health_drain_per_hour: float = 0.0
## Skill id -> levels temporarily subtracted (a positive count; the effective
## level floors at 0). Read by PawnSkillsComponent's disease malus overlay.
@export var skill_maluses: Dictionary[StringName, int] = {}
## Happiness offset applied as a modifier while this stage is active (usually
## negative). 0 = no mood effect.
@export var mood_modifier: float = 0.0
## Movement-speed multiplier while this stage is active. 1.0 = normal; Fervent
## Fever runs hot, so a >1 value is a feverish speed-up (WI-31 flavour).
@export var move_speed_mult: float = 1.0
