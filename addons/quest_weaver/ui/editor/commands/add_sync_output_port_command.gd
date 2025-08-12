# res://addons/quest_weaver/ui/editor/commands/add_sync_output_port_command.gd
@tool
class_name AddSyncOutputPortCommand
extends EditorCommand

var _node_data: SynchronizeNodeResource
var _new_port_data: SynchronizeOutputPort

func _init(p_node_data: SynchronizeNodeResource):
	self._node_data = p_node_data

func execute() -> void:
	# If this is the first execution (not a redo), create a new port resource.
	if not is_instance_valid(_new_port_data):
		_new_port_data = SynchronizeOutputPort.new()
		_new_port_data.port_name = "Out %d" % (_node_data.outputs.size() + 1)
	
	_node_data.outputs.append(_new_port_data)
	_node_data._update_ports_from_data()

func undo() -> void:
	# Undo is simple: just remove the port we just added.
	_node_data.outputs.erase(_new_port_data)
	_node_data._update_ports_from_data()
