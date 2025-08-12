# res://addons/quest_weaver/graph/nodes/start_node_resource.gd
@tool
class_name StartNodeResource
extends GraphNodeResource

func _init():
	category = "Default"
	input_ports = [""]
	output_ports = ["Out"]



func get_editor_summary() -> String:
	return ""

func execute(controller): pass
