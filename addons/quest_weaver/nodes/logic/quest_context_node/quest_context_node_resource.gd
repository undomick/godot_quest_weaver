# res://addons/quest_weaver/nodes/logic/quest_context_node/quest_context_node_resource.gd
@tool
class_name QuestContextNodeResource
extends GraphNodeResource

## Defines whether this is a Main or Side quest.
enum QuestType { MAIN, SIDE }
@export var quest_type: QuestType = QuestType.SIDE

## Unique identifier for this quest.
@export var quest_id: String = ""

## The title displayed to the player.
@export var quest_title: String = ""

## The initial description of the quest.
@export_multiline var quest_description: String = ""

## (Optional) An initial log entry added when the quest starts.
@export_multiline var log_on_start: String = ""

func _init() -> void:
	category = "Logic"
	input_ports = ["In"]
	output_ports = ["Out"]

func get_editor_summary() -> String:
	if quest_id.is_empty():
		return "!! NO QUEST ID SET !!"
	
	var type_text = "Main" if quest_type == QuestType.MAIN else "Side"
	
	return "\nID: %s\n%s Quest:\n%s" % [quest_id, type_text, quest_title]

func get_description() -> String:
	return "Defines the core properties of this quest (ID, Title, Description). Required once per graph."

func get_icon() -> Texture2D:
	return preload("res://addons/quest_weaver/assets/icons/context.svg")

func execute(_controller) -> void: 
	pass

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["quest_type"] = self.quest_type
	data["quest_id"] = self.quest_id
	data["quest_title"] = self.quest_title
	data["quest_description"] = self.quest_description
	data["log_on_start"] = self.log_on_start
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.quest_type = _defensive_load(data, "quest_type", QuestType.keys(), QuestType.SIDE)
	self.quest_id = data.get("quest_id", "")
	self.quest_title = data.get("quest_title", "")
	self.quest_description = data.get("quest_description", "")
	self.log_on_start = data.get("log_on_start", "")

## PRIVATE METHOD: Checks if an integer value is valid for the enum type.
func _defensive_load(data: Dictionary, prop: String, keys: Array, default_val: int) -> int:
	var val = data.get(prop, default_val)
	if val is int and val >= 0 and val < keys.size():
		return val
	return default_val

func _validate(_context: Dictionary) -> Array[ValidationResult]:
	var results: Array[ValidationResult] = []
	
	if quest_id.is_empty():
		results.append(ValidationResult.new(ValidationResult.Severity.ERROR, "Quest Context: Quest ID is not set.", id))
	if quest_title.is_empty():
		results.append(ValidationResult.new(ValidationResult.Severity.WARNING, "Quest Context: Quest Title is not set.", id))
		
	return results
