class_name QuestSignalRelay
extends Node
## Forwards a signal to the quest message bus. Connect any signal to [method relay]
## (in the editor or with [code]button.pressed.connect($QuestSignalRelay.relay)[/code]),
## or set [member source] and [member signal_name] to connect automatically.
## Quest message conditions and counters can then react to it without code.

enum ValueSource {
	## Send no value.
	NONE,
	## Send [member value].
	LITERAL,
	## Send the first argument of the signal.
	SIGNAL_ARGUMENT,
}

## The message to send, such as "Door Opened".
@export var message := ""
## The message parameter, such as the door's name.
@export var parameter := ""
@export var value_source := ValueSource.NONE
## The value to send when the source is LITERAL.
@export var value: QuestMessageValue
## The sender's ID. If empty, the ID of the [QuestIdentity] found on the parent.
@export var sender_id := ""
## The target's ID. Empty broadcasts to every listener.
@export var target_id := ""
## Optional node with a signal to connect to automatically.
@export var source: Node
## The signal of [member source] to connect to.
@export var signal_name := &""
## Only relay the first time.
@export var once := false
@export var enabled := true

var _relayed := false


func _ready() -> void:
	if source != null and not signal_name.is_empty():
		if source.has_signal(signal_name):
			source.connect(signal_name, relay)
		else:
			push_warning("Quests: %s has no signal '%s'." % [source.name, signal_name])


## Sends the configured message. Accepts up to eight signal arguments so that any
## signal can be connected to it.
func relay(arg0: Variant = null, _arg1: Variant = null, _arg2: Variant = null, _arg3: Variant = null,
		_arg4: Variant = null, _arg5: Variant = null, _arg6: Variant = null, _arg7: Variant = null) -> void:
	if not enabled or message.is_empty() or (once and _relayed):
		return
	_relayed = true
	var sent_value: Variant = null
	match value_source:
		ValueSource.LITERAL:
			sent_value = value.get_value() if value != null else null
		ValueSource.SIGNAL_ARGUMENT:
			sent_value = arg0
	var sender := sender_id
	if sender.is_empty() and get_parent() != null:
		sender = QuestMessages.get_id(get_parent())
	Quests.send_message(message, parameter, sent_value, sender, target_id)


## Sends the configured message with the literal value. Handy for wiring from the editor.
func trigger() -> void:
	relay()
