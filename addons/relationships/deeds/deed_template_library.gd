@tool
@icon("../icons/deed.svg")
class_name DeedTemplateLibrary
extends Resource
## A list of deed templates for [DeedReporter].

## Used only in the editor, to name the templates' traits.
@export var faction_database: FactionDatabase
@export var deed_templates: Array[DeedTemplate] = []


## Returns the template with this tag, or null.
func find_template(tag: String) -> DeedTemplate:
	for template in deed_templates:
		if template != null and template.tag == tag:
			return template
	return null
