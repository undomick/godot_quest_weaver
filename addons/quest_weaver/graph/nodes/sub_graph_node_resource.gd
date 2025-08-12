# res://addons/quest_weaver/graph/nodes/sub_graph_node_resource.gd
@tool
class_name SubGraphNodeResource
extends GraphNodeResource

## Führt einen anderen Quest-Graphen als untergeordneten Prozess aus.
## Kann optional auf dessen Abschluss warten, bevor er den Haupt-Fluss fortsetzt.

@export_file("*.tres", "*.quest") var quest_graph_path: String
@export var wait_for_completion: bool = true


func _init():
	category = "Logic"
	input_ports = ["In"]
	output_ports = ["Out"]

func get_editor_summary() -> String:
	var path_text = quest_graph_path.get_file() if not quest_graph_path.is_empty() else "(Not Set)"
	return "Run:\n%s" % path_text

func execute(controller):
	pass

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["quest_graph_path"] = self.quest_graph_path
	data["wait_for_completion"] = self.wait_for_completion
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.quest_graph_path = data.get("quest_graph_path", "")
	self.wait_for_completion = data.get("wait_for_completion", true)
