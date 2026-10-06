@tool
@icon("res://addons/juice/icons/channel.svg")
class_name JuiceChannel
extends Resource
## A named channel that feedbacks broadcast on and shakers listen to.
##
## Plain integers work as channels too. Use a resource when you want a readable
## name instead of a number. Two channels match when they are the same resource
## or share the same file path.

## A readable name shown in the editor.
@export var display_name: String = ""


## Returns true when [param other] is the same channel as this one.
func matches(other: JuiceChannel) -> bool:
	if other == null:
		return false
	if other == self:
		return true
	return not resource_path.is_empty() and resource_path == other.resource_path
