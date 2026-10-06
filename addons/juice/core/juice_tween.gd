@tool
@icon("res://addons/juice/icons/tween.svg")
class_name JuiceTween
extends Resource
## An easing curve. It turns a progress from 0 to 1 into a shaped value.
##
## Three sources are available. A preset is one of the built-in shapes, including
## the overshooting and elastic ones. A Godot tween uses a transition and an ease from
## [Tween]. A custom curve samples a [Curve] resource. Always go through
## [method evaluate], or [method sample] when the tween may be null.

## Which source [method evaluate] reads.
enum Mode { PRESET, GODOT, CURVE }

## The built-in shapes. Each family has an in, an out and an in-out form.
## ANTI_LINEAR runs from 1 down to 0. ALMOST_IDENTITY is a soft start that ends on 1.
enum Preset {
	LINEAR,
	EASE_IN_QUADRATIC, EASE_OUT_QUADRATIC, EASE_IN_OUT_QUADRATIC,
	EASE_IN_CUBIC, EASE_OUT_CUBIC, EASE_IN_OUT_CUBIC,
	EASE_IN_QUARTIC, EASE_OUT_QUARTIC, EASE_IN_OUT_QUARTIC,
	EASE_IN_QUINTIC, EASE_OUT_QUINTIC, EASE_IN_OUT_QUINTIC,
	EASE_IN_SINUSOIDAL, EASE_OUT_SINUSOIDAL, EASE_IN_OUT_SINUSOIDAL,
	EASE_IN_BOUNCE, EASE_OUT_BOUNCE, EASE_IN_OUT_BOUNCE,
	EASE_IN_OVERHEAD, EASE_OUT_OVERHEAD, EASE_IN_OUT_OVERHEAD,
	EASE_IN_EXPONENTIAL, EASE_OUT_EXPONENTIAL, EASE_IN_OUT_EXPONENTIAL,
	EASE_IN_ELASTIC, EASE_OUT_ELASTIC, EASE_IN_OUT_ELASTIC,
	EASE_IN_CIRCULAR, EASE_OUT_CIRCULAR, EASE_IN_OUT_CIRCULAR,
	ANTI_LINEAR,
	ALMOST_IDENTITY,
}

const _FAMILY_COUNT := 10

@export var mode: Mode = Mode.PRESET:
	set(value):
		mode = value
		notify_property_list_changed()
		emit_changed()
## The built-in shape, used when [member mode] is PRESET.
@export var preset: Preset = Preset.LINEAR:
	set(value):
		preset = value
		emit_changed()
## The transition, used when [member mode] is GODOT.
@export var transition: Tween.TransitionType = Tween.TRANS_SINE:
	set(value):
		transition = value
		emit_changed()
## The ease, used when [member mode] is GODOT.
@export var easing: Tween.EaseType = Tween.EASE_OUT:
	set(value):
		easing = value
		emit_changed()
## The curve, used when [member mode] is CURVE. It is sampled over 0..1.
## A missing curve acts as a straight line.
@export var curve: Curve:
	set(value):
		curve = value
		emit_changed()


func _validate_property(property: Dictionary) -> void:
	var prop_name: String = property.name
	if prop_name == "preset" and mode != Mode.PRESET:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif (prop_name == "transition" or prop_name == "easing") and mode != Mode.GODOT:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "curve" and mode != Mode.CURVE:
		property.usage &= ~PROPERTY_USAGE_EDITOR


## Shapes [param t], a progress from 0 to 1. Values outside 0..1 are not clamped
## for presets, so overshooting shapes stay accurate.
func evaluate(t: float) -> float:
	match mode:
		Mode.GODOT:
			return Tween.interpolate_value(0.0, 1.0, clampf(t, 0.0, 1.0), 1.0, transition, easing)
		Mode.CURVE:
			if curve == null:
				return t
			return curve.sample(t)
	return evaluate_preset(preset, t)


## Evaluates [param tween], or a straight line when it is null.
static func sample(tween: JuiceTween, t: float) -> float:
	if tween == null:
		return t
	return tween.evaluate(t)


