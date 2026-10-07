@tool
@icon("res://addons/behaviors/icons/task_guard.svg")
class_name BehaviorTaskGuard
extends BehaviorDecorator
## Limits how many branches can run a shared resource at once, like a semaphore.
##
## Every guard with the same [member key] shares one count. Put a guard with key
## [code]&"voice"[/code] above each task that plays a voice line, with
## [member max_access_count] 1, and two lines never play at the same time.

## Where guards with the same key share their count.
enum Scope {
	## Guards in the same agent.
	AGENT,
	## Guards in every agent.
	GLOBAL,
}

## Guards with the same key share one count.
@export var key: StringName = &"guard"
## How many guarded children can run at once.
@export_range(1, 100, 1, "or_greater") var max_access_count: int = 1
## Waits until a slot is free. When false, fails at once if no slot is free.
@export var wait_until_available: bool = true
## Which guards share the count.
@export var scope: Scope = Scope.AGENT

var _holding: bool = false


func _execute(delta: float) -> Status:
	if not _holding:
		if not Behaviors._acquire_guard(_get_guards(), key, max_access_count):
			return Status.RUNNING if wait_until_available else Status.FAILURE
		_holding = true
	return super(delta)


func _get_graph_text() -> String:
	return "%s ≤ %d" % [key, max_access_count]


func _on_end() -> void:
	if _holding:
		Behaviors._release_guard(_get_guards(), key)
		_holding = false


func _get_guards() -> Dictionary[StringName, int]:
	return Behaviors._guards if scope == Scope.GLOBAL or agent == null else agent._guards
