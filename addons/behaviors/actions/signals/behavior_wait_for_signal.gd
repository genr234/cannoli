@tool
@icon("res://addons/behaviors/icons/signal.svg")
class_name BehaviorWaitForSignal
extends BehaviorAction
## Runs until a signal is emitted, then succeeds. Fails when the target is missing, has
## no such signal, is freed while waiting, or the timeout runs out.
##
## The signal is connected when the task starts and disconnected when it ends, also
## when it is interrupted. Signals emitted before the task starts are not seen.

## The node that emits the signal, relative to the actor. Empty is the actor.
@export var target: NodePath = NodePath()
## A variable holding the object that emits the signal. Replaces [member target] when
## set.
@export var target_variable: String = ""
## The signal to wait for.
@export var signal_name: StringName = &""
## Variables that receive the signal's arguments, in order. Extra arguments are
## dropped, and extra names are left alone.
@export var store_arguments: PackedStringArray = PackedStringArray()
## Fails after this many seconds. 0 waits forever.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var timeout: float = 0.0

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")

var _source: Object
var _emitted: bool = false
var _arguments: Array = []
var _argument_count: int = 0
var _elapsed: float = 0.0
var _connected: bool = false


func _on_start() -> void:
	_emitted = false
	_arguments = []
	_elapsed = 0.0
	_connected = false
	_source = Targets.resolve(self, target, target_variable)
	if _source == null or not _source.has_signal(signal_name):
		Targets.warn_once(self, "cannot wait for signal \"%s\"." % signal_name)
		_source = null
		return
	for info in _source.get_signal_list():
		if info.name == signal_name:
			_argument_count = info.args.size()
			break
	_source.connect(signal_name, _on_emitted)
	_connected = true


func _on_update(delta: float) -> Status:
	if not _connected:
		return Status.FAILURE
	if not is_instance_valid(_source):
		_connected = false
		return Status.FAILURE
	if _emitted:
		for index in mini(store_arguments.size(), _arguments.size()):
			if not store_arguments[index].is_empty():
				set_var(StringName(store_arguments[index]), _arguments[index])
		return Status.SUCCESS
	_elapsed += delta
	if timeout > 0.0 and _elapsed >= timeout:
		return Status.FAILURE
	return Status.RUNNING


func _on_end() -> void:
	if _connected and is_instance_valid(_source) and _source.is_connected(signal_name, _on_emitted):
		_source.disconnect(signal_name, _on_emitted)
	_connected = false
	_source = null


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if String(signal_name).is_empty():
		warnings.append("Wait For Signal has no signal name.")
	return warnings


func _get_graph_text() -> String:
	return String(signal_name) if timeout <= 0.0 else "%s (%ss)" % [signal_name, timeout]


# Accepts any signal with up to six arguments. The real count comes from the signal's
# declaration, because unused defaults are indistinguishable from null arguments.
func _on_emitted(a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null, e: Variant = null, f: Variant = null) -> void:
	if _emitted:
		return
	_emitted = true
	_arguments = [a, b, c, d, e, f].slice(0, mini(_argument_count, 6))
