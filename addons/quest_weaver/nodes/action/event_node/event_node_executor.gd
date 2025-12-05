# res://addons/quest_weaver/nodes/action/event_node/event_node_executor.gd
class_name EventNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var event_node = node as EventNodeResource
	if not is_instance_valid(event_node):
		push_error("EventNodeExecutor: Node is not a valid EventNodeResource.")
		context.quest_controller.complete_node(node)
		return
	
	var logger = QuestWeaverServices.logger
	if not is_instance_valid(logger): return
	
	# If the event name is empty, we print a warning but still continue the quest flow.
	# This prevents the quest from getting stuck on an unconfigured node.
	if event_node.event_name.is_empty():
		logger.warn("Executor", "Executing EventNode '%s': Event name is empty. Skipping event emission." % event_node.id)
	else:
		logger.log("Executor", "Executing EventNode '%s': Firing event '%s' with payload: %s" % [event_node.id, event_node.event_name, event_node.payload])
		QuestWeaverGlobal.quest_event_fired.emit(event_node.event_name, event_node.payload)
	
	# The node has done its job, so we complete it to continue the quest flow.
	context.quest_controller.complete_node(event_node)
