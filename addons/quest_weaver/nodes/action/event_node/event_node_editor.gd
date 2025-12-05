# res://addons/quest_weaver/nodes/action/event_node/event_node_editor.gd
@tool
class_name EventNodeEditor
extends NodePropertyEditorBase

@onready var event_name_edit: LineEdit = %SignalNameEdit
@onready var payload_edit: TextEdit = %PayloadEdit

func _ready() -> void:
	payload_edit.placeholder_text = """(example)
{
  "door_id": "special_door",
  "key_id": "special_key"
}"""
	event_name_edit.text_submitted.connect(func(_text): _on_event_name_confirmed())
	event_name_edit.focus_exited.connect(_on_event_name_confirmed)
	payload_edit.focus_exited.connect(_on_payload_confirmed)

func set_node_data(node_data: GraphNodeResource) -> void:
	super.set_node_data(node_data)
	if not node_data is EventNodeResource: return
	
	event_name_edit.text = node_data.event_name
	payload_edit.remove_theme_color_override("font_color")

func _on_event_name_confirmed() -> void:
	var current_text = event_name_edit.text
	if is_instance_valid(edited_node_data) and edited_node_data.event_name != current_text:
		property_update_requested.emit(edited_node_data.id, "event_name", current_text)

func _on_payload_confirmed() -> void:
	var text = payload_edit.text
	if text.strip_edges().is_empty():
		if is_instance_valid(edited_node_data) and not edited_node_data.payload.is_empty():
			property_update_requested.emit(edited_node_data.id, "payload", {})
		payload_edit.remove_theme_color_override("font_color")
		return
		
	var json_parser_result = JSON.parse_string(text)
	
	if json_parser_result != null:
		if is_instance_valid(edited_node_data) and edited_node_data.payload != json_parser_result:
			property_update_requested.emit(edited_node_data.id, "payload", json_parser_result)
		payload_edit.remove_theme_color_override("font_color")
	else:
		payload_edit.add_theme_color_override("font_color", Color.RED)
