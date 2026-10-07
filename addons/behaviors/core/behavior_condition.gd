@tool
@abstract
@icon("res://addons/behaviors/icons/condition.svg")
class_name BehaviorCondition
extends BehaviorTask
## A task that checks the game and changes nothing.
##
## Override [method BehaviorTask._on_update] and return
## [constant BehaviorTask.Status.SUCCESS] or [constant BehaviorTask.Status.FAILURE] in
## the same tick. Composites with an abort type run conditions again while later
## tasks run, and interrupt them when the result changes, so a condition must be
## cheap and must not depend on [method BehaviorTask._on_start] being called again.
