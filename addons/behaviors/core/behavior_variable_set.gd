@tool
@icon("res://addons/behaviors/icons/variable.svg")
class_name BehaviorVariableSet
extends Resource
## A list of variables saved on its own, used for the global variables.
##
## Point the project setting [code]behaviors/variables/global_variables[/code] at one
## of these, and every tree can read and write its variables with the
## [code]global/[/code] prefix.

## The variables.
@export var variables: Array[BehaviorVariable] = []


## The variable with [param variable_name], or null.
func get_variable(variable_name: StringName) -> BehaviorVariable:
	for variable in variables:
		if variable and variable.name == variable_name:
			return variable
	return null
