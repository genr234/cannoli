@tool
class_name JuiceBlinkPhase
extends Resource
## One stretch of a [JuiceBlink]: a number of on and off cycles with their own timing.

## Seconds of the on state in each cycle.
@export_range(0.0, 5.0, 0.01, "or_greater", "suffix:s") var on_duration: float = 0.1
## Seconds of the off state in each cycle.
@export_range(0.0, 5.0, 0.01, "or_greater", "suffix:s") var off_duration: float = 0.1
## How many on and off cycles this phase lasts.
@export_range(1, 100, 1, "or_greater") var cycles: int = 3


## The seconds this phase takes.
func get_duration() -> float:
	return (on_duration + off_duration) * cycles
