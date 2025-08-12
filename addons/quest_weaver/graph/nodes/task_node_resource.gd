# res://addons/quest_weaver/graph/nodes/task_node_resource.gd
@tool
class_name TaskNodeResource
extends GraphNodeResource

## Eine Liste der konkreten Ziele, die erfüllt werden müssen.
@export var objectives: Array[ObjectiveResource] = []

func _init():
	category = "Action"
	
	if id.is_empty() and objectives.is_empty():
		var new_objective = QWConstants.ObjectiveResourceScript.new()
		new_objective.id = "objective_%d" % Time.get_unix_time_from_system()
		new_objective.description = "New Objective"
		objectives.append(new_objective)

func get_editor_summary() -> String:
	if objectives.is_empty():
		return "(No Objectives!)"
	
	var summary_lines: Array[String] = []
	
	for i in range(min(objectives.size(), 3)):
		var objective: ObjectiveResource = objectives[i]
		if not is_instance_valid(objective):
			continue
			
		var trigger_type_name = ObjectiveResource.TriggerType.keys()[objective.trigger_type].replace("_", " ").capitalize()
		var description_preview: String
		var warning_prefix = "" # Standardmäßig kein Präfix
		
		# HIER IST DIE GEZIELTE ÄNDERUNG:
		if objective.description.is_empty():
			# Setze den gewünschten Warntext
			description_preview = "Missing Objective Title" 
			# Füge das Präfix nur für DIESE Zeile hinzu
			warning_prefix = "[WARN]" 
		else:
			description_preview = objective.description.left(30) + ("..." if objective.description.length() > 30 else "")
		
		# Baue den zweizeiligen String zusammen, mit dem möglichen Präfix davor.
		var objective_summary = "%s%d) %s:\n   %s" % [warning_prefix, i + 1, description_preview, trigger_type_name]
		summary_lines.append(objective_summary)

	if objectives.size() > 3:
		var remaining_count = objectives.size() - 3
		var plural_s = "s" if remaining_count > 1 else ""
		summary_lines.append("... and %d more Objective%s" % [remaining_count, plural_s])
	
	return "\n".join(summary_lines)

func execute(controller):
	pass

func add_objective(payload: Dictionary):
	if payload.has("objective_instance"):
		var objective_instance = payload.get("objective_instance")
		if is_instance_valid(objective_instance):
			objectives.append(objective_instance)
			return
	
	var new_objective = QWConstants.ObjectiveResourceScript.new()
	new_objective.id = "objective_%d" % Time.get_unix_time_from_system()
	new_objective.description = "New Objective"
	objectives.append(new_objective)

func remove_objective(payload: Dictionary):
	if payload.has("objective"):
		objectives.erase(payload["objective"])

func update_objective_description(payload: Dictionary):
	if payload.has("objective") and payload.has("new_description"):
		var objective: ObjectiveResource = payload["objective"]
		objective.description = payload["new_description"]

func update_objective_trigger_type(payload: Dictionary):
	if payload.has("objective") and payload.has("new_type_index"):
		var objective: ObjectiveResource = payload["objective"]
		var new_type_index = payload["new_type_index"]
		var new_type = ObjectiveResource.TriggerType.values()[new_type_index]

		if objective.trigger_type == new_type:
			return

		objective.trigger_type = new_type
		
		match new_type:
			ObjectiveResource.TriggerType.MANUAL, \
			ObjectiveResource.TriggerType.INTERACT, \
			ObjectiveResource.TriggerType.LOCATION_ENTER:
				pass

func update_objective_trigger_param(payload: Dictionary):
	if payload.has("objective") and payload.has("param_name") and payload.has("param_value"):
		var objective: ObjectiveResource = payload["objective"]
		var param_name = payload["param_name"]
		var param_value = payload["param_value"]
		
		print("   -> Schreibe '", param_value, "' in trigger_params['", param_name, "']")
		objective.trigger_params[param_name] = param_value
		print("   -> Aktueller Inhalt von trigger_params: ", objective.trigger_params)

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	
	var objectives_data = []
	for objective in self.objectives:
		if is_instance_valid(objective):
			objectives_data.append(objective.to_dictionary())
	
	data["objectives"] = objectives_data
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	
	self.objectives.clear()
	var objectives_data = data.get("objectives", [])
	for objective_dict in objectives_data:
		var script_path = objective_dict.get("@script_path")
		if script_path and ResourceLoader.exists(script_path):
			var new_objective = load(script_path).new()
			new_objective.from_dictionary(objective_dict)
			self.objectives.append(new_objective)
