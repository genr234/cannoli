class_name FakeSave
extends Node
## A stand-in for the Save autoload, with the parts the quest system uses.

signal loaded(slot: int)

var sections := {}
var providers := {}


func register_section(section: String, provider: Callable) -> Error:
	providers[section] = provider
	return OK


func get_section(section: String) -> Dictionary:
	return sections.get(section, {})


## Stores what the registered providers return, like Save.save() does.
func collect() -> void:
	for section: String in providers:
		sections[section] = providers[section].call()
