# res://addons/quest_weaver/graph/nodes/end_scope_node_resource.gd
@tool
class_name EndScopeNodeResource
extends GraphNodeResource

## Muss mit der ID eines StartScopeNode im selben Graphen übereinstimmen.
@export var scope_id: String = "my_scope_1"

func _init():
	category = "Logic"
	input_ports = ["In"]
	# Der "Scope Completed"-Ausgang wird nur gefeuert, wenn der Knoten erreicht wird.
	# Er signalisiert das erfolgreiche Ende eines Scope-Durchlaufs.
	output_ports = ["Scope Completed"]

func get_editor_summary() -> String:
	var id_text = scope_id if not scope_id.is_empty() else "???"
	return "End Scope:\n'%s'" % id_text

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["scope_id"] = self.scope_id
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.scope_id = data.get("scope_id", "my_scope_1")
