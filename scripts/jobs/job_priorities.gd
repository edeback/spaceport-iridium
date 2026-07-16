class_name JobPriorities
extends RefCounted

## The priority bands, in one place. Storage priority is the routing
## language (sinks must out-priority sources), so keep the bands far apart:
##
##   +99  CONSTRUCTION_IMPORT   material delivery to a construction site
##   +50  COMPLETION_BOOST      finish-what's-started jobs (construct /
##                              deconstruct work on an already-resourced site)
##    +3  TRADE_EXPORT_BIN      staging sell-order goods at the docking bay:
##                              pulls from ordinary storerooms (+1) but loses
##                              to real consumers (kitchen, construction)
##    +1  STORAGE_DEFAULT       ordinary storeroom rebalancing (scene default)
##     0  (unset)               ad-hoc jobs (pile collection, moves)
##   -99  DECONSTRUCTION_EXPORT refund materials leaving a torn-down module
##
## Needs jobs (eat/sleep/...) never touch the board - they ride the pawn's
## personal queue - so they have no band here.
##
## Aging adds at most AGE_BONUS_CAP to a job's effective priority, enough to
## surface a starved job over fresher small-band peers but never enough to
## cross the ±99 routing bands.

const CONSTRUCTION_IMPORT: int = 99
const COMPLETION_BOOST: int = 50
const TRADE_EXPORT_BIN: int = 3
const STORAGE_DEFAULT: int = 1
const DECONSTRUCTION_EXPORT: int = -99

## Effective-priority points gained per sim-second waited unclaimed:
## +1 per game-hour (30 sim-seconds), capped at +10.
const AGE_BONUS_RATE: float = 1.0 / 30.0
const AGE_BONUS_CAP: float = 10.0
