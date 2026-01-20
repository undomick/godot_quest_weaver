# res://addons/quest_weaver/systems/managers/quest_state_persistence_manager.gd
class_name QuestStatePersistenceManager
extends RefCounted

const SAVE_VERSION = "1.0"

func save_state(controller: QuestController) -> Dictionary:
	var instances_data: Array[Dictionary] = []
	for instance: QuestInstance in controller._active_instances.values():
		if is_instance_valid(instance):
			instances_data.append(instance.get_save_data())
	
	return {
		"version": SAVE_VERSION,
		"instances": instances_data
	}

func load_state(controller: QuestController, data: Dictionary) -> void:
	var logger = controller._get_logger()
	if logger: logger.log("SaveLoad", "Loading quest state...")

	controller.reset_all_graphs_and_quests()
	
	var instances_data = data.get("instances", [])
	if not instances_data is Array: return

	for inst_data in instances_data:
		# Instanz laden
		var instance = QuestInstance.new("") 
		instance.load_save_data(inst_data)
		
		# Validation: Prüfen ob die Definition existiert
		# Wir nutzen die generische Map im Controller (siehe Controller-Anpassung)
		if not controller._id_to_context_node_map.has(instance.file_id):
			if logger: logger.warn("SaveLoad", "Loaded quest '%s' but no definition found. Skipping." % instance.file_id)
			continue
			
		# Registrieren unter FILE ID
		controller._active_instances[instance.file_id] = instance

	# Restore Runtime Hooks
	if is_instance_valid(controller._timer_manager):
		controller._timer_manager.restore_timers_from_instances(controller._active_instances)
		
	_restore_event_listeners(controller)
	
	# Notify UI
	for file_id in controller._active_instances:
		var inst = controller._active_instances[file_id]
		# Signal mit Logical ID senden (falls vorhanden), sonst File ID
		var signal_id = inst.quest_id if not inst.quest_id.is_empty() else inst.file_id
		controller.quest_data_changed.emit(signal_id)

	if logger: logger.log("SaveLoad", "Load complete. %d quests restored." % controller._active_instances.size())

func _restore_event_listeners(controller: QuestController) -> void:
	var event_manager = controller._event_manager
	if not is_instance_valid(event_manager): return
	
	event_manager.clear()
	
	for instance: QuestInstance in controller._active_instances.values():
		for node_id in instance.active_node_ids:
			var node_def = controller._node_definitions.get(node_id)
			
			if node_def is EventListenerNodeResource:
				event_manager.register_listener(node_def)
			elif node_def is TaskNodeResource:
				_restore_task_listeners(controller, node_def, instance)

func _restore_task_listeners(controller: QuestController, task_node: TaskNodeResource, instance: QuestInstance):
	var context = controller._execution_context
	if not is_instance_valid(context): return
	
	for objective in task_node.objectives:
		if instance.get_objective_status(objective.id) == 2:
			continue
		
		# Resolve Params from Instance Variables (which are already loaded at this point)
		var resolved_params = {}
		for key in objective.trigger_params:
			resolved_params[key] = instance.resolve_parameter(objective.trigger_params[key])

		var wrapper = {
			"objective": objective,
			"file_id": instance.file_id,
			"task_node_id": task_node.id,
			"resolved_params": resolved_params
		}
		
		match objective.trigger_type:
			ObjectiveResource.TriggerType.ITEM_COLLECT:
				var item_id = resolved_params.get("item_id")
				if item_id: _add_listener(context.item_objective_listeners, str(item_id), wrapper)
			
			ObjectiveResource.TriggerType.KILL:
				var enemy_id = resolved_params.get("enemy_id")
				if enemy_id: _add_listener(context.kill_objective_listeners, str(enemy_id), wrapper)
				
			ObjectiveResource.TriggerType.INTERACT:
				var target = resolved_params.get("target_path")
				if target: _add_listener(context.interact_objective_listeners, str(target), wrapper)
				
			ObjectiveResource.TriggerType.LOCATION_ENTER:
				var loc = resolved_params.get("location_id")
				if loc: _add_listener(context.location_objective_listeners, str(loc), wrapper)

func _add_listener(dict: Dictionary, key: String, wrapper: Dictionary):
	if not dict.has(key): dict[key] = []
	# Duplikat-Check vergleicht jetzt Wrapper-Inhalte
	for existing in dict[key]:
		if existing.file_id == wrapper.file_id and existing.objective == wrapper.objective:
			return
	dict[key].append(wrapper)
