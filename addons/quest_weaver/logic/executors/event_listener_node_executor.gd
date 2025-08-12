# res://addons/quest_weaver/logic/executors/event_listener_node_executor.gd
class_name EventListenerNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var listener_node = node as EventListenerNodeResource
	if not is_instance_valid(listener_node):
		push_error("EventListenerNodeExecutor: The provided node is not an EventListenerNodeResource.")
		context.quest_controller.complete_node(node)
		return

	var controller = context.quest_controller
	var logger = QuestWeaverServices.logger
	if not is_instance_valid(logger): return
	
	var activated_on_port = 0
	if node.has_meta("activated_on_port_hack"):
		activated_on_port = node.get_meta("activated_on_port_hack")


	if activated_on_port == 0:
		logger.log("Flow", "Executing EventListenerNode '%s': Waiting for event '%s'." % [listener_node.id, listener_node.event_name])
		listener_node.status = GraphNodeResource.Status.ACTIVE
		
		if is_instance_valid(controller._event_manager):
			controller._event_manager.register_listener(listener_node)
		else:
			logger.warn("Flow", "EventListenerNode: QuestEventManager not found in controller.")
	
	elif activated_on_port == 1:
		logger.log("Flow", "Executing EventListenerNode '%s': Received CANCEL signal." % listener_node.id)
		if is_instance_valid(controller._event_manager):
			controller._event_manager.unregister_listener(listener_node)
			
		controller._trigger_next_nodes_from_port(listener_node, 1)
		controller._mark_node_as_logically_complete(listener_node)
