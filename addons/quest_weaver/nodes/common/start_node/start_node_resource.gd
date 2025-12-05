# res://addons/quest_weaver/nodes/common/start_node/start_node_resource.gd
@tool
class_name StartNodeResource
extends GraphNodeResource

func _init():
	category = "Default"
	input_ports = [""]
	output_ports = ["Out"]



func get_editor_summary() -> String:
	return ""

func get_description() -> String:
	return "The entry point of the quest graph. Execution begins here."

func get_icon() -> Texture2D:
	return preload("res://addons/quest_weaver/assets/icons/flag.svg")

func execute(controller): pass

func determine_default_size() -> QWNodeSizes.Size:
	return QWNodeSizes.Size.TINY
