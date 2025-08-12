# res://addons/quest_weaver/logic/quest_state_persistence_manager.gd
class_name QuestStatePersistenceManager
extends Object

## Sammelt den kompletten Zustand des Quest-Systems und packt ihn in ein serialisierbares Dictionary.
func save_state(controller: QuestController) -> Dictionary:
	var save_data := {
		"version": 2, # for data migration in the future
		"active_quests": controller._active_quests.duplicate(true),
		"objective_progress": {},
		"active_timers": controller._timer_manager.get_save_data(),
		"active_listeners": controller._event_manager.get_save_data(),
		"active_synchronizers": controller._sync_manager.get_save_data()
	}

	for node_instance in controller._active_nodes.values():
		if node_instance is TaskNodeResource:
			var obj_progress_dict := {}
			for objective in node_instance.objectives:
				if objective.required_progress > 1 and objective.current_progress > 0:
					obj_progress_dict[objective.id] = objective.current_progress
			
			if not obj_progress_dict.is_empty():
				save_data.objective_progress[node_instance.id] = obj_progress_dict
	
	print("[Persistence] Speicherdaten (v2) erstellt.")
	return save_data

func load_state(controller: QuestController, data: Dictionary) -> void:
	controller.reset_all_graphs_and_quests()
	controller._active_quests = data.get("active_quests", {}).duplicate(true)
	
	var quests_to_restart = []
	for quest_id in controller._active_quests:
		if controller._active_quests[quest_id].status == QWConstants.QWEnums.QuestState.ACTIVE:
			quests_to_restart.append(quest_id)
			
	if quests_to_restart.is_empty():
		print("[Persistence] Wiederherstellung abgeschlossen. Keine aktiven Quests zum Neustarten.")
		return
		
	for quest_id in quests_to_restart:
		if controller._quest_id_to_context_node_map.has(quest_id):
			var context_node: QuestContextNodeResource = controller._quest_id_to_context_node_map[quest_id]
			controller._activate_node(context_node)
		else:
			push_warning("Could not restore quest '%s': Found no ContextNode." % quest_id)
			
	await controller.get_tree().process_frame

	var saved_objective_progress = data.get("objective_progress", {})
	for node_id in saved_objective_progress:
		if controller._active_nodes.has(node_id):
			var node_instance: TaskNodeResource = controller._active_nodes[node_id]
			var progress_data = saved_objective_progress[node_id]
			for objective_id in progress_data:
				for objective in node_instance.objectives:
					if objective.id == objective_id:
						objective.current_progress = progress_data[objective_id]
						break

	controller._timer_manager.load_save_data(data.get("active_timers", {}), controller._active_nodes)
	controller._event_manager.load_save_data(data.get("active_listeners", {}))
	controller._sync_manager.load_save_data(data.get("active_synchronizers", {}))

	for quest_id in controller._active_quests:
		controller.quest_data_changed.emit(quest_id)
	
