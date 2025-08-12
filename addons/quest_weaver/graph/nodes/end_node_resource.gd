# res://addons/quest_weaver/graph/nodes/end_node_resource.gd
@tool
class_name EndNodeResource
extends GraphNodeResource

func _init() -> void:
	category = "Default"
	input_ports = ["In"]
	output_ports = [] 


func get_editor_summary() -> String:
	return ""

func execute(controller) -> void:
	pass
