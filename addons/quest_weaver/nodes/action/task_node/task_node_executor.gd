# res://addons/quest_weaver/nodes/action/task_node/task_node_executor.gd
class_name TaskNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var task_node = node as TaskNodeResource
	if not is_instance_valid(task_node): return

	var controller = context.quest_controller
	var inventory_adapter = controller._inventory_adapter

	task_node.status = GraphNodeResource.Status.ACTIVE
	
	if task_node.objectives.is_empty():
		controller.complete_node(task_node)
		return
	
	_register_objective_listeners(context, task_node)
	
	for objective in task_node.objectives:
		objective.owner_task_node_id = task_node.id
		
		if is_instance_valid(inventory_adapter) and \
		   objective.trigger_type == ObjectiveResource.TriggerType.ITEM_COLLECT and \
		   objective.track_progress_since_activation:
			
			var item_id = objective.trigger_params.get("item_id", "")
			if not item_id.is_empty():
				objective._item_count_on_activation = inventory_adapter.count_item(item_id)
		
		if not objective.status_changed.is_connected(controller._on_objective_in_node_changed):
			objective.status_changed.connect(controller._on_objective_in_node_changed.bind(task_node, objective))
		
		objective.set_status(ObjectiveResource.Status.ACTIVE)
		
	var quest_id = controller.get_quest_id_for_node(task_node.id)
	if not quest_id.is_empty():
		controller.quest_data_changed.emit(quest_id)

func cleanup_listeners(context: ExecutionContext, node: TaskNodeResource):
	if not is_instance_valid(context): return
	
	for objective in node.objectives:
		match objective.trigger_type:
			ObjectiveResource.TriggerType.ITEM_COLLECT:
				var item_id = objective.trigger_params.get("item_id")
				if context.item_objective_listeners.has(item_id):
					context.item_objective_listeners[item_id].erase(objective)
					if context.item_objective_listeners[item_id].is_empty():
						context.item_objective_listeners.erase(item_id)
			
			ObjectiveResource.TriggerType.KILL:
				var enemy_id = objective.trigger_params.get("enemy_id", "")
				if not enemy_id.is_empty() and context.kill_objective_listeners.has(enemy_id):
					context.kill_objective_listeners[enemy_id].erase(objective)
					if context.kill_objective_listeners[enemy_id].is_empty():
						context.kill_objective_listeners.erase(enemy_id)
			
			ObjectiveResource.TriggerType.INTERACT:
				var target_path = objective.trigger_params.get("target_path", "")
				if not target_path.is_empty() and context.interact_objective_listeners.has(target_path):
					context.interact_objective_listeners[target_path].erase(objective)
					if context.interact_objective_listeners[target_path].is_empty():
						context.interact_objective_listeners.erase(target_path)
			
			ObjectiveResource.TriggerType.LOCATION_ENTER:
				var loc_id = objective.trigger_params.get("location_id", "")
				if not loc_id.is_empty() and context.location_objective_listeners.has(loc_id):
					context.location_objective_listeners[loc_id].erase(objective)
					if context.location_objective_listeners[loc_id].is_empty():
						context.location_objective_listeners.erase(loc_id)

func _register_objective_listeners(context: ExecutionContext, node: TaskNodeResource):
	for objective in node.objectives:
		if objective.status == ObjectiveResource.Status.COMPLETED:
			continue
			
		match objective.trigger_type:
			ObjectiveResource.TriggerType.ITEM_COLLECT:
				var item_id = objective.trigger_params.get("item_id")
				if not item_id or item_id.is_empty(): continue
				
				if not context.item_objective_listeners.has(item_id):
					context.item_objective_listeners[item_id] = []
				context.item_objective_listeners[item_id].append(objective)

			ObjectiveResource.TriggerType.KILL:
				var enemy_id = objective.trigger_params.get("enemy_id", "")
				if enemy_id.is_empty(): continue
				
				if not context.kill_objective_listeners.has(enemy_id):
					context.kill_objective_listeners[enemy_id] = []
				context.kill_objective_listeners[enemy_id].append(objective)

			ObjectiveResource.TriggerType.INTERACT:
				var target_path = objective.trigger_params.get("target_path", "")
				if target_path.is_empty(): continue
				
				if not context.interact_objective_listeners.has(target_path):
					context.interact_objective_listeners[target_path] = []
				context.interact_objective_listeners[target_path].append(objective)

			ObjectiveResource.TriggerType.LOCATION_ENTER:
				var loc_id = objective.trigger_params.get("location_id", "")
				if loc_id.is_empty(): continue
				
				if not context.location_objective_listeners.has(loc_id):
					context.location_objective_listeners[loc_id] = []
				context.location_objective_listeners[loc_id].append(objective)
