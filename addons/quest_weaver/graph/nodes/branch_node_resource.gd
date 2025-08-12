# res://addons/quest_weaver/graph/nodes/branch_node_resource.gd
@tool
class_name BranchNodeResource
extends GraphNodeResource

enum LogicOperator { AND, OR, NAND, NOR }
@export var operator: LogicOperator = LogicOperator.AND
@export var conditions: Array[ConditionResource] = []

func _init() -> void:
	category = "Flow" 
	input_ports = ["In"]
	output_ports = ["True", "False"]

	if id.is_empty() and conditions.is_empty():
		add_condition({})

func execute(controller) -> void:
	pass

func check_all_conditions(context: ExecutionContext) -> bool:
	if conditions.is_empty():
		return true

	match operator:
		LogicOperator.AND:
			for condition in conditions:
				if not is_instance_valid(condition) or not condition.check(context):
					return false
			return true
			
		LogicOperator.OR:
			for condition in conditions:
				if is_instance_valid(condition) and condition.check(context):
					return true
			return false

		LogicOperator.NAND: # Not AND
			for condition in conditions:
				if not is_instance_valid(condition) or not condition.check(context):
					return true
			return false
			
		LogicOperator.NOR: # Not OR
			for condition in conditions:
				if is_instance_valid(condition) and condition.check(context):
					return false
			return true
			
	return false # Should never be the case

func get_editor_summary() -> String:
	if conditions.is_empty():
		return "[NO CONDITIONS!]"
		
	var summary_lines: Array[String] = []
	
	var operator_name = LogicOperator.keys()[operator]
	summary_lines.append(operator_name)
	
	if conditions.size() >= 1:
		var condition1_summary = _format_condition_summary(conditions[0])
		summary_lines.append("1) %s" % condition1_summary)
		
	if conditions.size() >= 2:
		var condition2_summary = _format_condition_summary(conditions[1])
		summary_lines.append("2) %s" % condition2_summary)
	
	if conditions.size() > 2:
		var remaining_count = conditions.size() - 2
		var plural_s = "s" if remaining_count > 1 else ""
		summary_lines.append("... and %d more Condition%s" % [remaining_count, plural_s])
	
	return "\n".join(summary_lines)

func _format_condition_summary(condition: ConditionResource) -> String:
	if not is_instance_valid(condition):
		return "Invalid Condition"

	match condition.type:
		ConditionResource.ConditionType.BOOL:
			return "BOOL is %s" % str(condition.is_true).capitalize()
		ConditionResource.ConditionType.CHANCE:
			return "CHANCE: %s%%" % condition.chance_percentage
		ConditionResource.ConditionType.CHECK_ITEM:
			if condition.item_id.is_empty():
				return "CHECK_ITEM:\n(ID missing)"
			return "CHECK_ITEM:\n%d x '%s'" % [condition.amount, condition.item_id.get_file()]
		ConditionResource.ConditionType.CHECK_QUEST_STATUS:
			var status_name = QWConstants.QWEnums.QuestState.keys()[condition.expected_status].capitalize()
			return "QUEST_CHECK:\n'%s' is %s" % [condition.quest_id, status_name]
		ConditionResource.ConditionType.CHECK_VARIABLE:
			var op_keys = ["==", "!=", ">", "<", ">=", "<="]
			var op_symbol = op_keys[condition.operator]
			return "VAR:\n%s %s %s" % [condition.variable_name, op_symbol, condition.expected_value_string]
		ConditionResource.ConditionType.CHECK_OBJECTIVE_STATUS:
			var status_name = ObjectiveResource.Status.keys()[condition.expected_objective_status].capitalize()
			return "OBJECTIVE:\n...%s is %s" % [condition.objective_id.right(4), status_name]
		ConditionResource.ConditionType.COMPOUND:
			var op_name = condition.LogicOperator.keys()[condition.logic_operator]
			return "COMPOUND:\n%s (%d sub)" % [op_name, condition.sub_conditions.size()]
		ConditionResource.ConditionType.CHECK_SYNCHRONIZER:
			var check_name = condition.CheckType.keys()[condition.check_type].replace("_", " ").capitalize()
			return "SYNC:\n%s" % check_name
		_:
			return "Unknown Condition"

func add_condition(payload: Dictionary) -> void:
	if payload.has("condition_instance"):
		var condition_instance = payload.get("condition_instance")
		var index = payload.get("index", -1)
		if is_instance_valid(condition_instance):
			if index > -1 and index <= conditions.size():
				conditions.insert(index, condition_instance)
			else:
				conditions.append(condition_instance)
			return
	
	var new_condition = QWConstants.ConditionResourceScript.new()
	conditions.append(new_condition)

func remove_condition(payload: Dictionary) -> void:
	if payload.has("condition"):
		var condition_instance = payload.get("condition")
		if conditions.has(condition_instance):
			conditions.erase(condition_instance)
			return

	if payload.has("index"):
		var index = payload.get("index")
		if index >= 0 and index < conditions.size():
			conditions.remove_at(index)

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["operator"] = self.operator
	var conditions_data = []
	for c in self.conditions:
		if is_instance_valid(c): conditions_data.append(c.to_dictionary())
	data["conditions"] = conditions_data
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.operator = data.get("operator", LogicOperator.AND)
	self.conditions.clear()
	for c_data in data.get("conditions", []):
		var script = load(c_data.get("@script_path"))
		if script:
			var new_c = script.new()
			new_c.from_dictionary(c_data)
			self.conditions.append(new_c)
