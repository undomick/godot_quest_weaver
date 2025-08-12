# res://addons/quest_weaver/logic/executors/set_variable_node_executor.gd
class_name SetVariableNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var var_node = node as SetVariableNodeResource
	if not is_instance_valid(var_node): return
	
	var controller = context.quest_controller
	var game_state = context.game_state
	
	var logger = QuestWeaverServices.logger
	if not is_instance_valid(logger): return
	
	if var_node.variable_name.is_empty() or not is_instance_valid(game_state):
		logger.warn("Executor", "SetVariableNode: variable_name ist leer oder GameState nicht gefunden.")
		controller.complete_node(var_node)
		return
	
	var value_to_apply = _get_value_from_string(var_node.value_to_set_string, game_state)
	
	# Wir prüfen auf 'null' nur für Operatoren, die den Wert auch wirklich brauchen.
	if var_node.operator != var_node.Operator.TOGGLE and value_to_apply == null:
		push_error("SetVariableNode '%s': Konnte den Wert für '%s' nicht auflösen." % [var_node.id, var_node.value_to_set_string])
		controller.complete_node(var_node)
		return

	# HIER ERWEITERN WIR DIE MATCH-ANWEISUNG
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
			# Robuste Prüfung: Verhindere Division durch Null
			if value_to_apply == 0:
				push_error("SetVariableNode '%s': Versuch, durch Null zu teilen!" % var_node.id)
			elif typeof(current_value) in [TYPE_INT, TYPE_FLOAT] and typeof(value_to_apply) in [TYPE_INT, TYPE_FLOAT]:
				game_state.set_variable(var_node.variable_name, current_value / float(value_to_apply))
		
		var_node.Operator.TOGGLE:
			# Robuste Prüfung: TOGGLE funktioniert nur sinnvoll mit Booleans
			var current_value = game_state.get_variable(var_node.variable_name, false)
			if typeof(current_value) == TYPE_BOOL:
				game_state.set_variable(var_node.variable_name, not current_value)
			else:
				logger.warn("Executor", "SetVariableNode '%s': TOGGLE-Operator kann nur auf Boolean-Werte angewendet werden." % var_node.id)
	
	controller.complete_node(var_node)

# Diese Funktion analysiert einen String und gibt entweder den geparsten statischen
# Wert oder den Wert einer referenzierten Variable aus dem GameState zurück.
func _get_value_from_string(text: String, game_state) -> Variant:
	# Fall 1: Der String beginnt mit '$'. Es ist ein dynamischer Verweis.
	if text.begins_with("$"):
		# Entferne das '$'-Zeichen, um den reinen Variablennamen zu erhalten.
		var referenced_var_name = text.trim_prefix("$")
		
		# Prüfe, ob die Variable im GameState existiert.
		if game_state.has_variable(referenced_var_name):
			# Wenn ja, gib ihren Wert zurück.
			return game_state.get_variable(referenced_var_name)
		else:
			# Wenn nicht, gib 'null' zurück, um einen Fehler zu signalisieren.
			return null
			
	# Fall 2: Der String ist statisch. Wir verwenden die alte Parse-Logik.
	else:
		if text.is_valid_int():
			return text.to_int()
		elif text.is_valid_float():
			return text.to_float()
		elif text.to_lower() == "true":
			return true
		elif text.to_lower() == "false":
			return false
		# Wenn alles andere fehlschlägt, ist es ein normaler String.
		return text
