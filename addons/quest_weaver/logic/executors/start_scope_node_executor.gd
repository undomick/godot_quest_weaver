# res://addons/quest_weaver/logic/executors/start_scope_node_executor.gd
class_name StartScopeNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var scope_node = node as StartScopeNodeResource
	if not is_instance_valid(scope_node): return

	var controller = context.quest_controller

	# Prüfe, ob das Limit erreicht ist. 0 bedeutet unendlich.
	var limit_reached = (scope_node.max_executions > 0 and \
						 scope_node.current_executions >= scope_node.max_executions)

	if limit_reached:
		print("Executing StartScopeNode '%s': Max executions (%d) reached." % [scope_node.id, scope_node.max_executions])
		# Feuere den "On Max Reached"-Ausgang (Port 1)
		controller._trigger_next_nodes_from_port(scope_node, 1)
		# Wichtig: Markiere den Knoten als logisch abgeschlossen, auch wenn er fehlschlägt.
		controller._mark_node_as_logically_complete(scope_node)
	else:
		# Zähle den Ausführungszähler hoch.
		scope_node.current_executions += 1
		print("Executing StartScopeNode '%s': Entering scope '%s'. (Execution #%d)" % [scope_node.id, scope_node.scope_id, scope_node.current_executions])
		# Schließe den Knoten normal ab und feuere den "On Start"-Ausgang (Port 0).
		controller.complete_node(scope_node)
