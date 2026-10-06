@tool
@icon("res://addons/juice/icons/haptics.svg")
class_name JuiceHapticStep
extends Resource
## One piece of a [JuiceHapticPattern]: a stretch of time with a constant vibration strength.
##
## Gamepads have two motors. The strong one is a slow, heavy rumble and the weak one a light,
## high buzz. Phones have one motor, so they use the larger of the two.

## How long this step lasts in seconds.
@export_range(0.0, 5.0, 0.005, "or_greater", "suffix:s") var duration: float = 0.05
## Strength of the light buzz motor, from 0 (off) to 1.
@export_range(0.0, 1.0, 0.01) var weak: float = 0.0
## Strength of the heavy rumble motor, from 0 (off) to 1.
@export_range(0.0, 1.0, 0.01) var strong: float = 0.0


## Returns the vibration strength a phone should use: the larger of both motors.
func get_amplitude() -> float:
	return maxf(weak, strong)


## Returns true when both motors are off, so the step is a pause.
func is_silent() -> bool:
	return weak <= 0.0 and strong <= 0.0


## Makes a step in code.
static func make(step_duration: float, weak_strength: float, strong_strength: float) -> JuiceHapticStep:
	var step := JuiceHapticStep.new()
	step.duration = step_duration
	step.weak = weak_strength
	step.strong = strong_strength
	return step
