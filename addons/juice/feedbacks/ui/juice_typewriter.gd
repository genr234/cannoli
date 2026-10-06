@tool
@icon("res://addons/juice/icons/text.svg")
class_name JuiceTypewriter
extends JuiceFeedback
## Reveals text bit by bit, like a typewriter or a dialogue box.
##
## It works on Label and RichTextLabel (through visible characters) and on Label3D (by
## cutting the text). The text can be replaced first with [member new_text]. Text can appear a
## character, a word or a line at a time, with a fixed time per step or a fixed total time.
## Reversed plays hide the text again. The text is put back on restore.
##
## When the duration is based on the step time, it is worked out from the text the target
## had when the player was initialized (or from [member new_text]).

## What counts as one step of the reveal.
enum RevealMode { CHARACTER, WORD, LINE }
## STEP_INTERVAL uses [member interval] seconds per step. TOTAL_DURATION spreads the
## reveal over [member total_duration] seconds.
enum DurationMode { STEP_INTERVAL, TOTAL_DURATION }

@export_group("Typewriter")
## What counts as one step of the reveal.
@export var reveal_mode: RevealMode = RevealMode.CHARACTER
## How the length of the reveal is decided.
@export var duration_mode: DurationMode = DurationMode.STEP_INTERVAL:
	set(value):
		duration_mode = value
		notify_property_list_changed()
## Seconds per step, for STEP_INTERVAL.
@export_range(0.001, 5.0, 0.001, "or_greater", "suffix:s") var interval: float = 0.04
## Seconds the whole reveal takes, for TOTAL_DURATION.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var total_duration: float = 1.0
## The curve of the reveal. Null is a straight line.
@export var tween: JuiceTween
## Hides all the text when the player initializes, so it does not show before the reveal.
@export var hide_on_initialize: bool = false

@export_group("Text")
## Replaces the text of the target before revealing.
@export var set_text: bool = false:
	set(value):
		set_text = value
		notify_property_list_changed()
## The new text. For a RichTextLabel with BBCode enabled, tags are allowed.
@export_multiline var new_text: String = ""

var _initial_text := ""
var _initial_visible := -1
var _units := 0
var _cuts := PackedInt32Array()
var _full := ""


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name == "interval" and duration_mode != DurationMode.STEP_INTERVAL:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "total_duration" and duration_mode != DurationMode.TOTAL_DURATION:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "new_text" and not set_text:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	if duration_mode == DurationMode.TOTAL_DURATION:
		return total_duration
	return interval * float(_units if _units > 0 else _estimate_units())


func _get_category() -> StringName:
	return Juice.CATEGORY_OTHER


func _has_target() -> bool:
	return true


func _on_initialize() -> void:
	var node := get_target()
	if not _is_supported(node):
		return
	_initial_text = _read_text(node)
	if node is Label or node is RichTextLabel:
		_initial_visible = node.visible_characters
	_prepare_text(node, false)
	if set_text:
		_units = _estimate_units()
	if hide_on_initialize:
		_show_chars(node, 0)


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target()
	if not _is_supported(node):
		return
	_prepare_text(node, set_text)
	if _get_duration() <= 0.0:
		_apply(node, 0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	var node := get_target()
	if _is_supported(node):
		_apply(node, progress)


func _on_restore() -> void:
	var node := get_target()
	if not _is_supported(node):
		return
	_write_text(node, _initial_text)
	if node is Label or node is RichTextLabel:
		node.visible_characters = _initial_visible


func _apply(node: Node, progress: float) -> void:
	if _units <= 0:
		return
	var shaped := clampf(JuiceTween.sample(tween, progress), 0.0, 1.0)
	var steps := clampi(floori(shaped * _units + 0.0001), 0, _units)
	if steps >= _units:
		_show_chars(node, -1)
	else:
		_show_chars(node, 0 if steps == 0 else _cuts[steps - 1])


# Sets the text if asked and works out where each step ends.
func _prepare_text(node: Node, replace: bool) -> void:
	if replace:
		_write_text(node, new_text)
	_full = _plain_text(node)
	_cuts = _compute_cuts(_full)
	_units = _cuts.size()


func _show_chars(node: Node, count: int) -> void:
	if node is Label or node is RichTextLabel:
		node.visible_characters = count
	elif node is Label3D:
		node.text = _full if count < 0 else _full.substr(0, count)


func _is_supported(node: Node) -> bool:
	return node is Label or node is RichTextLabel or node is Label3D


func _read_text(node: Node) -> String:
	return node.text


func _write_text(node: Node, value: String) -> void:
	node.text = value


# The text as shown, without BBCode tags.
func _plain_text(node: Node) -> String:
	if node is RichTextLabel:
		return node.get_parsed_text()
	return node.text


func _compute_cuts(text: String) -> PackedInt32Array:
	var cuts := PackedInt32Array()
	var length := text.length()
	match reveal_mode:
		RevealMode.CHARACTER:
			for i in length:
				cuts.append(i + 1)
		RevealMode.WORD:
			var i := 0
			while i < length:
				while i < length and _is_space(text[i]):
					i += 1
				if i >= length:
					break
				while i < length and not _is_space(text[i]):
					i += 1
				cuts.append(i)
		RevealMode.LINE:
			var start := 0
			while start < length:
				var end := text.find("\n", start)
				if end < 0:
					cuts.append(length)
					break
				cuts.append(end)
				start = end + 1
	return cuts


func _is_space(character: String) -> bool:
	return character == " " or character == "\n" or character == "\t"


# Used before the player has run: counts steps in the new text or in the target's text.
func _estimate_units() -> int:
	var text := new_text
	if not set_text:
		var node := get_target() if player != null else null
		if not _is_supported(node):
			return 1
		text = _plain_text(node)
	elif _bbcode_possible():
		var regex := RegEx.create_from_string("\\[[^\\]]*\\]")
		text = regex.sub(text, "", true)
	return maxi(_compute_cuts(text).size(), 1)


func _bbcode_possible() -> bool:
	var node := get_target() if player != null else null
	return node == null or node is RichTextLabel
