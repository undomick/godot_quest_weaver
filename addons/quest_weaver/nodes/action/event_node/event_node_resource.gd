# res://addons/quest_weaver/nodes/action/event_node/event_node_resource.gd
@tool
class_name EventNodeResource
extends GraphNodeResource

class PayloadEntry extends Resource:
	@export var key: String = "my_key"
	@export var value_string: String = ""
	enum Type { STRING, INT, FLOAT, BOOL }
	@export var value_type: Type = Type.STRING

## The name of the global event to fire.
@export var event_name: String = "my_quest_event"

## A List of PayloadEntries
@export var payload_entries: Array[PayloadEntry] = []


func _init() -> void:
	category = "Action" 
	input_ports = ["In"]
	output_ports = ["Out"]

func get_editor_summary() -> String:
	if event_name.is_empty():
		return "[WARN]No Event Name"
	else:
		return "Fire Event:\n'%s'" % event_name

func get_description() -> String:
	return "Fires a global signal ('quest_event_fired') to trigger external game logic (e.g., open door)."

func get_icon() -> Texture2D:
	return preload("res://addons/quest_weaver/assets/icons/signal.svg")

func get_runtime_payload() -> Dictionary:
	var payload: Dictionary = {}
	for entry in payload_entries:
		if not is_instance_valid(entry) or entry.key.is_empty(): continue
		
		var parsed_value: Variant
		
		match entry.value_type:
			PayloadEntry.Type.INT:
				parsed_value = entry.value_string.to_int()
			PayloadEntry.Type.FLOAT:
				parsed_value = entry.value_string.to_float()
			PayloadEntry.Type.BOOL:
				parsed_value = entry.value_string.to_lower() == "true"
			PayloadEntry.Type.STRING:
				parsed_value = entry.value_string
		
		payload[entry.key] = parsed_value
		
	return payload

# Serialization remains the same, but with new variable names.
func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["event_name"] = self.event_name
	var entries_data = []
	for entry in self.payload_entries:
		if is_instance_valid(entry):
			entries_data.append(entry.to_dictionary())
			
	data["payload_entries"] = entries_data
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.event_name = data.get("event_name", "my_quest_event")
	self.payload_entries.clear()
	var entries_data = data.get("payload_entries", [])
	for entry_dict in entries_data:
		var new_entry = PayloadEntry.new()
		new_entry.key = entry_dict.get("key", "")
		new_entry.value_string = entry_dict.get("value_string", "")
		new_entry.value_type = entry_dict.get("value_type", PayloadEntry.Type.STRING)
		self.payload_entries.append(new_entry)

func determine_default_size() -> QWNodeSizes.Size:
	return QWNodeSizes.Size.SMALL
