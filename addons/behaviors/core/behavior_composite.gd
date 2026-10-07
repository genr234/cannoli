@tool
@abstract
@icon("res://addons/behaviors/icons/composite.svg")
class_name BehaviorComposite
extends BehaviorParent
## A parent with any number of children, such as a sequence or a selector.
##
## [b]Conditional aborts.[/b] A composite can keep checking conditions that already ran
## while a later task is running, and interrupt it when a result changes:
## [br]- [constant AbortType.SELF]: conditions among this composite's own children
## interrupt the child that is running now.
## [br]- [constant AbortType.LOWER_PRIORITY]: this composite's conditions keep being
## checked after it ended, while tasks to its right run, and interrupt them.
## [br]- [constant AbortType.BOTH]: both of the above.
## [br][br]
## When an abort happens, the composite that owns the interrupted branch restarts at
## the child holding the condition.

## When conditions that already ran are checked again.
enum AbortType {
	## Never.
	NONE,
	## While a later child of this composite runs.
	SELF,
	## While a task to the right of this composite runs.
	LOWER_PRIORITY,
	## Both.
	BOTH,
}

## Which running tasks the conditions of this composite can interrupt.
@export var abort_type: AbortType = AbortType.NONE

# For each child, the tasks to check again while a later child runs.
var _observers: Array[Array] = []


func _start() -> void:
	if _observers.size() != children.size():
		_build_observers()
	for list in _observers:
		for task: BehaviorTask in list:
			task._observed = Status.INACTIVE
	super()


func _execute(delta: float) -> Status:
	if _running_child > 0 and not can_run_parallel_children():
		_check_aborts(delta)
	return super(delta)


# Runs the observed conditions left of the running child. On a change, interrupts the
# running child and restarts at the child that holds the condition.
func _check_aborts(delta: float) -> bool:
	if _observers.size() != children.size():
		_build_observers()
	for index in _running_child:
		for task: BehaviorTask in _observers[index]:
			if task._reevaluate(delta):
				var running := _running_child
				if children[running]:
					children[running].abort()
				_running_child = -1
				if agent:
					agent._task_aborted_by(task, children[running])
				_on_conditional_abort(index)
				return true
	return false


func _build_observers() -> void:
	_observers.clear()
	var self_abort := abort_type == AbortType.SELF or abort_type == AbortType.BOTH
	for child in children:
		var list: Array[BehaviorTask] = []
		if self_abort:
			_collect_direct(child, list)
		_collect_lower_priority(child, list)
		_observers.append(list)


func _observes_lower_priority() -> bool:
	return abort_type == AbortType.LOWER_PRIORITY or abort_type == AbortType.BOTH


# Conditions that are this child, or under a chain of decorators.
static func _collect_direct(task: BehaviorTask, list: Array[BehaviorTask]) -> void:
	if task == null or task.disabled:
		return
	if task is BehaviorCondition:
		list.append(task)
	elif task is BehaviorDecorator and not task._observes_lower_priority():
		_collect_direct((task as BehaviorDecorator).get_child(), list)


# Conditions of composites inside this child that abort lower priority tasks, and
# decorators that do the same.
static func _collect_lower_priority(task: BehaviorTask, list: Array[BehaviorTask]) -> void:
	if task == null or task.disabled:
		return
	if task is BehaviorDecorator:
		if task._observes_lower_priority():
			list.append(task)
		else:
			_collect_lower_priority((task as BehaviorDecorator).get_child(), list)
	elif task is BehaviorComposite:
		if task._observes_lower_priority():
			for child in (task as BehaviorComposite).children:
				_collect_direct(child, list)
		for child in (task as BehaviorComposite).children:
			_collect_lower_priority(child, list)
