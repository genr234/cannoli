@tool
@icon("res://addons/behaviors/icons/sync.svg")
class_name BehaviorSyncEntry
extends Resource
## One link between an agent variable and a node property, for [BehaviorVariableSync].

## Which way values travel.
enum Direction {
	## The variable is copied to the property.
	AGENT_TO_NODE,
	## The property is copied to the variable.
	NODE_TO_AGENT,
	## Whichever side changed since the last sync is copied to the other. The variable wins
	## on the first sync. The node wins when both changed.
	BOTH,
}

## The agent, relative to the [BehaviorVariableSync]. Empty uses the first agent among
## the sync node's siblings, or its children.
@export var agent_path: NodePath = NodePath()
## The name of the variable on the agent.
@export var variable: StringName = &""
## The node, relative to the [BehaviorVariableSync].
@export var node_path: NodePath = NodePath()
## The property of the node. A path into a property works too, such as
## [code]position:x[/code].
@export var property: NodePath = NodePath()
## Which way values travel.
@export var direction: Direction = Direction.AGENT_TO_NODE
