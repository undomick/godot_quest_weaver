# res://addons/quest_weaver/graph/nodes/quest_context_node_resource.gd
@tool
class_name QuestContextNodeResource
extends GraphNodeResource

## Definiert, ob es sich um eine Haupt- oder Nebenquest handelt.
enum QuestType { MAIN, SIDE }
@export var quest_type: QuestType = QuestType.SIDE

## Verweis auf die einmalig definierte Quest-ID.
@export var quest_id: String = ""

## Der Titel der Quest, der dem Spieler angezeigt wird.
@export var quest_title: String = ""

## Die anfängliche Beschreibung der Quest.
@export_multiline var quest_description: String = ""

## (Optional) Ein erster Logbucheintrag, der beim Start der Quest hinzugefügt wird.
@export_multiline var log_on_start: String = ""

func _init() -> void:
	category = "Logic"
	input_ports = ["In"]
	output_ports = ["Out"]

func get_editor_summary() -> String:
	if quest_id.is_empty():
		return "!! NO QUEST ID SET !!"
	
	var type_text = "Main" if quest_type == QuestType.MAIN else "Side"
	
	return "\nID: %s\n%s Quest:\n%s" % [quest_id,type_text, quest_title]

func execute(controller) -> void: pass

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["quest_type"] = self.quest_type # Hinzufügen
	data["quest_id"] = self.quest_id
	data["quest_title"] = self.quest_title
	data["quest_description"] = self.quest_description
	data["log_on_start"] = self.log_on_start
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.quest_type = data.get("quest_type", QuestType.SIDE) # Hinzufügen
	self.quest_id = data.get("quest_id", "")
	self.quest_title = data.get("quest_title", "")
	self.quest_description = data.get("quest_description", "")
	self.log_on_start = data.get("log_on_start", "")
