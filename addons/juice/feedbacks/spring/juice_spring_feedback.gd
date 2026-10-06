@tool
@icon("res://addons/juice/icons/spring.svg")
class_name JuiceSpringFeedback
extends JuiceFeedback
## Sends a command to a [JuiceSpringNode]: move, bump, stop, restore and so on.
##
## Set [member target_spring] to drive one spring directly. Leave it empty to broadcast on
## the channel, so every [JuiceSpringNode] listening on it reacts (use the spring's id to
## narrow that down). The values below can be a float, Vector2, Vector3, Vector4 or Color;
## they are converted to the type of the spring that receives them.
##
## The spring is open ended, so the duration of this feedback is only what you declare in
## [member declared_duration]. It lets holding pauses wait for the spring to calm down.
##
## Intensity multiplies bump and additive or subtractive amounts. MOVE_TO and random
## targets are absolute values and are not scaled.

## The event name sent on the bus.
const EVENT := JuiceSpringNode.EVENT

@export_group("Spring")
## The spring to command. Empty: broadcast on the channel.
@export var target_spring: NodePath
## An id that narrows a broadcast. Only springs with this id (or any, when empty) react.
@export var spring_id: StringName = &""
## Seconds this feedback lasts for the player. The spring itself is not limited by it.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var declared_duration: float = 0.0
## What to tell the spring.
@export var command: JuiceSpring.Command = JuiceSpring.Command.BUMP:
	set(value):
		command = value
		notify_property_list_changed()
## The value for MOVE_TO, MOVE_TO_ADDITIVE, MOVE_TO_SUBTRACTIVE and MOVE_TO_INSTANT.
@export var move_to_value: Variant = 2.0
## The speed added by BUMP.
@export var bump_amount: Variant = 75.0
## The lowest value for MOVE_TO_RANDOM.
@export var move_to_random_min: Variant = -2.0
## The highest value for MOVE_TO_RANDOM.
@export var move_to_random_max: Variant = 2.0
## The lowest speed for BUMP_RANDOM.
@export var bump_random_min: Variant = -20.0
## The highest speed for BUMP_RANDOM.
@export var bump_random_max: Variant = 20.0

@export_group("Overrides")
## Changes the damping of the spring before the command.
@export var override_damping: bool = false:
	set(value):
		override_damping = value
		notify_property_list_changed()
## The new damping. A vector sets each axis separately.
@export var new_damping: Variant = 0.8
## Changes the frequency of the spring before the command.
@export var override_frequency: bool = false:
	set(value):
		override_frequency = value
		notify_property_list_changed()
## The new frequency. A vector sets each axis separately.
@export var new_frequency: Variant = 5.0


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name == "move_to_value" and command not in [JuiceSpring.Command.MOVE_TO, JuiceSpring.Command.MOVE_TO_ADDITIVE, JuiceSpring.Command.MOVE_TO_SUBTRACTIVE, JuiceSpring.Command.MOVE_TO_INSTANT]:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "bump_amount" and command != JuiceSpring.Command.BUMP:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["move_to_random_min", "move_to_random_max"] and command != JuiceSpring.Command.MOVE_TO_RANDOM:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["bump_random_min", "bump_random_max"] and command != JuiceSpring.Command.BUMP_RANDOM:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "new_damping" and not override_damping:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "new_frequency" and not override_frequency:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return declared_duration


func _get_category() -> StringName:
	return Juice.CATEGORY_MOTION


func _has_channel() -> bool:
	return target_spring.is_empty()


func _has_target() -> bool:
	return false


func _get_display_label() -> String:
	return "Spring"


func _on_play(_feedback_intensity: float) -> void:
	var share := get_intensity()
	var payload: Dictionary = {
		"command": command,
		"value": move_to_value,
		"bump": bump_amount,
		"min": move_to_random_min,
		"max": move_to_random_max,
		"bump_min": bump_random_min,
		"bump_max": bump_random_max,
		"override_damping": override_damping,
		"damping": new_damping,
		"override_frequency": override_frequency,
		"frequency": new_frequency,
		"id": spring_id,
	}
	if command in [JuiceSpring.Command.MOVE_TO_ADDITIVE, JuiceSpring.Command.MOVE_TO_SUBTRACTIVE]:
		payload["value"] = Juice.scale_value(move_to_value, share)
	elif command == JuiceSpring.Command.BUMP:
		payload["bump"] = Juice.scale_value(bump_amount, share)
	elif command == JuiceSpring.Command.BUMP_RANDOM:
		payload["bump_min"] = Juice.scale_value(bump_random_min, share)
		payload["bump_max"] = Juice.scale_value(bump_random_max, share)
	_send(payload)


func _on_stop() -> void:
	_send({"command": JuiceSpring.Command.STOP, "id": spring_id})


func _on_restore() -> void:
	_send({"command": JuiceSpring.Command.RESTORE, "id": spring_id})


# Direct target when one is set, the channel otherwise.
func _send(payload: Dictionary) -> void:
	if not target_spring.is_empty():
		var node := resolve(target_spring) as JuiceSpringNode
		if node != null:
			node.apply_command(payload)
		return
	broadcast(EVENT, payload)
