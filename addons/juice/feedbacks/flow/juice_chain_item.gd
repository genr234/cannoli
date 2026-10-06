@tool
class_name JuiceChainItem
extends Resource
## One step of a [JuiceChain]: a player to play, with delays around it.

## The player to play. Path is relative to the player of the chain feedback.
@export var player: NodePath
## Seconds to wait before playing it.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var delay_before: float = 0.0
## Seconds to wait after it, before the next step.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var delay_after: float = 0.0
## Waits until the player has ended before going on. Off starts the next step at once.
@export var wait_until_complete: bool = true
## Skips this step.
@export var inactive: bool = false
