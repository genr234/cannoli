class_name QuestDriveAlignmentMethod
extends RefCounted
## How the planner scores the difference between two drive values.

enum Method { DIFFERENCE, DIFFERENCE_SQUARED }


## Returns an alignment in [0,1] for drive values that are [param difference] apart (0 to 200).
static func alignment(method: Method, difference: float) -> float:
	var ratio := difference / 200.0
	if method == Method.DIFFERENCE_SQUARED:
		return 1.0 - ratio * ratio
	return 1.0 - ratio
