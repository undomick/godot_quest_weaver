# res://addons/quest_weaver/graph/nodes/start_scope_node_resource.gd
@tool
class_name StartScopeNodeResource
extends GraphNodeResource

@export var scope_id: String = "my_scope_1"

## 0 = infinite.
@export_range(0, 100, 1) var max_executions: int = 0

var current_executions: int = 0

func _init():
	category = "Logic"
	input_ports = ["In"]
	output_ports = ["On Start", "On Max Reached"]

func get_editor_summary() -> String:
	var id_text = scope_id if not scope_id.is_empty() else "???"
	var limit_text = " (Limit: %d)" % max_executions if max_executions > 0 else " (No Limit)"
	return "Begin Scope:\n%s\n%s" % [id_text, limit_text]

func execute(controller): pass

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["scope_id"] = self.scope_id
	data["max_executions"] = self.max_executions
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.scope_id = data.get("scope_id", "my_scope_1")
	self.max_executions = data.get("max_executions", 0)
