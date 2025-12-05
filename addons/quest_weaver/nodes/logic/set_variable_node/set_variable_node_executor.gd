# res://addons/quest_weaver/nodes/logic/set_variable_node/set_variable_node_executor.gd
class_name SetVariableNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var var_node = node as SetVariableNodeResource
	if not is_instance_valid(var_node): return
	
	var controller = context.quest_controller
	var game_state = context.game_state
	
	# Safe logger lookup to avoid static dependency issues
	var logger = null
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.root:
		var services = main_loop.root.get_node_or_null("QuestWeaverServices")
		if is_instance_valid(services):
			logger = services.logger
	
	if var_node.variable_name.is_empty() or not is_instance_valid(game_state):
		if logger:
			logger.warn("Executor", "SetVariableNode: variable_name is empty or GameState not found.")
		controller.complete_node(var_node)
		return
	
	var value_to_apply = _get_value_from_string(var_node.value_to_set_string, game_state)
	
	# Only check for 'null' if the operator actually requires a value (Toggle does not).
	if var_node.operator != var_node.Operator.TOGGLE and value_to_apply == null:
		push_error("SetVariableNode '%s': Could not resolve value for '%s'." % [var_node.id, var_node.value_to_set_string])
		controller.complete_node(var_node)
		return

	match var_node.operator:
		var_node.Operator.SET:
			game_state.set_variable(var_node.variable_name, value_to_apply)
		
		var_node.Operator.ADD:
			var current_value = game_state.get_variable(var_node.variable_name, 0)
			if typeof(current_value) in [TYPE_INT, TYPE_FLOAT] and typeof(value_to_apply) in [TYPE_INT, TYPE_FLOAT]:
				game_state.set_variable(var_node.variable_name, current_value + value_to_apply)
		
		var_node.Operator.SUBTRACT:
			var current_value = game_state.get_variable(var_node.variable_name, 0)
			if typeof(current_value) in [TYPE_INT, TYPE_FLOAT] and typeof(value_to_apply) in [TYPE_INT, TYPE_FLOAT]:
				game_state.set_variable(var_node.variable_name, current_value - value_to_apply)
		
		var_node.Operator.MULTIPLY:
			var current_value = game_state.get_variable(var_node.variable_name, 1)
			if typeof(current_value) in [TYPE_INT, TYPE_FLOAT] and typeof(value_to_apply) in [TYPE_INT, TYPE_FLOAT]:
				game_state.set_variable(var_node.variable_name, current_value * value_to_apply)
		
		var_node.Operator.DIVIDE:
			var current_value = game_state.get_variable(var_node.variable_name, 1)
			# Robust check: Prevent division by zero
			if value_to_apply == 0:
				push_error("SetVariableNode '%s': Attempted division by zero!" % var_node.id)
			elif typeof(current_value) in [TYPE_INT, TYPE_FLOAT] and typeof(value_to_apply) in [TYPE_INT, TYPE_FLOAT]:
				game_state.set_variable(var_node.variable_name, current_value / float(value_to_apply))
		
		var_node.Operator.TOGGLE:
			# Robust check: TOGGLE only works with Booleans
			var current_value = game_state.get_variable(var_node.variable_name, false)
			if typeof(current_value) == TYPE_BOOL:
				game_state.set_variable(var_node.variable_name, not current_value)
			else:
				if logger:
					logger.warn("Executor", "SetVariableNode '%s': TOGGLE operator can only be applied to boolean values." % var_node.id)
	
	controller.complete_node(var_node)

# Parses a string to return either a static value or a variable from GameState.
func _get_value_from_string(text: String, game_state) -> Variant:
	# Case 1: Dynamic reference (Starts with '$')
	if text.begins_with("$"):
		var referenced_var_name = text.trim_prefix("$")
		
		if game_state.has_variable(referenced_var_name):
			return game_state.get_variable(referenced_var_name)
		else:
			return null # Variable not found
			
	# Case 2: Static value parsing
	else:
		if text.is_valid_int():
			return text.to_int()
		elif text.is_valid_float():
			return text.to_float()
		elif text.to_lower() == "true":
			return true
		elif text.to_lower() == "false":
			return false
		
		# Default: Return as string
		return text
