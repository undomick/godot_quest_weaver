# res://addons/quest_weaver/graph/nodes/backdrop_node_resource.gd
@tool
class_name BackdropNodeResource
extends GraphNodeResource

@export var title: String = ""
@export_multiline var text: String = ""
@export var color: Color = Color(0.2, 0.23, 0.3, 0.6)
@export var node_size: Vector2 = Vector2(400, 300)
@export_range(10, 48, 1) var title_font_size: int = 16

func _init() -> void:
	category = "Backdrop"
	input_ports = []
	output_ports = []

func execute(controller) -> void:
	pass

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["title"] = self.title
	data["text"] = self.text
	data["color"] = self.color
	data["node_size"] = self.node_size
	data["title_font_size"] = self.title_font_size
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.title = data.get("title", "")
	self.text = data.get("text", "")
	self.color = data.get("color", Color(0.2, 0.23, 0.3, 0.6))
	self.node_size = data.get("node_size", Vector2(400, 300))
	self.title_font_size = data.get("title_font_size", 16)
