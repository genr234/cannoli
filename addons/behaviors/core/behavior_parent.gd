@tool
@abstract
@icon("res://addons/behaviors/icons/composite.svg")
class_name BehaviorParent
extends BehaviorTask
## A task with children: the base of [BehaviorComposite] and [BehaviorDecorator].
##
## The default run loop asks the hooks below which child to run next, ticks it, and
## reports the result back. Sequential parents run one child at a time. Parallel
## parents ([method can_run_parallel_children]) start every child they can and tick
## them all, then [method override_status] decides when they are done.

## The children, run from first to last. The editor orders them by their position.
@export_storage var children: Array[BehaviorTask] = []

# The sequential child being run, or -1.
var _running_child: int = -1
# The parallel children being run.
var _active: Array[int] = []
var _last_child_status: Status = Status.INACTIVE


#region Parent hooks

## The most children this task accepts.
func max_children() -> int:
	return 1 << 30


## True when the children run at the same time.
func can_run_parallel_children() -> bool:
	return false


## The index of the child to run next.
func current_child_index() -> int:
	return 0


## True while another child should be started.
func can_execute() -> bool:
	return false


## Called when the child at [param index] is about to start.
func _on_child_started(_index: int) -> void:
	pass


## Called when the child at [param index] ends with [param child_status].
func _on_child_executed(_index: int, _child_status: Status) -> void:
	pass


## Turns the last child status into this task's status once no child can start. For
## parallel parents it is called every tick with [constant Status.RUNNING]. Returning
## [constant Status.RUNNING] keeps this task running.
func override_status(child_status: Status) -> Status:
	return Status.SUCCESS if child_status == Status.INACTIVE else child_status


## Called when a conditional abort restarts this task at the child at [param index].
func _on_conditional_abort(_index: int) -> void:
	pass

#endregion


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var count := 0
	for child in children:
		if child:
			count += 1
	if count == 0:
		warnings.append("%s has no children." % get_display_name())
	elif count > max_children():
		warnings.append("%s accepts at most %d child." % [get_display_name(), max_children()])
	return warnings


## The child at [param index], or null.
func get_child(index: int = 0) -> BehaviorTask:
	return children[index] if index >= 0 and index < children.size() else null


## The number of children.
func get_child_count() -> int:
	return children.size()


func _setup_children() -> void:
	for index in children.size():
		var child := children[index]
		if child:
			child._setup(agent, actor, _get_child_blackboard(), self, index)


func _start() -> void:
	_running_child = -1
	_active.clear()
	_last_child_status = Status.INACTIVE
	for child in children:
		if child:
			child._observed = Status.INACTIVE
	super()


func _execute(delta: float) -> Status:
	if can_run_parallel_children():
		return _execute_parallel(delta)
	return _execute_sequential(delta)


func _execute_sequential(delta: float) -> Status:
	while true:
		if _running_child < 0:
			if not can_execute():
				break
			var index := current_child_index()
			if index < 0 or index >= children.size() or children[index] == null:
				break
			_running_child = index
			_on_child_started(index)
		var running := _running_child
		var child := children[running]
		var result := child.tick(delta)
		if result == Status.RUNNING:
			return override_status(Status.RUNNING)
		_running_child = -1
		_last_child_status = result
		_on_child_executed(running, result)
		if not child.instant and can_execute():
			return Status.RUNNING
	return override_status(_last_child_status)


func _execute_parallel(delta: float) -> Status:
	while can_execute():
		var index := current_child_index()
		if index < 0 or index >= children.size():
			break
		_on_child_started(index)
		if children[index] and not _active.has(index):
			_active.append(index)
	for index in _active.duplicate():
		var result := children[index].tick(delta)
		if result != Status.RUNNING:
			_active.erase(index)
			_on_child_executed(index, result)
	var result := override_status(Status.RUNNING)
	if result != Status.RUNNING:
		_abort_children()
	return result


func _abort_children() -> void:
	if _running_child >= 0 and _running_child < children.size() and children[_running_child]:
		children[_running_child].abort()
	_running_child = -1
	for index in _active:
		if children[index]:
			children[index].abort()
	_active.clear()


func _pause(paused: bool) -> void:
	if not is_running:
		return
	super(paused)
	for child in children:
		if child:
			child._pause(paused)


func _visit(callback: Callable) -> void:
	super(callback)
	for child in children:
		if child:
			child._visit(callback)
