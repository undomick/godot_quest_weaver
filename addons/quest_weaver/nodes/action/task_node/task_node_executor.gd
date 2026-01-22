class_name TaskNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource, instance: QuestInstance) -> void:
	var task_node = node as TaskNodeResource
	if not is_instance_valid(task_node): return

	var controller = context.quest_controller
	var inventory_adapter = controller._inventory_adapter
	var logger = context.logger

	if task_node.objectives.is_empty():
		if logger: logger.warn("Executor", "TaskNode '%s' has no objectives. Completing immediately." % task_node.id)
		controller.complete_node(task_node)
		return
	
	if logger: 
		logger.log("Executor", "TaskNode '%s': Activating %d objectives in instance '%s'." % [task_node.id, task_node.objectives.size(), instance.file_id])

	# 1. Register global listeners (Kill, Interact, Location, etc.)
	# Now using the static helper to avoid redundancy with PersistenceManager
	TaskNodeExecutor.register_listeners(context, task_node, instance)
	
	# 2. Initialize runtime state in the Instance
	for objective in task_node.objectives:
		if instance.get_objective_status(objective.id) == 2: # 2 = COMPLETED
			continue
			
		instance.set_objective_status(objective.id, 1) 
		
		var resolved_desc = instance.resolve_text(objective.description)
		if resolved_desc != objective.description:
			instance.set_objective_description_override(objective.id, resolved_desc)
		
		if is_instance_valid(inventory_adapter) and \
		   objective.trigger_type == ObjectiveResource.TriggerType.ITEM_COLLECT and \
		   objective.track_progress_since_activation:
			
			var item_id = objective.trigger_params.get("item_id", "")
			if not item_id.is_empty():
				var current_amount = inventory_adapter.count_item(item_id)
				var snapshot_key = "start_amount_%s" % objective.id
				instance.set_node_data(task_node.id, snapshot_key, current_amount)
				
				if logger:
					logger.log("Inventory", "  - Snapshot for '%s': Player has %d. Tracking starts from here." % [item_id, current_amount])
		
	var signal_id = instance.quest_id if not instance.quest_id.is_empty() else instance.file_id
	controller.quest_data_changed.emit(signal_id)

func cleanup_listeners(context: ExecutionContext, node: TaskNodeResource):
	if not is_instance_valid(context): return
	
	for objective in node.objectives:
		match objective.trigger_type:
			ObjectiveResource.TriggerType.ITEM_COLLECT:
				var item_id = objective.trigger_params.get("item_id")
				if item_id: _remove_listener_wrapper(context.item_objective_listeners, str(item_id), objective)
			
			ObjectiveResource.TriggerType.KILL:
				var enemy_id = objective.trigger_params.get("enemy_id", "")
				if enemy_id: _remove_listener_wrapper(context.kill_objective_listeners, str(enemy_id), objective)
			
			ObjectiveResource.TriggerType.INTERACT:
				var target_path = objective.trigger_params.get("target_path", "")
				if target_path: _remove_listener_wrapper(context.interact_objective_listeners, str(target_path), objective)
			
			ObjectiveResource.TriggerType.LOCATION_ENTER:
				var loc_id = objective.trigger_params.get("location_id", "")
				if loc_id: _remove_listener_wrapper(context.location_objective_listeners, str(loc_id), objective)

# --- STATIC HELPER FOR REGISTRATION ---

static func register_listeners(context: ExecutionContext, node: TaskNodeResource, instance: QuestInstance):
	if not is_instance_valid(context): return

	for objective in node.objectives:
		# SKIP if already completed (Essential for Savegame Loading)
		if instance.get_objective_status(objective.id) == 2: # 2 = COMPLETED
			continue
		
		# 1. Resolve Parameters immediately using the instance
		var resolved_params = {}
		for key in objective.trigger_params:
			var raw_val = objective.trigger_params[key]
			resolved_params[key] = instance.resolve_parameter(raw_val)
		
		# 2. Store in Wrapper
		var wrapper = {
			"objective": objective,
			"file_id": instance.file_id,
			"task_node_id": node.id,
			"resolved_params": resolved_params
		}
		
		# 3. Register using RESOLVED keys
		match objective.trigger_type:
			ObjectiveResource.TriggerType.ITEM_COLLECT:
				var item_id = resolved_params.get("item_id")
				if item_id and not str(item_id).is_empty():
					_add_listener_static(context.item_objective_listeners, str(item_id), wrapper)

			ObjectiveResource.TriggerType.KILL:
				var enemy_id = resolved_params.get("enemy_id")
				if enemy_id and not str(enemy_id).is_empty():
					_add_listener_static(context.kill_objective_listeners, str(enemy_id), wrapper)

			ObjectiveResource.TriggerType.INTERACT:
				var target_path = resolved_params.get("target_path")
				if target_path and not str(target_path).is_empty():
					_add_listener_static(context.interact_objective_listeners, str(target_path), wrapper)

			ObjectiveResource.TriggerType.LOCATION_ENTER:
				var loc_id = resolved_params.get("location_id")
				if loc_id and not str(loc_id).is_empty():
					_add_listener_static(context.location_objective_listeners, str(loc_id), wrapper)

static func _add_listener_static(dict: Dictionary, key: String, wrapper: Dictionary):
	if not dict.has(key): dict[key] = []
	# Avoid duplicates based on file_id and objective reference
	for existing in dict[key]:
		if existing.file_id == wrapper.file_id and existing.objective == wrapper.objective:
			return
	dict[key].append(wrapper)

# --- INSTANCE HELPER FOR CLEANUP ---

func _remove_listener_wrapper(dict: Dictionary, key: String, objective: ObjectiveResource):
	if not dict.has(key): return
	var list = dict[key]
	for i in range(list.size() - 1, -1, -1):
		if list[i].objective == objective:
			list.remove_at(i)
	
	if list.is_empty():
		dict.erase(key)