## Evaluates a built-in shape without creating a resource.
static func evaluate_preset(preset_id: Preset, t: float) -> float:
	if preset_id == Preset.LINEAR:
		return t
	if preset_id == Preset.ANTI_LINEAR:
		return 1.0 - t
	if preset_id == Preset.ALMOST_IDENTITY:
		return t * t * (2.0 - t)
	var index := int(preset_id) - 1
	var family := floori(index / 3.0)
	if family >= _FAMILY_COUNT:
		return t
	match index % 3:
		0:
			return _ease_in(family, t)
		1:
			return 1.0 - _ease_in(family, 1.0 - t)
	if t < 0.5:
		return _ease_in(family, t * 2.0) * 0.5
	return 1.0 - _ease_in(family, (1.0 - t) * 2.0) * 0.5


# Families, in enum order: quadratic, cubic, quartic, quintic, sinusoidal, bounce,
# overhead, exponential, elastic, circular.
static func _ease_in(family: int, t: float) -> float:
	match family:
		0:
			return t * t
		1:
			return t * t * t
		2:
			return pow(t, 4.0)
		3:
			return pow(t, 5.0)
		4:
			return 1.0 + sin(PI * 0.5 * t - PI * 0.5)
		5:
			var period := 0.3
			return pow(2.0, -10.0 * t) * sin((t - period * 0.25) * TAU / period) + 1.0
		6:
			var back := 1.6
			return t * t * ((back + 1.0) * t - back)
		7:
			return 0.0 if t == 0.0 else pow(1024.0, t - 1.0)
		8:
			if t == 0.0:
				return 0.0
			if t == 1.0:
				return 1.0
			var shifted := t - 1.0
			return -pow(2.0, 10.0 * shifted) * sin((shifted - 0.1) * TAU / 0.4)
	return 1.0 - sqrt(maxf(0.0, 1.0 - t * t))


## A resource for a built-in shape.
static func make_preset(preset_id: Preset) -> JuiceTween:
	var tween := JuiceTween.new()
	tween.mode = Mode.PRESET
	tween.preset = preset_id
	return tween


## A resource that uses a Godot transition and ease.
static func make_godot(trans: Tween.TransitionType, ease_type: Tween.EaseType) -> JuiceTween:
	var tween := JuiceTween.new()
	tween.mode = Mode.GODOT
	tween.transition = trans
	tween.easing = ease_type
	return tween


## A resource that samples a custom curve.
static func make_curve(source: Curve) -> JuiceTween:
	var tween := JuiceTween.new()
	tween.mode = Mode.CURVE
	tween.curve = source
	return tween


## A straight line from 0 to 1.
static func make_linear() -> JuiceTween:
	return make_preset(Preset.LINEAR)


## A smooth start, a cubic ease in.
static func make_ease_in() -> JuiceTween:
	return make_preset(Preset.EASE_IN_CUBIC)


## A smooth stop, a cubic ease out.
static func make_ease_out() -> JuiceTween:
	return make_preset(Preset.EASE_OUT_CUBIC)


## A smooth start and stop, a cubic ease in and out.
static func make_ease_in_out() -> JuiceTween:
	return make_preset(Preset.EASE_IN_OUT_CUBIC)


## Rises to 1 and comes back to 0, a triangle that peaks halfway.
static func make_there_and_back() -> JuiceTween:
	var shape := Curve.new()
	shape.add_point(Vector2(0.0, 0.0), 0.0, 0.0, Curve.TANGENT_LINEAR)
	shape.add_point(Vector2(0.5, 1.0), 0.0, 0.0, Curve.TANGENT_LINEAR)
	shape.add_point(Vector2(1.0, 0.0), 0.0, 0.0, Curve.TANGENT_LINEAR)
	for i in shape.point_count:
		shape.set_point_left_mode(i, Curve.TANGENT_LINEAR)
		shape.set_point_right_mode(i, Curve.TANGENT_LINEAR)
	return make_curve(shape)
