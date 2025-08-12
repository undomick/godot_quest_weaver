# res://addons/quest_weaver/ui/conditions/condition_resource.gd
@tool
class_name ConditionResource
extends Resource

const ExecutionContext = preload("res://addons/quest_weaver/logic/execution_context.gd")

enum QuestState { INACTIVE, ACTIVE, COMPLETED, FAILED }
enum ConditionType { 
	BOOL, CHANCE, CHECK_ITEM, CHECK_QUEST_STATUS, CHECK_VARIABLE, CHECK_SYNCHRONIZER,
	CHECK_OBJECTIVE_STATUS, COMPOUND
}
@export var type: ConditionType = ConditionType.BOOL

# --- BoolCondition ---
@export var is_true: bool = true

# --- ChanceCondition ---
@export_range(0.0, 100.0, 0.1, "suffix:%") var chance_percentage: float = 50.0

# --- CheckItemCondition ---
@export var item_id: String = ""
@export var amount: int = 1

# --- CheckQuestStatusCondition ---
@export var quest_id: String = ""
@export var expected_status: QWConstants.QWEnums.QuestState = QWConstants.QWEnums.QuestState.COMPLETED

# --- CheckVariableCondition ---
@export var variable_name: String = ""
@export var expected_value_string: String = ""
enum Operator { EQUALS, NOT_EQUALS, GREATER_THAN, LESS_THAN, GREATER_OR_EQUAL, LESS_OR_EQUAL }
@export var operator: Operator = Operator.EQUALS

# --- CheckSynchronizerCondition ---
enum CheckType { RECEIVED_N_INPUTS, RECEIVED_SPECIFIC_INPUT }
@export var check_type: CheckType = CheckType.RECEIVED_N_INPUTS
@export var sync_value: int = 1

# --- CheckObjectiveStatusCondition ---
@export var objective_id: String = ""
@export var expected_objective_status: ObjectiveResource.Status = ObjectiveResource.Status.COMPLETED

# --- CompoundCondition ---
enum LogicOperator { AND, OR }
@export var logic_operator: LogicOperator = LogicOperator.AND
@export var sub_conditions: Array[ConditionResource] = []


func check(context: Variant) -> bool:
	if context is ExecutionContext:
		var exec_context = context as ExecutionContext
		match type:
			ConditionType.BOOL:
				return is_true
				
			ConditionType.CHANCE:
				return randf() < (chance_percentage / 100.0)
				
			ConditionType.CHECK_ITEM:
				var adapter = exec_context.quest_controller._inventory_adapter
				if not is_instance_valid(adapter) or item_id.is_empty():
					return false
				
				# Wir rufen direkt die check_item-Funktion des Adapters auf.
				return adapter.check_item(item_id, amount)
				
			ConditionType.CHECK_QUEST_STATUS:
				if quest_id.is_empty() or not is_instance_valid(exec_context.quest_controller):
					return false
				
				var quest_data = exec_context.quest_controller.get_quest_data(quest_id)
				if quest_data.is_empty():
					return expected_status == QWConstants.QWEnums.QuestState.INACTIVE
				
				return quest_data.get("status", QWConstants.QWEnums.QuestState.INACTIVE) == expected_status
				
			ConditionType.CHECK_VARIABLE:
				# Diese Bedingung kann in beiden Kontexten funktionieren, daher prüfen wir hier.
				if variable_name.is_empty() or not is_instance_valid(exec_context.game_state): return false
				var actual_value = exec_context.game_state.get_variable(variable_name)
				return _compare_values(actual_value, expected_value_string)
				
			ConditionType.CHECK_OBJECTIVE_STATUS:
				if objective_id.is_empty() or not is_instance_valid(exec_context.quest_controller):
					return false
				
				# Wir rufen die neue API-Funktion im Controller auf.
				var actual_status = exec_context.quest_controller.get_objective_status(objective_id)
				return actual_status == expected_objective_status
				
			ConditionType.COMPOUND:
				if sub_conditions.is_empty(): return logic_operator == LogicOperator.AND
				match logic_operator:
					LogicOperator.AND:
						for condition in sub_conditions:
							if not is_instance_valid(condition) or not condition.check(exec_context): return false
						return true
					LogicOperator.OR:
						for condition in sub_conditions:
							if is_instance_valid(condition) and condition.check(exec_context): return true
						return false
		# Wenn der Typ hier nicht behandelt wird, gib false zurück.
		return false

	# Fall 2: Wir bekommen ein Dictionary (vom EventListenerNode).
	elif context is Dictionary:
		var payload = context as Dictionary
		match type:
			ConditionType.CHECK_SYNCHRONIZER:
				if not payload.has("sync_inputs_received_array"): return false
				var received_array: Array = payload["sync_inputs_received_array"]
				match check_type:
					CheckType.RECEIVED_N_INPUTS:
						return received_array.count(true) >= sync_value
					CheckType.RECEIVED_SPECIFIC_INPUT:
						return sync_value >= 0 and sync_value < received_array.size() and received_array[sync_value]
				return false
				
			ConditionType.CHECK_VARIABLE:
				if variable_name.is_empty() or not payload.has(variable_name):
					return false
				var actual_value = payload[variable_name]
				return _compare_values(actual_value, expected_value_string)
				
			ConditionType.COMPOUND:
				# Wir können auch verschachtelte Bedingungen mit der Payload prüfen.
				if sub_conditions.is_empty(): return logic_operator == LogicOperator.AND
				match logic_operator:
					LogicOperator.AND:
						for condition in sub_conditions:
							if not is_instance_valid(condition) or not condition.check(payload): return false
						return true
					LogicOperator.OR:
						for condition in sub_conditions:
							if is_instance_valid(condition) and condition.check(payload): return true
						return false
			_:
				# Andere Bedingungen wie CHECK_ITEM machen ohne Spiel-Kontext keinen Sinn.
				push_warning("Condition-Typ '%s' kann nicht auf einer Event-Payload ausgeführt werden." % ConditionType.keys()[type])
				return false

	# Wenn der Kontext weder ExecutionContext noch Dictionary ist, ist er ungültig.
	return false

