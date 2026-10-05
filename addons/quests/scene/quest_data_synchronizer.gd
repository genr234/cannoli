class_name QuestDataSynchronizer
extends Node
## Keeps a quest counter in [constant QuestCounter.UpdateMode.DATA_SYNC] mode in
## step with a value that lives somewhere else, such as an inventory script.
##
## Call [method data_source_value_changed] when your value changes; counters
## that watch [member data_source_name] follow it. To synchronize the other way,
## connect [signal request_data_source_change_value] to a method that applies
## the value.

## Emitted when a counter asks the data source to change its value.
signal request_data_source_change_value(value: Variant)

## The name of the data source. Counters with this name follow it.
@export var data_source_name := ""


func _enter_tree() -> void:
	QuestMessages.add_listener(self, QuestMessages.REQUEST_DATA_SOURCE_CHANGE_VALUE, data_source_name, _on_message)


func _exit_tree() -> void:
	QuestMessages.remove_listener(self)


## Tells listeners, such as quest counters, that the data source's value changed.
func data_source_value_changed(new_value: Variant) -> void:
	QuestMessages.send(self, null, QuestMessages.DATA_SOURCE_VALUE_CHANGED, data_source_name, [new_value])


func _on_message(args: QuestMessageArgs) -> void:
	request_data_source_change_value.emit(args.first_value())
