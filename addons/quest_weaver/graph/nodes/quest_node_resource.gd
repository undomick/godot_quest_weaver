# res://addons/quest_weaver/graph/nodes/quest_node_resource.gd
@tool
class_name QuestNodeResource
extends GraphNodeResource

enum QuestAction {
	COMPLETE, # Setzt den Status auf COMPLETED
	FAIL,     # Setzt den Status auf FAILED
	START     # Startet explizit eine andere Quest (selten, aber mächtig)
}

## Verweis auf die Quest, die beeinflusst werden soll.
@export var target_quest_id: String = ""
@export var action: QuestAction = QuestAction.COMPLETE

func _init() -> void:
	category = "Logic"
	input_ports = ["In"]
	output_ports = ["Out"]

func get_editor_summary() -> String:
	if not target_quest_id.is_empty():
		var id_text = target_quest_id
		return "%s:\n'%s'" % [QuestAction.keys()[action].capitalize(), id_text]
	else:
		return "[WARN]%s:\n???" % QuestAction.keys()[action].capitalize()

func execute(controller) -> void: pass

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["target_quest_id"] = self.target_quest_id
	data["action"] = self.action
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.target_quest_id = data.get("target_quest_id", "")
	self.action = data.get("action", QuestAction.COMPLETE)
