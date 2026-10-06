@tool
@abstract
@icon("res://addons/juice/icons/environment.svg")
class_name JuiceEnvironmentBase
extends JuiceFeedback
## Base class of the feedbacks that change the world's [Environment] or camera attributes.
##
## The environment is found from the target: a [WorldEnvironment] or a [Camera3D] used directly,
## otherwise the current camera, the first WorldEnvironment in the tree, or the world of the
## viewport. The values are changed on that resource, so every viewer of it sees the change,
## and restoring the feedback puts all of them back. Subclasses list what to change in
## [method _get_changes] and what to switch on in [method _get_switches].

## ABSOLUTE blends from the current value toward the value. ADDITIVE adds the value to the
## current value.
enum Mode { ABSOLUTE, ADDITIVE }

const _ENVIRONMENT := &"environment"
const _ATTRIBUTES := &"attributes"

@export_group("Environment")
## How the values are used.
@export var mode: Mode = Mode.ABSOLUTE
## Seconds one play takes. 0 applies the final value at once.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.5
## The curve of the change. Null is a straight line.
@export var tween: JuiceTween
## Puts the values back to what they were at the start of the play when it ends.
@export var revert_when_finished: bool = false

var _environment: Environment
var _attributes: CameraAttributes
var _attributes_host: Object
var _attributes_property: StringName = &""
var _created_attributes := false
# "holder:property" -> value as found when bound, put back by restore
var _initial: Dictionary = {}
# "holder:property" -> value at the start of the current play
var _origin: Dictionary = {}
var _bound := false


# --- Virtual API for subclasses --------------------------------------------

## Returns the values to animate. Each entry is a dictionary with [code]holder[/code]
## ([code]&"environment"[/code] or [code]&"attributes"[/code]), [code]property[/code], [code]from[/code]
## and [code]to[/code].
func _get_changes() -> Array[Dictionary]:
	return []


## Returns values that are set once when the play starts, such as [code]glow_enabled[/code]. Each
## entry has [code]holder[/code], [code]property[/code] and [code]value[/code].
func _get_switches() -> Array[Dictionary]:
	return []


## Return true to create camera attributes when the scene has none.
func _creates_missing_attributes() -> bool:
	return false


# --- Feedback hooks ----------------------------------------------------------

func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_OTHER


func _on_initialize() -> void:
	_bind()


func _on_play(_feedback_intensity: float) -> void:
	_bind()
	if not _bound:
		return
	if not is_retrigger():
		_origin.clear()
		for entry in _get_changes():
			var holder := _holder(entry["holder"])
			if holder != null:
				_origin[_key(entry)] = holder.get(entry["property"])
	for entry in _get_switches():
		var holder := _holder(entry["holder"])
		if holder != null:
			_remember(entry, holder)
			holder.set(entry["property"], entry["value"])
	if duration <= 0.0:
		_apply(0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	if _bound:
		_apply(progress)


func _on_finished() -> void:
	if revert_when_finished and _bound:
		for entry in _get_changes():
			var holder := _holder(entry["holder"])
			var key := _key(entry)
			if holder != null and _origin.has(key):
				holder.set(entry["property"], _origin[key])


func _on_restore() -> void:
	if not _bound:
		return
	for key: String in _initial:
		var parts := key.split(":")
		var holder := _holder(StringName(parts[0]))
		if holder != null:
			holder.set(parts[1], _initial[key])
	if _created_attributes and is_instance_valid(_attributes_host):
		_attributes_host.set(_attributes_property, null)
	_created_attributes = false
	_initial.clear()
	_origin.clear()
	_bound = false
	_environment = null
	_attributes = null


# --- Internals -----------------------------------------------------------------

func _bind() -> void:
	if _bound and (_environment != null or _attributes != null):
		return
	var start := get_target()
	if start == null:
		start = player
	var found := JuiceEnvironmentFinder.find(start)
	_environment = found["environment"]
	_attributes = found["attributes"]
	_attributes_host = found["attributes_host"]
	_attributes_property = found["attributes_property"]
	if _attributes == null and _creates_missing_attributes() and _attributes_host != null:
		_attributes = CameraAttributesPractical.new()
		_attributes_host.set(_attributes_property, _attributes)
		_created_attributes = true
	_bound = _environment != null or _attributes != null
	if not _bound:
		return
	_initial.clear()
	for entry in _get_changes():
		_remember(entry)
	for entry in _get_switches():
		_remember(entry)


func _remember(entry: Dictionary, holder: Object = null) -> void:
	var key := _key(entry)
	if _initial.has(key):
		return
	var source := holder if holder != null else _holder(entry["holder"])
	if source != null:
		_initial[key] = source.get(entry["property"])


func _key(entry: Dictionary) -> String:
	return "%s:%s" % [entry["holder"], entry["property"]]


func _holder(holder_name: StringName) -> Object:
	if holder_name == _ENVIRONMENT:
		return _environment
	return _attributes


func _apply(progress: float) -> void:
	var shaped := JuiceTween.sample(tween, progress)
	var intensity := get_intensity()
	for entry in _get_changes():
		var holder := _holder(entry["holder"])
		var key := _key(entry)
		if holder == null or not _origin.has(key):
			continue
		var origin: Variant = _origin[key]
		var between: Variant = Juice.mix(entry["from"], entry["to"], shaped)
		var result: Variant
		if mode == Mode.ADDITIVE:
			result = Juice.add_values(origin, Juice.scale_value(between, intensity))
		else:
			result = Juice.mix(origin, between, intensity)
		holder.set(entry["property"], result)
