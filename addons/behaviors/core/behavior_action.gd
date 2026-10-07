@tool
@abstract
@icon("res://addons/behaviors/icons/action.svg")
class_name BehaviorAction
extends BehaviorTask
## A task that changes the game: moves the actor, plays a sound, sets a variable.
##
## Override [method BehaviorTask._on_update] and return
## [constant BehaviorTask.Status.RUNNING] while the work is not done.
