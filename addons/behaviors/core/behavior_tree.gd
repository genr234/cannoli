@tool
@icon("res://addons/behaviors/icons/tree.svg")
class_name BehaviorTree
extends Resource
## A behavior tree: a root task, its descendants, and the variables they share.
##
## Edit trees in the Behaviors main screen and run them with a [BehaviorAgent]. The
## same file can run on many agents, and inside other trees through
## [BehaviorSubtree].

## What the tree does. Shown in the editor.
@export_multiline var description: String = ""
## The variables the tasks share. Each agent gets its own copy.
@export var variables: Array[BehaviorVariable] = []
## The first task to run.
@export_storage var root: BehaviorTask
## Tasks in the editor that are not connected to the root. They never run.
@export_storage var detached: Array[BehaviorTask] = []
## Editor-only data: the entry position, comment frames, watched properties.
@export_storage var editor_data: Dictionary = {}


## A copy of the tasks for one run: every task reachable from the root is duplicated,
## and references between tasks point to the copies.
func instantiate() -> BehaviorTask:
	return clone_tasks(root)


## The variable with [param variable_name], or null.
func get_variable(variable_name: StringName) -> BehaviorVariable:
	for variable in variables:
		if variable and variable.name == variable_name:
			return variable
	return null


## Every task reachable from the root, the root first. With [param include_detached],
## adds the detached tasks and their descendants.
func get_tasks(include_detached: bool = false) -> Array[BehaviorTask]:
	var tasks: Array[BehaviorTask] = []
	var seen := {}
	_collect(root, tasks, seen)
	if include_detached:
		for task in detached:
			_collect(task, tasks, seen)
	return tasks


## The task with [param task_id], or null.
func find_task_by_id(task_id: int) -> BehaviorTask:
	for task in get_tasks(true):
		if task.id == task_id:
			return task
	return null


## Gives every task without an id a new one that is unique in this tree. Returns true
## when an id was assigned.
func ensure_ids() -> bool:
	var tasks := get_tasks(true)
	var owners := {}
	var changed := false
	var next_id := 1
	for task in tasks:
		if task.id > 0 and not owners.has(task.id):
			owners[task.id] = task
			next_id = maxi(next_id, task.id + 1)
	for task in tasks:
		if task.id <= 0 or owners[task.id] != task:
			task.id = next_id
			owners[next_id] = task
			next_id += 1
			changed = true
	return changed


## Every problem found in the tree, as dictionaries with [code]task[/code] (or null)
## and [code]message[/code].
func validate() -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if root == null:
		issues.append({"task": null, "message": "The tree has no root task."})
	for task in get_tasks():
		for message in task.get_warnings():
			issues.append({"task": task, "message": message})
	var names := {}
	for variable in variables:
		if variable == null:
			continue
		if String(variable.name).is_empty():
			issues.append({"task": null, "message": "A variable has no name."})
		elif names.has(variable.name):
			issues.append({"task": null, "message": "Two variables are named \"%s\"." % variable.name})
		names[variable.name] = true
	return issues


## Duplicates [param source] and every task it reaches, keeping references between
## them. Other resources (curves, considerations) are shared.
static func clone_tasks(source: BehaviorTask) -> BehaviorTask:
	if source == null:
		return null
	var originals: Array[BehaviorTask] = []
	_collect(source, originals, {})
	var copies := {}
	for original in originals:
		copies[original] = original.duplicate(false)
	for original in originals:
		var copy: BehaviorTask = copies[original]
		for property in _task_properties(original):
			copy.set(property, _remap(original.get(property), copies))
	return copies[source]


static func _collect(task: BehaviorTask, into: Array[BehaviorTask], seen: Dictionary) -> void:
	if task == null or seen.has(task):
		return
	seen[task] = true
	into.append(task)
	for property in _task_properties(task):
		var value: Variant = task.get(property)
		if value is BehaviorTask:
			_collect(value, into, seen)
		elif value is Array:
			for item in value:
				if item is BehaviorTask:
					_collect(item, into, seen)


# Stored properties that can hold tasks, plus arrays and dictionaries, which must not
# be shared between copies.
static func _task_properties(task: BehaviorTask) -> Array[StringName]:
	var properties: Array[StringName] = []
	for info in task.get_property_list():
		if not (info.usage & PROPERTY_USAGE_STORAGE):
			continue
		var type: int = info.type
		if type == TYPE_ARRAY or type == TYPE_DICTIONARY:
			properties.append(info.name)
		elif type == TYPE_OBJECT and task.get(info.name) is BehaviorTask:
			properties.append(info.name)
	return properties


static func _remap(value: Variant, copies: Dictionary) -> Variant:
	if value is BehaviorTask:
		return copies.get(value, value)
	if value is Array:
		var array: Array = value.duplicate()
		for index in array.size():
			if array[index] is BehaviorTask:
				array[index] = copies.get(array[index], array[index])
		return array
	if value is Dictionary:
		return value.duplicate()
	return value
