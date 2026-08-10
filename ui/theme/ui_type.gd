class_name UIType

## Every theme *type variation* name the console UI uses, in one place (WI-49).
##
## Same argument as [Groups] (WI-41): a type variation is a contract between a
## `.tres` theme entry and a `theme_type_variation` assignment in code, tied
## together by a bare string. A misspelling on either side is silent - the
## control simply renders with its base type's look and nobody notices until a
## screenshot. These constants make the surface greppable and the typo a parse
## error.
##
## Constants only. The theme itself lives in `ui/themes/base_theme.tres`; this
## file only names the variations, it does not define them.
##
## Why variations at all, rather than per-label font overrides: Godot's [Font]
## has no letter-spacing, and the design leans on tracking heavily (.18em panel
## titles, .20em readout labels). Tracking comes from [FontVariation]'s
## `spacing_glyph`, which is a *font resource* property - so the only way to
## have it without an override on every label is to bake the whole type scale
## into theme variations. See [UIMetrics] for the tracking values themselves,
## which widgets need in order to compensate when they centre a tracked label.

# --- label variations ---------------------------------------------------------

## Panel header title. Chakra Petch 700, 15px, heavy tracking, caps.
const PANEL_TITLE: StringName = &"PanelTitle"

## Readout header label and section labels. Chakra Petch 600, 11px, the heaviest
## tracking in the scale, caps.
const READOUT_LABEL: StringName = &"ReadoutLabel"

## A crew member's, module's or ship's name in a row. Chakra Petch 600, 15px.
const ENTITY_NAME: StringName = &"EntityName"

## The same, at the size the inspector's selected subject uses. 18px.
const ENTITY_NAME_LARGE: StringName = &"EntityNameLarge"

## Every number. IBM Plex Mono 700, 13px.
const METRIC: StringName = &"Metric"

## A headline number - the console vitals, a panel's balance chip. IBM Plex Mono
## 700, 16px.
const METRIC_LARGE: StringName = &"MetricLarge"

## The console clock, and nothing else (WI-50). IBM Plex Mono 700, 28px - the
## largest type in the HUD, because the time zone is the one readout the player
## checks without looking for it.
const CLOCK: StringName = &"ClockMetric"

## The status line under an entity name. IBM Plex Mono 500, 11px, light
## tracking, caps.
const META_LINE: StringName = &"MetaLine"

## Console mode-button label. Chakra Petch 600, 9px - the smallest type in the
## design, and the reason MSDF stays off for the UI fonts.
const MODE_LABEL: StringName = &"ModeLabel"

## The hotkey hint right-aligned in a panel header. IBM Plex Mono 500, 11px.
const HOTKEY: StringName = &"Hotkey"

## Tab strip label. Chakra Petch 600, 12px.
const TAB_LABEL: StringName = &"TabLabel"

## Prose: descriptions, tooltips, explanations. IBM Plex Sans 400, 13px. This is
## also the theme's default font, so a plain [Label] already reads as Body - the
## variation exists so prose can be tagged explicitly where it matters.
const BODY: StringName = &"Body"

# --- button variations --------------------------------------------------------

## The design's three button weights. `ActionButton` picks one; nothing else
## should assign these directly, because the destructive-is-outline-only rule
## (invariant, program doc palette table) is enforced in that widget.

## LIVE-tinted fill, LIVE border. The one thing this panel is for.
const ACTION_PRIMARY: StringName = &"ActionPrimary"

## Dim fill, control border. Everything else.
const ACTION_SECONDARY: StringName = &"ActionSecondary"

## Outline only, never a filled button. Demolish and fire.
const ACTION_DESTRUCTIVE: StringName = &"ActionDestructive"

## Selected tab in a `TabStrip`: LIVE-tinted fill, active border, no bottom edge
## so it sits on the strip's underline.
const TAB_ACTIVE: StringName = &"TabActive"

## Unselected tab: no fill, no border, secondary text.
const TAB_INACTIVE: StringName = &"TabInactive"
