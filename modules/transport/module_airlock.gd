@tool
class_name AirlockModule
extends ModuleBase

## No behaviour of its own any more. The truss it used to lay under its inner cell
## in on_place() is one rule on ModuleBase now (see ModuleBase.backfill_points),
## shared with the corridor, the stairs and the turbolift - and read by the build
## preview, which has to know what a module will leave behind before it exists.
## Kept as the identity the two airlock scenes attach.
