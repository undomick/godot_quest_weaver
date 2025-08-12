# res://addons/quest_weaver/logic/execution_context.gd
class_name ExecutionContext
extends RefCounted

## Ein Datencontainer, der alle externen Abhängigkeiten für die Ausführung
## eines Quest-Graphen bündelt. Er wird einmal erstellt und dann durchgereicht.

var game_state
var quest_controller

var item_objective_listeners: Dictionary = {}
var kill_objective_listeners: Dictionary = {}
var interact_objective_listeners: Dictionary = {}

## Konstruktor, um alle Abhängigkeiten bei der Erstellung zu setzen.
func _init(p_controller: QuestController, p_game_state: Node):
	self.quest_controller = p_controller
	self.game_state = p_game_state
