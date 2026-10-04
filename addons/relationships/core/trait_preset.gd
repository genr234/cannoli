@tool
class_name TraitPreset
extends Resource
## A named set of personality trait values, used as a shortcut when filling in
## the traits of factions and deeds.

@export var name := "":
	set(value):
		name = value
		resource_name = value
		emit_changed()
## Only for the designer's benefit.
@export_multiline var description := ""
## One value per personality trait definition in the database.
@export var traits := PackedFloat32Array()
