# res://addons/quest_weaver/graph/nodes/complete_objective_node_resource.gd
@tool
class_name CompleteObjectiveNodeResource
extends GraphNodeResource

# The ID of the objective to be completed.
@export var target_objective_id: String = ""

func _init():
	category = "Logic"
	input_ports = ["In"]
	output_ports = ["Out"]

func get_editor_summary() -> String:
	var line1 = "Complete"
	var line2: String

	# Check if the ID is missing and build the second line accordingly.
	if target_objective_id.is_empty():
		# If the ID is missing, add the [WARN] prefix only before this line.
		line2 = "[WARN]Target: (Not Set)"
	else:
		# Otherwise, create the normal text without a prefix.
		line2 = "'%s'" % target_objective_id
	
	# Join the two lines with a line break.
	return "%s\n%s" % [line1, line2]

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["target_objective_id"] = self.target_objective_id
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.target_objective_id = data.get("target_objective_id", "")
