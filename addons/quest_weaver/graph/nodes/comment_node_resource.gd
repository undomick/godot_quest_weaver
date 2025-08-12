# res://addons/quest_weaver/graph/nodes/comment_node_resource.gd
@tool
class_name CommentNodeResource
extends GraphNodeResource

# The text content of the comment.
@export_multiline var text: String = "My Comment"

# The size of the node in the graph editor.
@export var node_size: Vector2 = Vector2(200, 150)


func _init() -> void:
	category = "Utility"
	input_ports = []
	output_ports = []

# This node does nothing at runtime, so we provide an empty execute function.
func execute(controller) -> void:
	controller.complete_node(self)

func get_editor_summary() -> String:
	if text.is_empty():
		return "(Empty Comment)"
	return text

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["text"] = self.text
	data["node_size"] = self.node_size
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.text = data.get("text", "My Comment")
	self.node_size = data.get("node_size", Vector2(200, 150))
