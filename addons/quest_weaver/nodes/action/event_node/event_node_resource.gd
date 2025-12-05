# res://addons/quest_weaver/nodes/action/event_node/event_node_resource.gd
@tool
class_name EventNodeResource
extends GraphNodeResource

## The name of the global event to fire.
@export var event_name: String = "my_quest_event"

## A Dictionary of data that will be sent as a payload with the event.
## Example: { "npc_id": "guard_captain", "state": "angry" }
@export var payload: Dictionary = {}


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

# Serialization remains the same, but with new variable names.
func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["event_name"] = self.event_name
	data["payload"] = self.payload
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.event_name = data.get("event_name", "my_quest_event")
	self.payload = data.get("payload", {})

func determine_default_size() -> QWNodeSizes.Size:
	return QWNodeSizes.Size.SMALL
