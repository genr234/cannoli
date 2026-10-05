class_name QuestCurves
extends RefCounted
## Helpers for building [Curve] resources from a list of points. Used for the
## generator's default "number of entities" curves.


## Builds a curve through [param points] (x, y) with linear interpolation. The
## domain and value range are widened to fit the points. Values outside the
## domain are clamped to the first or last point.
static func linear(points: Array[Vector2]) -> Curve:
	var curve := Curve.new()
	var max_x := 1.0
	var max_y := 1.0
	var min_y := 0.0
	for p in points:
		max_x = maxf(max_x, p.x)
		max_y = maxf(max_y, p.y)
		min_y = minf(min_y, p.y)
	curve.min_domain = 0.0
	curve.max_domain = max_x
	curve.min_value = min_y
	curve.max_value = max_y
	for p in points:
		curve.add_point(p, 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return curve


## Evaluates [param curve] at [param x], returning 0 if the curve is null or empty.
static func evaluate(curve: Curve, x: float) -> float:
	if curve == null or curve.point_count == 0:
		return 0.0
	return curve.sample(x)


## Rounds up a curve value, ignoring the tiny error that single precision adds
## when a curve is sampled exactly at one of its keys.
static func ceil_value(value: float) -> int:
	return ceili(value - 0.0001)


## The default entity-count multiplier used by urgency functions.
static func default_entity_count_multiplier() -> Curve:
	return linear([Vector2(0, 0), Vector2(1, 1), Vector2(10, 10), Vector2(50, 20)])
