# res://addons/quest_weaver/nodes/flow/timer_node/timer_node_executor.gd
class_name TimerNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var timer_node = node as TimerNodeResource
	if not is_instance_valid(timer_node): return
	
	var controller = context.quest_controller
	var logger = context.logger
			
	if not is_instance_valid(logger): return
	
	logger.log("Flow", "Executing TimerNode '%s': Starting %d second timer." % [timer_node.id, timer_node.duration])
	timer_node.status = GraphNodeResource.Status.ACTIVE
	
	if controller.has_method("start_quest_timer"):
		controller._timer_manager.start_timer(timer_node)
	else:
		logger.warn("Flow", "TimerNode: QuestController hat keine Methode 'start_quest_timer'. Breche ab.")
		controller.complete_node(timer_node)
