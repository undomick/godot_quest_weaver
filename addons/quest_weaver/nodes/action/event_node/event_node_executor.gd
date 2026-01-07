# res://addons/quest_weaver/nodes/action/event_node/event_node_executor.gd
class_name EventNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var event_node = node as EventNodeResource
	if not is_instance_valid(event_node):
		push_error("EventNodeExecutor: Node is not a valid EventNodeResource.")
		context.quest_controller.complete_node(node)
		return
	
	var logger = context.logger
	var runtime_payload = event_node.get_runtime_payload()
	
	if event_node.event_name.is_empty():
		if is_instance_valid(logger):
			logger.warn("Executor", "Executing EventNode '%s': Event name is empty. Skipping event emission." % event_node.id)
	else:
		if is_instance_valid(logger):
			logger.log("Executor", "Executing EventNode '%s': Firing event '%s' with payload: %s" % [event_node.id, event_node.event_name, runtime_payload])
		
		if is_instance_valid(context.services):
			var root = context.services.get_tree().get_root()
			if is_instance_valid(root):
				var global_bus = root.get_node_or_null("QuestWeaverGlobal")
				if is_instance_valid(global_bus):
					global_bus.quest_event_fired.emit(event_node.event_name, runtime_payload)
	
	context.quest_controller.complete_node(event_node)
