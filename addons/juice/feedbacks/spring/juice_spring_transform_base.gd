@tool
@abstract
class_name JuiceSpringTransformBase
extends JuiceFeedback
## The shared part of [JuicePositionSpring], [JuiceRotationSpring], [JuiceScaleSpring] and
## [JuiceSquashSpring].
##
## These feedbacks own a [JuiceSpring] and move their target with it directly, so no
## [JuiceSpringNode] is needed. The spring is driven from [method _on_tick].
##
## A spring has no natural end, but a feedback needs a duration. By default the duration
## is an estimate of how long the spring takes to settle, worked out from its damping and
## frequency, and capped by [member max_duration]. Choose FIXED to set it yourself. When
## the duration ends the spring snaps to its target, which is invisible if the estimate was
## right. Playing again while the spring still moves does not restart it: the new command
## is added to the motion that is already there.
##
## Each play that does not continue a previous one starts from the value the target has
## at that moment, so moving the node between plays works. Restoring puts the value found
## on initialization back. Reversed plays are not meaningful for a spring and are played
## forward.

## MOVE_TO sets the target to a random value between the min and max. MOVE_TO_ADDITIVE
## adds a random amount to the current value. BUMP kicks the spring with a random speed.
enum Mode { MOVE_TO, MOVE_TO_ADDITIVE, BUMP }
## AUTOMATIC estimates how long the spring needs to settle. FIXED uses [member fixed_duration].
enum DurationMode { AUTOMATIC, FIXED }
## Which of the four amounts a subclass is asked for.
enum Amount { MOVE_MIN, MOVE_MAX, BUMP_MIN, BUMP_MAX }

@export_group("Spring")
## The spring settings. Every runtime copy of this feedback uses its own clone.
@export var spring: JuiceSpring = JuiceSpring.new()
## What a play does to the spring.
@export var mode: Mode = Mode.BUMP:
	set(value):
		mode = value
		notify_property_list_changed()
## How long this feedback lasts from the point of view of the player.
@export var duration_mode: DurationMode = DurationMode.AUTOMATIC:
	set(value):
		duration_mode = value
		notify_property_list_changed()
## The longest an AUTOMATIC duration can be.
@export_range(0.05, 10.0, 0.01, "or_greater", "suffix:s") var max_duration: float = 2.0
## The duration used when [member duration_mode] is FIXED.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var fixed_duration: float = 0.5

var _spring: JuiceSpring
var _initial: Variant


# --- Subclass hooks --------------------------------------------------------

## Return true if [param node] can be animated by this feedback.
func _is_supported(_node: Node) -> bool:
	return false


## Reads the value of [param node] in the spring's type.
func _read(_node: Node) -> Variant:
	return 0.0


## Writes the spring value to [param node].
func _write(_node: Node, _value: Variant) -> void:
	pass


## The amounts exported by the subclass, in the spring's type.
func _get_amount(_which: Amount) -> Variant:
	return 0.0


## Converts an additive or bump amount before it reaches the spring, for example from
## units to pixels.
func _convert_amount(amount: Variant, _node: Node) -> Variant:
	return amount


## Called when a run starts from rest, to remember anything about the node.
func _capture(_node: Node) -> void:
	pass


## Called once per tick before the spring moves.
func _on_spring_update(_node: Node) -> void:
	pass


## Lets a subclass adjust its runtime clone of the spring, for example to add a clamp.
func _configure_spring(_clone: JuiceSpring) -> void:
	pass


# --- JuiceFeedback ---------------------------------------------------------

func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name == "fixed_duration" and duration_mode != DurationMode.FIXED:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "max_duration" and duration_mode != DurationMode.AUTOMATIC:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	if duration_mode == DurationMode.FIXED:
		return fixed_duration
	if spring == null:
		return 0.0
	return minf(spring.get_settle_time(), max_duration)


func _get_category() -> StringName:
	return Juice.CATEGORY_MOTION


func _on_initialize() -> void:
	var node := get_target()
	if not _is_supported(node):
		return
	_spring = (spring.duplicate() as JuiceSpring) if spring != null else JuiceSpring.new()
	_initial = _read(node)
	_spring.setup(_initial)
	_configure_spring(_spring)
	_capture(node)


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target()
	if _spring == null or not _is_supported(node):
		return
	if not is_retrigger():
		var start: Variant = _read(node)
		_capture(node)
		_spring.stop()
		_spring.current = start
		_spring.target = start
	var share := get_intensity()
	match mode:
		Mode.MOVE_TO:
			_spring.move_to_random(_get_amount(Amount.MOVE_MIN), _get_amount(Amount.MOVE_MAX))
		Mode.MOVE_TO_ADDITIVE:
			var amount: Variant = _random_between(_get_amount(Amount.MOVE_MIN), _get_amount(Amount.MOVE_MAX))
			_spring.move_to_additive(Juice.scale_value(_convert_amount(amount, node), share))
		Mode.BUMP:
			var kick: Variant = _random_between(_get_amount(Amount.BUMP_MIN), _get_amount(Amount.BUMP_MAX))
			_spring.bump(Juice.scale_value(_convert_amount(kick, node), share))
	if get_feedback_duration() <= 0.0:
		_spring.finish()
		_write(node, _spring.current)


func _on_tick() -> void:
	var node := get_target()
	if _spring == null or not _is_supported(node):
		return
	_on_spring_update(node)
	_spring.update(get_delta())
	_write(node, _spring.current)


func _on_finished() -> void:
	_snap()


func _on_skip_to_end() -> void:
	_snap()


func _on_stop() -> void:
	var node := get_target()
	if _spring == null or not _is_supported(node):
		return
	_spring.stop()
	_write(node, _spring.current)


func _on_restore() -> void:
	var node := get_target()
	if _spring == null or not _is_supported(node):
		return
	_spring.restore_initial()
	_write(node, _spring.current)


func _snap() -> void:
	var node := get_target()
	if _spring == null or not _is_supported(node):
		return
	_spring.finish()
	_write(node, _spring.current)


func _random_between(low: Variant, high: Variant) -> Variant:
	match typeof(low):
		TYPE_FLOAT, TYPE_INT:
			return randf_range(float(low), float(high))
		TYPE_VECTOR3:
			var a: Vector3 = low
			var b: Vector3 = high
			return Vector3(randf_range(a.x, b.x), randf_range(a.y, b.y), randf_range(a.z, b.z))
	return low
