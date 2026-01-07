# res://addons/quest_weaver/editor/commands/remove_payload_command.gd
@tool
class_name RemovePayloadCommand
extends EditorCommand

var _event_node: EventNodeResource
var _entry_to_remove: EventNodeResource.PayloadEntry
var _original_index: int = -1

func _init(p_event_node: EventNodeResource, p_entry_to_remove: EventNodeResource.PayloadEntry):
	self._event_node = p_event_node
	self._entry_to_remove = p_entry_to_remove

func execute() -> void:
	self._original_index = _event_node.payload_entries.find(_entry_to_remove)
	
	if _original_index != -1:
		_event_node.payload_entries.erase(_entry_to_remove)

func undo() -> void:
	if _original_index != -1:
		_event_node.payload_entries.insert(_original_index, _entry_to_remove)
