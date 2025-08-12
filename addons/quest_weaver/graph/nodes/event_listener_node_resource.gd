# res://addons/quest_weaver/graph/nodes/event_listener_node_resource.gd
@tool
class_name EventListenerNodeResource
extends GraphNodeResource

## Hält einen Questzweig an, bis ein bestimmtes globales Ereignis
## (via QuestWeaver.quest_event_fired) ausgelöst wird.

@export var event_name: String = "my_game_event"
@export var payload_condition: ConditionResource

@export var use_simple_conditions: bool = true
@export var simple_conditions: Array[Dictionary] = [] # Format: [{"key": "", "op": 0, "value": ""}]

enum SimpleOperator { EQUALS, NOT_EQUALS, GREATER_THAN, LESS_THAN, GREATER_OR_EQUAL, LESS_OR_EQUAL, HAS }

func _init() -> void:
	category = "Flow"
	# "In" startet das Warten, "Cancel" bricht es ab.
	input_ports = ["In", "Cancel"] 
	# "On Event" wird bei Erfolg gefeuert, "On Cancel" bei Abbruch.
	output_ports = ["On Event", "On Cancel"]
	
	if id.is_empty() and not is_instance_valid(payload_condition):
		payload_condition = QWConstants.ConditionResourceScript.new()
		#payload_condition.resource_local_to_scene = true

func get_editor_summary() -> String:
	var event_name_text = event_name if not event_name.is_empty() else "???"
	return "Listen for:\n'%s'" % event_name_text

func execute(controller) -> void:
	pass

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["event_name"] = self.event_name
	if is_instance_valid(payload_condition):
		data["payload_condition"] = payload_condition.to_dictionary()
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.event_name = data.get("event_name", "my_game_event")
	var cond_data = data.get("payload_condition")
	if cond_data is Dictionary:
		var script = load(cond_data.get("@script_path"))
		if script:
			self.payload_condition = script.new()
			self.payload_condition.from_dictionary(cond_data)
