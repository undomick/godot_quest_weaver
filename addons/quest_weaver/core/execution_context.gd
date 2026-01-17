# res://addons/quest_weaver/core/execution_context.gd
class_name ExecutionContext
extends RefCounted

## A data container that bundles all external dependencies for the execution
## of a quest graph. It is created once and then passed through the execution flow.

var game_state: Node
var quest_controller: QuestController
var logger: QWLogger
var services: Node

# Dictionaries mapping specific IDs (items, enemies, interaction paths) to active Objectives.
var item_objective_listeners: Dictionary = {}
var kill_objective_listeners: Dictionary = {}
var interact_objective_listeners: Dictionary = {}
var location_objective_listeners: Dictionary = {} 

## Constructor to set all dependencies upon creation.
func _init(p_controller: QuestController, p_game_state: Node, p_logger: QWLogger, p_services: Node) -> void:
	self.quest_controller = p_controller
	self.game_state = p_game_state
	self.logger = p_logger
	self.services = p_services