func _compare_values(actual_value: Variant, expected_value_str: String) -> bool:
	if actual_value == null: return false
	
	var expected_value: Variant = _parse_string_to_variant(expected_value_str)
	
	if typeof(actual_value) != typeof(expected_value):
		if not (actual_value is float and expected_value is int) and \
		   not (actual_value is int and expected_value is float):
			return false
			
	match operator:
		Operator.EQUALS: return actual_value == expected_value
		Operator.NOT_EQUALS: return actual_value != expected_value
		Operator.GREATER_THAN: return actual_value > expected_value
		Operator.LESS_THAN: return actual_value < expected_value
		Operator.GREATER_OR_EQUAL: return actual_value >= expected_value
		Operator.LESS_OR_EQUAL: return actual_value <= expected_value
		
	return false

func _parse_string_to_variant(text: String) -> Variant:
	var parsed_value: Variant = text
	if text.is_valid_int(): parsed_value = text.to_int()
	elif text.is_valid_float(): parsed_value = text.to_float()
	elif text.to_lower() == "true": parsed_value = true
	elif text.to_lower() == "false": parsed_value = false
	return parsed_value

# ======================================================
# SERIALIZATION
# ======================================================

func to_dictionary() -> Dictionary:
	var sub_conditions_data = []
	for sub_cond in sub_conditions:
		if is_instance_valid(sub_cond):
			sub_conditions_data.append(sub_cond.to_dictionary())
	
	return {
		"@script_path": get_script().resource_path,
		"type": self.type, "is_true": self.is_true,
		"chance_percentage": self.chance_percentage, "item_id": self.item_id,
		"amount": self.amount, "quest_id": self.quest_id,
		"expected_status": self.expected_status, "variable_name": self.variable_name,
		"expected_value_string": self.expected_value_string, "operator": self.operator,
		"check_type": self.check_type, "sync_value": self.sync_value,
		"logic_operator": self.logic_operator, "objective_id": self.objective_id,
		"expected_objective_status": self.expected_objective_status, 
		"sub_conditions": sub_conditions_data,
	}

func from_dictionary(data: Dictionary):
	self.type = data.get("type", ConditionType.BOOL)
	self.is_true = data.get("is_true", true)
	self.chance_percentage = data.get("chance_percentage", 50.0)
	self.item_id = data.get("item_id", "")
	self.amount = data.get("amount", 1)
	self.quest_id = data.get("quest_id", "")
	self.expected_status = data.get("expected_status", QWConstants.QWEnums.QuestState.COMPLETED)
	self.variable_name = data.get("variable_name", "")
	self.expected_value_string = data.get("expected_value_string", "")
	self.operator = data.get("operator", Operator.EQUALS)
	self.check_type = data.get("check_type", CheckType.RECEIVED_N_INPUTS)
	self.sync_value = data.get("sync_value", 1)
	self.objective_id = data.get("objective_id", "")
	self.expected_objective_status = data.get("expected_objective_status", ObjectiveResource.Status.COMPLETED)
	self.logic_operator = data.get("logic_operator", LogicOperator.AND)
	
	self.sub_conditions.clear()
	var sub_conditions_data = data.get("sub_conditions", [])
	for sub_cond_dict in sub_conditions_data:
		var script_path = sub_cond_dict.get("@script_path")
		if script_path and ResourceLoader.exists(script_path):
			var new_sub_cond = load(script_path).new()
			new_sub_cond.from_dictionary(sub_cond_dict)
			self.sub_conditions.append(new_sub_cond)
