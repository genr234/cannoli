@tool
@icon("../icons/deed.svg")
class_name DeedCategory
extends Resource
## An optional category for deeds, such as "Combat" or "Trade".

@export var category_name := "":
	set(value):
		category_name = value
		resource_name = value
