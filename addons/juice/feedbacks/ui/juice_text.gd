@tool
@icon("res://addons/juice/icons/text.svg")
class_name JuiceText
extends JuiceFeedback
## Changes the text of a node, either at once or by counting a number up or down.
##
## It works on anything with a [code]text[/code] property: Label, RichTextLabel, Label3D,
## Button, LineEdit and so on. In COUNT mode the number runs from [member from_value] to
## [member to_value] and is written with [member format], a format string with one
## placeholder such as [code]%d[/code], [code]%.1f[/code] or [code]Score: %d[/code].
## The text is put back on restore. Intensity does not change text.

## SET_TEXT writes [member text]. COUNT animates a number.
enum Mode { SET_TEXT, COUNT }

@export_group("Text")
## What to do to the text.
@export var mode: Mode = Mode.SET_TEXT:
	set(value):
		mode = value
		notify_property_list_changed()
## The text to write, for SET_TEXT.
@export_multiline var text: String = "Hello"
## The number at the start, for COUNT.
@export var from_value: float = 0.0
## The number at the end, for COUNT.
@export var to_value: float = 100.0
## The format used to write the number. One placeholder, like %d or %.2f.
@export var format: String = "%d"
## Rounds the number down to a whole number before formatting. Needed for %d style counters.
@export var floor_values: bool = true
## A character put between thousands in the first number of the text, such as a comma. Empty for none.
@export var thousands_separator: String = ""
## Seconds the count takes.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var duration: float = 1.0
## The curve of the count. Null is a straight line.
@export var tween: JuiceTween
## The least time in seconds between two text updates. 0 updates every frame.
@export_range(0.0, 1.0, 0.01, "suffix:s") var min_refresh_interval: float = 0.0

var _initial := ""
var _last_update_msec := 0


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name == "text" and mode != Mode.SET_TEXT:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["from_value", "to_value", "format", "floor_values", "thousands_separator", "duration", "tween", "min_refresh_interval"] and mode != Mode.COUNT:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return duration if mode == Mode.COUNT else 0.0


func _get_category() -> StringName:
	return Juice.CATEGORY_OTHER


func _has_target() -> bool:
	return true


func _on_initialize() -> void:
	var node := get_target()
	if _is_supported(node):
		_initial = node.get("text")


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target()
	if not _is_supported(node):
		return
	_last_update_msec = 0
	if mode == Mode.SET_TEXT:
		node.set("text", text)
	elif duration <= 0.0:
		_write_count(node, 0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	var node := get_target()
	if not _is_supported(node) or mode != Mode.COUNT:
		return
	# The first and last frames always update, so the count never stops short.
	var now := Time.get_ticks_msec()
	var final_frame := progress <= 0.0 or progress >= 1.0
	if not final_frame and min_refresh_interval > 0.0 and now - _last_update_msec < int(min_refresh_interval * 1000.0):
		return
	_last_update_msec = now
	_write_count(node, progress)


func _on_restore() -> void:
	var node := get_target()
	if _is_supported(node):
		node.set("text", _initial)


func _write_count(node: Node, progress: float) -> void:
	var value := lerpf(from_value, to_value, JuiceTween.sample(tween, progress))
	node.set("text", format_value(value))


## Formats [param value] the way this feedback writes its count.
func format_value(value: float) -> String:
	var result: String
	if not "%" in format:
		result = format
	elif floor_values:
		result = format % floori(value)
	else:
		result = format % value
	if thousands_separator != "":
		result = _separate_thousands(result)
	return result


func _separate_thousands(source: String) -> String:
	var regex := RegEx.create_from_string("\\d+")
	var found := regex.search(source)
	if found == null:
		return source
	var digits := found.get_string()
	var grouped := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			grouped = thousands_separator + grouped
		grouped = digits[i] + grouped
		count += 1
	return source.substr(0, found.get_start()) + grouped + source.substr(found.get_end())


func _is_supported(node: Node) -> bool:
	return node != null and "text" in node
