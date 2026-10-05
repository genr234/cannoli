class_name QuestCallMethodAction
extends QuestAction
## Calls a method on scene nodes. Replaces scene-event and event-list
## actions.
##
## The target is a group name, the id of a [QuestIdentity], or a node name.
## Every matching node that has the method is called.

## Group name, [QuestIdentity] id or node name of the target.
@export var target := ""
## Optional path from the target node to the node that has the method.
@export var child_path: NodePath
## Method to call.
@export var method := ""
## Arguments for the method. Strings may contain tags such as {QUESTERID}.
@export var arguments: Array = []
## Call at the end of the frame instead of immediately.
@export var deferred := false


func get_editor_name() -> String:
	if method.is_empty():
		return "Call Method"
	return "Call Method: %s.%s()" % [target, method]


func execute() -> void:
	if target.is_empty() or method.is_empty():
		return
	var nodes := QuestSceneLookup.find_nodes(target)
	if nodes.is_empty():
		if Quests.debug:
			push_warning("Quests: QuestCallMethodAction can't find '%s'." % target)
		return
	var args: Array = []
	for argument in arguments:
		args.append(QuestTags.replace_tags(argument, quest) if argument is String else argument)
	for node in nodes:
		var receiver: Node = node
		if not child_path.is_empty():
			receiver = node.get_node_or_null(child_path)
		if receiver == null or not receiver.has_method(method):
			if Quests.debug:
				push_warning("Quests: '%s' has no method '%s'." % [node.name, method])
			continue
		if deferred:
			Callable(receiver, method).bindv(args).call_deferred()
		else:
			receiver.callv(method, args)
