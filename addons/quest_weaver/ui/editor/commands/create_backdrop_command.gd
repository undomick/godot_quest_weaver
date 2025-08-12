# res://addons/quest_weaver/ui/editor/commands/create_backdrop_command.gd
@tool
class_name CreateBackdropCommand
extends EditorCommand

var _graph: QuestGraphResource
var _selected_nodes: Array[GraphElement]
var _new_backdrop_data: BackdropNodeResource

func _init(p_graph: QuestGraphResource, p_selected_nodes: Array[GraphElement]):
	self._graph = p_graph
	self._selected_nodes = p_selected_nodes

func execute() -> void:
	if _selected_nodes.is_empty():
		return

	var bounds = Rect2(_selected_nodes[0].position_offset, _selected_nodes[0].size)
	for i in range(1, _selected_nodes.size()):
		var node_rect = Rect2(_selected_nodes[i].position_offset, _selected_nodes[i].size)
		bounds = bounds.merge(node_rect)

	bounds = bounds.grow(50)

	var BackdropNodeScript = load("res://addons/quest_weaver/graph/nodes/backdrop_node_resource.gd")
	_new_backdrop_data = BackdropNodeScript.new()
	_new_backdrop_data.id = "backdrop_%d" % Time.get_unix_time_from_system()
	_new_backdrop_data.graph_position = bounds.position
	_new_backdrop_data.node_size = bounds.size
	_new_backdrop_data.title = "New Group"

	_graph.add_node(_new_backdrop_data)

func undo() -> void:
	if is_instance_valid(_new_backdrop_data):
		_graph.remove_node(_new_backdrop_data.id)
