# res://addons/quest_weaver/graph/nodes/graph_node_resource.gd
@tool
class_name GraphNodeResource
extends Resource

# The runtime status of this node.
enum Status { INACTIVE, ACTIVE, LOCKED, COMPLETED }
var status: Status = Status.INACTIVE

@export var id: String
@export var category: String = "Default"
@export var graph_position: Vector2
@export var input_ports: Array[String] = ["In"]
@export var output_ports: Array[String] = ["Out"]

## This function is called by the QuestController when the node becomes active.
func execute(controller) -> void:
	push_warning("Executing base method for node '%s'. This should be overridden in the derived class." % id)
	controller.complete_node(self)

## Provides a brief, human-readable summary for display in the graph editor.
func get_editor_summary() -> String:
	return ""

func to_dictionary() -> Dictionary:
	return {
		"@script_path": get_script().resource_path,
		"id": id,
		"category": category,
		"graph_position": graph_position,
		"input_ports": input_ports,
		"output_ports": output_ports
	}

func from_dictionary(data: Dictionary):
	self.id = data.get("id")
	self.category = data.get("category")
	self.graph_position = data.get("graph_position")
	self.input_ports = data.get("input_ports")
	self.output_ports = data.get("output_ports")
