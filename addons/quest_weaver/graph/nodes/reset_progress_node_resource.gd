# res://addons/quest_weaver/graph/nodes/reset_progress_node_resource.gd
@tool
class_name ResetProgressNodeResource
extends GraphNodeResource

## Setzt den Fortschritt aller Knoten innerhalb eines definierten Scopes
## (beginnend mit einem 'Start Scope Node') zurück und startet diesen optional neu.

@export var target_scope_id: String = ""
@export var restart_scope_on_completion: bool = true


func _init():
	category = "Logic"
	input_ports = ["In"]
	# Dieser Knoten hat optional einen Ausgang. Man könnte einen Pfad fortsetzen,
	# nachdem ein Reset ausgelöst wurde, aber meistens wird die Questschleife neu gestartet.
	output_ports = ["On Reset"] 

func get_editor_summary() -> String:
	var line1 = "Reset Scope:"
	var line2: String

	if target_scope_id.is_empty():
		line2 = "[WARN]No Target!"
	else:
		line2 = "'%s'" % target_scope_id
	
	return "%s\n%s" % [line1, line2]

func execute(controller):
	pass

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["target_scope_id"] = self.target_scope_id
	data["restart_scope_on_completion"] = self.restart_scope_on_completion
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.target_scope_id = data.get("target_scope_id", "")
	self.restart_scope_on_completion = data.get("restart_scope_on_completion", true)
