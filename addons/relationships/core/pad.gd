@tool
class_name Pad
extends Resource
## An emotional state based on the PAD (pleasure, arousal, dominance) model:
## https://en.wikipedia.org/wiki/PAD_emotional_state_model

## A temperament is a broad label for the current PAD values. The values are
## bit flags, so several can be combined into a mask.
enum Temperament {
	EXUBERANT = 1, ## P+ A+ D+
	BORED = 2, ## P- A- D-
	DEPENDENT = 4, ## P+ A+ D-
	DISDAINFUL = 8, ## P- A- D+
	RELAXED = 16, ## P+ A- D+
	ANXIOUS = 32, ## P- A+ D-
	DOCILE = 64, ## P+ A- D-
	HOSTILE = 128, ## P- A+ D+
	NEUTRAL = 256, ## All near zero.
}

## A mask that matches every temperament.
const ALL_TEMPERAMENTS := 511
## For [annotation @GDScript.@export_flags] hints, in flag order.
const TEMPERAMENT_FLAGS_HINT := "Exuberant,Bored,Dependent,Disdainful,Relaxed,Anxious,Docile,Hostile,Neutral"

## The sum of all pleasure over the member's lifetime.
@export_range(-100, 100) var happiness := 0.0
## How happy or sad the member currently is.
@export_range(-100, 100) var pleasure := 0.0
## How worked up or excited the member currently is.
@export_range(-100, 100) var arousal := 0.0
## How dominant or submissive the member feels in the current situation.
@export_range(-100, 100) var dominance := 0.0
## PAD values must be beyond this to count toward a temperament.
@export_range(0, 100) var excitability_threshold := 20.0


## Adds the changes, clamping each value to [-100, 100].
func modify(happiness_change: float, pleasure_change: float, arousal_change: float, dominance_change: float) -> void:
	happiness = clampf(happiness + happiness_change, -100.0, 100.0)
	pleasure = clampf(pleasure + pleasure_change, -100.0, 100.0)
	arousal = clampf(arousal + arousal_change, -100.0, 100.0)
	dominance = clampf(dominance + dominance_change, -100.0, 100.0)


func reset() -> void:
	happiness = 0.0
	pleasure = 0.0
	arousal = 0.0
	dominance = 0.0


## Returns the [enum Temperament] that matches the current PAD values.
func get_temperament() -> Temperament:
	var happy := pleasure > excitability_threshold
	var unhappy := pleasure < -excitability_threshold
	var aroused := arousal > excitability_threshold
	var lulled := arousal < -excitability_threshold
	var dominant := dominance > excitability_threshold
	var submissive := dominance < -excitability_threshold
	if happy and aroused and not submissive:
		return Temperament.EXUBERANT
	if happy and aroused and submissive:
		return Temperament.DEPENDENT
	if happy and lulled and submissive:
		return Temperament.DOCILE
	if happy and lulled and not submissive:
		return Temperament.RELAXED
	if unhappy and aroused and dominant:
		return Temperament.HOSTILE
	if unhappy and aroused:
		return Temperament.ANXIOUS
	if unhappy and lulled and dominant:
		return Temperament.DISDAINFUL
	if unhappy and lulled and not dominant:
		return Temperament.BORED
	return Temperament.NEUTRAL


## Whether the current temperament is in [param mask], a combination of
## [enum Temperament] flags.
func matches_temperament(mask: int) -> bool:
	return (mask & get_temperament()) != 0
