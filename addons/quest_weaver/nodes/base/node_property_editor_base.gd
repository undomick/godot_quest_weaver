# res://addons/quest_weaver/nodes/base/node_property_editor_base.gd
@tool
class_name NodePropertyEditorBase
extends VBoxContainer

signal property_update_requested(node_id: String, property_name: String, new_value: Variant)
signal complex_action_requested(node_id: String, action: String, payload: Dictionary)

var edited_node_data: GraphNodeResource

func set_node_data(node_data: GraphNodeResource) -> void:
	self.edited_node_data = node_data
