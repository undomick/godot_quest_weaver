# res://addons/quest_weaver/logic/quest_controller.gd
class_name QuestController
extends Node

# --- SIGNALS ---
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)
signal quest_data_changed(quest_id: String) # For title, desc, log changes

# --- MANAGER INSTANCES ---
var _timer_manager: QuestTimerManager
var _sync_manager: QuestSyncManager
var _event_manager: QuestEventManager
var _persistence_manager: QuestStatePersistenceManager
var _execution_context: ExecutionContext
var _inventory_adapter: QuestInventoryAdapterBase = null
var _presentation_manager: PresentationManager
var _logger: QWLogger

# === STATE MANAGEMENT ===
## Maps a graph path to an array of Node IDs within that graph.
## Format: { "res://path/to/graph.quest": ["node_id_1", "node_id_2"] }
var _quest_node_map: Dictionary = {}
## A stack to manage returns from sub-graphs.
## Format: [ { "parent_node_id": "id", "parent_quest_path": "res://..." } ]
var _call_stack: Array[Dictionary] = []
# Maps each Node ID to the ID of its parent QuestContext node.
var _node_to_context_map: Dictionary = {}
# Maps a Quest ID directly to the node that defines it.
var _quest_id_to_context_node_map: Dictionary = {}
# Stores the runtime state of each active quest.
var _active_quests: Dictionary = {} # Format: { "quest_id": { "status": int, "title": "", ... } }
# Stores the blueprints of all nodes from all graphs. { "node_id": GraphNodeResource }
var _node_definitions: Dictionary = {}
# Stores the connections originating from a node. { "from_node_id": [connection_dict, ...] }
var _node_connections: Dictionary = {}
# Stores the runtime instances of active nodes. { "node_id": GraphNodeResource (copy) }
var _active_nodes: Dictionary = {}
# Stores the completed nodes in case of a reset.
var _completed_nodes: Dictionary = {}
# Registers the available executor scripts.
var _executors: Dictionary = {}
# Reference to the NodeTypeRegistry for displaying names etc.
var _node_registry: NodeTypeRegistry


func _ready() -> void:
	await get_tree().process_frame
	QuestWeaverServices.register_quest_controller(self)
	_initialize_dependencies_and_start()

func _initialize_dependencies_and_start() -> void:
	_initialize_managers()
	_register_executors()
	_initialize_inventory_adapter()
	_initialize_quest_graphs()
	_connect_global_signals()
	start_all_loaded_graphs()

# --- CORE INITIALIZATION ---

func _initialize_managers():
	_persistence_manager = QuestStatePersistenceManager.new()
	_timer_manager = QuestTimerManager.new(self)
	_sync_manager = QuestSyncManager.new(self)
	_event_manager = QuestEventManager.new(self)
	
	_logger = QWLogger.new()
	_logger.initialize()
	QuestWeaverServices.register_logger(_logger)
	
	_presentation_manager = PresentationManager.new()
	_presentation_manager.name = "PresentationManager"
	add_child(_presentation_manager)
	QuestWeaverServices.register_presentation_manager(_presentation_manager)

func _register_executors():
	_node_registry = ResourceLoader.load(QWConstants.Settings.node_type_registry_path)
	if not is_instance_valid(_node_registry):
		push_error("QuestController: Could not load NodeTypeRegistry!")
		return
	
	for type_info in _node_registry.node_types:
		if not is_instance_valid(type_info) or not is_instance_valid(type_info.node_script):
			continue
		var script_path = type_info.node_script.resource_path
		if script_path.is_empty(): continue
		var executor_script = null
		if not type_info.executor_script_path.is_empty() and ResourceLoader.exists(type_info.executor_script_path):
			executor_script = load(type_info.executor_script_path)
		_executors[script_path] = executor_script.new() if is_instance_valid(executor_script) else NodeExecutor.new()

func _initialize_quest_graphs() -> void:
	var logger = QuestWeaverServices.logger
	if not is_instance_valid(logger): return

	logger.log("Flow", "Initializing quest graphs from Editor Session Data...")
	
	if not is_instance_valid(QWConstants.Settings):
		push_error("[QuestController] CRITICAL: Could not load QuestWeaverSettings.tres.")
		return

	var editor_data_path = QWConstants.Settings.editor_data_path
	if editor_data_path.is_empty() or not ResourceLoader.exists(editor_data_path):
		push_error("[QuestController] CRITICAL: 'editor_data_path' is not set or is invalid in QuestWeaverSettings.tres.")
		return

	var editor_data: QuestEditorData = ResourceLoader.load(editor_data_path, "QuestEditorData", ResourceLoader.CACHE_MODE_REPLACE)
	if not is_instance_valid(editor_data):
		push_error("[QuestController] CRITICAL: Could not load QuestEditorData from path: '%s'" % editor_data_path)
		return

	var paths_to_load: Array[String] = editor_data.open_files
	
	if paths_to_load.is_empty():
		logger.warn("Flow", "No quests are listed in the 'open_files' array. No quests will be loaded.")
	else:
		logger.log("Flow", "Found %d quest(s) listed in 'open_files' to load." % paths_to_load.size())

	for graph_path in paths_to_load:
		if graph_path.is_empty() or not FileAccess.file_exists(graph_path):
			push_warning("[QuestController] Skipped loading: File path '%s' from open_files does not exist." % graph_path)
			continue
		
		var file = FileAccess.open(graph_path, FileAccess.READ)
		if file == null:
			push_error("[QuestController] Failed to open file for manual loading: '%s'" % graph_path)
			continue
			
		var graph_data_dictionary: Dictionary = file.get_var(true)
		file.close()

		if not graph_data_dictionary is Dictionary:
			push_error("[QuestController] Invalid data format in quest file: '%s'" % graph_path)
			continue
			
		var graph_res = QuestGraphResource.new()
		graph_res.from_dictionary(graph_data_dictionary)
		
		if is_instance_valid(graph_res):

			graph_res.resource_path = graph_path 
			_load_graph_data(graph_res)

	logger.log("Flow", "Building context map...")
	_build_node_to_context_map()
	logger.log("Flow", "Initialization complete.")

func _initialize_inventory_adapter():
	var logger = QuestWeaverServices.logger
	var adapter_path = QWConstants.Settings.inventory_adapter_script
	
	if adapter_path and not adapter_path.is_empty() and ResourceLoader.exists(adapter_path):
		var adapter_script = load(adapter_path)
		if is_instance_valid(adapter_script):
			_inventory_adapter = adapter_script.new()
			# The adapter itself is responsible for connecting to any necessary game systems.
			_inventory_adapter.initialize()
			_inventory_adapter.inventory_updated.connect(_check_item_collect_objectives)
			if is_instance_valid(logger):
				logger.log("Inventory", "Inventory Adapter initialized and connected successfully.")
		else:
			push_error("QuestController: The assigned adapter script could not be instantiated.")
	elif is_instance_valid(logger):
		logger.warn("Inventory", "No Inventory Adapter configured. Item-related quests will not function.")

func _connect_global_signals() -> void:
	var logger = QuestWeaverServices.logger
	var event_bus = get_tree().root.get_node("QuestWeaverGlobal")
	
	if is_instance_valid(logger):
		logger.log("Flow", "Attempting to connect global signals. Found event_bus: %s" % is_instance_valid(event_bus))
	
	if not is_instance_valid(event_bus):
		push_warning("[QuestController] QuestWeaverGlobal Singleton could not be found via SceneTree. This is a critical issue.")
		return

	# The rest of the connections remain the same.
	if not event_bus.quest_event_fired.is_connected(_event_manager.on_global_event):
		event_bus.quest_event_fired.connect(_event_manager.on_global_event)
	if not event_bus.interacted_with_object.is_connected(_on_interacted_with_object):
		event_bus.interacted_with_object.connect(_on_interacted_with_object)
	if not event_bus.enemy_was_killed.is_connected(_on_enemy_was_killed):
		event_bus.enemy_was_killed.connect(_on_enemy_was_killed)
	if not event_bus.entered_location.is_connected(_on_entered_location):
		event_bus.entered_location.connect(_on_entered_location)

# --- PUBLIC API & CORE LOGIC ---

func reset_all_graphs_and_quests():
	var logger = QuestWeaverServices.logger
	if is_instance_valid(logger):
		logger.log("Flow", "Resetting all graphs and quest states.")
	
	_active_nodes.clear()
	_completed_nodes.clear()
	_timer_manager.clear_all_timers()
	_sync_manager.clear()
	_event_manager.clear()
	_active_quests.clear()

## Starts all Graphs, with a StartNode.
func start_all_loaded_graphs():
	_ensure_execution_context_exists()
	for node_id in _node_definitions:
		var node = _node_definitions[node_id]
		if node is StartNodeResource:
			_activate_node(node)

# This Function gets called by QuestContextNodeExecutor.
func start_quest(node_data: QuestContextNodeResource) -> void:
	var logger = QuestWeaverServices.logger
	var quest_id = node_data.quest_id
	if quest_id.is_empty():
		push_error("QuestContextNode '%s' has a missing Quest ID." % node_data.id)
		return
		
	if not _active_quests.has(quest_id):
		_active_quests[quest_id] = {
			"status": QWConstants.QWEnums.QuestState.ACTIVE,
			"title": node_data.quest_title,
			"description": node_data.quest_description,
			"log_entries": [],
			"quest_type": node_data.quest_type
		}
		if is_instance_valid(logger): logger.log("Flow", "Quest '%s' STARTED." % quest_id)
		if not node_data.log_on_start.is_empty():
			_active_quests[quest_id].log_entries.append(node_data.log_on_start)
		
		quest_started.emit(quest_id)
		quest_data_changed.emit(quest_id)
	else:
		push_warning("Attempted to start already active quest '%s'." % quest_id)

func start_sub_graph(graph_path: String):
	if not _quest_node_map.has(graph_path):
		var graph_res = ResourceLoader.load(graph_path)
		if is_instance_valid(graph_res):
			_load_graph_data(graph_res)
		else:
			push_error("QuestController: Could not load sub-graph resource at '%s'." % graph_path)
			return

	var context_node_of_subgraph: QuestContextNodeResource = null
	if _quest_node_map.has(graph_path):
		for node_id in _quest_node_map[graph_path]:
			var node_def = _node_definitions[node_id]
			if node_def is QuestContextNodeResource:
				context_node_of_subgraph = node_def
				break
	
	if is_instance_valid(context_node_of_subgraph):
		_activate_node(context_node_of_subgraph)
	else:
		push_error("QuestController: Sub-graph at '%s' has no QuestContextNode as an entry point." % graph_path)

func push_to_call_stack(parent_node_id: String):
	var parent_graph_path = _get_quest_path_for_node(parent_node_id)
			
	if parent_graph_path.is_empty():
		push_error("QuestController: Could not find parent graph for call stack (Node ID: %s)" % parent_node_id)
		return

	_call_stack.append({
		"parent_node_id": parent_node_id,
		"parent_quest_path": parent_graph_path
	})

func pop_from_call_stack():
	if _call_stack.is_empty(): return
	var return_info = _call_stack.pop_back()
	var parent_node_id = return_info.get("parent_node_id")
	
	var logger = QuestWeaverServices.logger
	if is_instance_valid(logger):
		logger.log("Flow", "Sub-Graph finished. Returning to parent graph at Node '%s'." % parent_node_id)
	
	var parent_subgraph_node = _active_nodes.get(parent_node_id)
	
	if is_instance_valid(parent_subgraph_node):
		complete_node(parent_subgraph_node)
	else:
		push_warning("QuestController: Could not find the calling SubGraphNode '%s' in active nodes to return to." % parent_node_id)

func set_quest_status(quest_id_str: String, action: QuestNodeResource.QuestAction) -> void:
	var logger = QuestWeaverServices.logger
	if quest_id_str.is_empty(): return
	
	if action == QuestNodeResource.QuestAction.START:
		if _active_quests.has(quest_id_str) and _active_quests[quest_id_str].status == QWConstants.QWEnums.QuestState.ACTIVE:
			push_warning("Attempted to start the already active quest '%s' again." % quest_id_str)
			return
		
		if _quest_id_to_context_node_map.has(quest_id_str):
			var context_node_to_start: QuestContextNodeResource = _quest_id_to_context_node_map[quest_id_str]
			if is_instance_valid(logger):
				logger.log("Flow", "Quest '%s' is being started via QuestNode at its ContextNode '%s'." % [quest_id_str, context_node_to_start.id])
			_activate_node(context_node_to_start)
		else:
			push_error("QuestNode could not start quest '%s': No QuestContextNode with this ID found in the project." % quest_id_str)
		return

	if not _active_quests.has(quest_id_str):
		push_warning("Attempted to change the status of an inactive quest ('%s')." % quest_id_str)
		return

	var current_status = _active_quests[quest_id_str].status
	var target_status: QWConstants.QWEnums.QuestState

	match action:
		QuestNodeResource.QuestAction.COMPLETE: target_status = QWConstants.QWEnums.QuestState.COMPLETED
		QuestNodeResource.QuestAction.FAIL: target_status = QWConstants.QWEnums.QuestState.FAILED

	if current_status != target_status:
		_active_quests[quest_id_str].status = target_status
		if is_instance_valid(logger):
			logger.log("Flow", "Status of Quest '%s' set to %s." % [quest_id_str, QWConstants.QWEnums.QuestState.keys()[target_status]])
		if target_status == QWConstants.QWEnums.QuestState.COMPLETED:
			quest_completed.emit(quest_id_str)
		elif target_status == QWConstants.QWEnums.QuestState.FAILED:
			quest_failed.emit(quest_id_str)

func get_objective_status(p_objective_id: String) -> ObjectiveResource.Status:
	if p_objective_id.is_empty():
		return ObjectiveResource.Status.INACTIVE

	for node in _active_nodes.values():
		if node is TaskNodeResource:
			for objective in node.objectives:
				if objective.id == p_objective_id:
					return objective.status
	
	return ObjectiveResource.Status.INACTIVE

func set_quest_description(node_id: String, description: String) -> void:
	var context_quest_id = get_quest_id_for_node(node_id)
	if context_quest_id and _active_quests.has(context_quest_id):
		_active_quests[context_quest_id].description = description
		quest_data_changed.emit(context_quest_id)

func add_quest_log_entry(node_id: String, log_text: String) -> void:
	var context_quest_id = get_quest_id_for_node(node_id)
	if context_quest_id and _active_quests.has(context_quest_id):
		_active_quests[context_quest_id].log_entries.append(log_text)
		quest_data_changed.emit(context_quest_id)

func get_active_quests_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for quest_id in _active_quests:
		if _active_quests[quest_id].status == QWConstants.QWEnums.QuestState.ACTIVE:
			var data = _active_quests[quest_id].duplicate(true)
			data["id"] = quest_id # Füge die ID für die UI hinzu
			result.append(data)
	return result

func get_quest_data(quest_id: String) -> Dictionary:
	if _active_quests.has(quest_id):
		return _active_quests[quest_id]
	return {}

## Gibt die Daten ALLER verwalteten Quests zurück, die nicht mehr INACTIVE sind.
func get_all_managed_quests_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for quest_id in _active_quests:
		if _active_quests[quest_id].status == QWConstants.QWEnums.QuestState.INACTIVE:
			continue

		var data = _active_quests[quest_id].duplicate(true)
		data["id"] = quest_id
		result.append(data)
	
	return result

## Sammelt alle Objectives von allen aktiven TaskNodes, die zu einer bestimmten Quest gehören.
func get_active_objectives_for_quest(quest_id: String) -> Array[ObjectiveResource]:
	var objectives_for_quest: Array[ObjectiveResource] = []
	
	for node in _active_nodes.values():
		if node is TaskNodeResource:
			# Finde heraus, zu welcher Quest dieser TaskNode gehört.
			var node_quest_id = get_quest_id_for_node(node.id)
			
			# Wenn die Quest-ID übereinstimmt, füge seine Objectives zur Ergebnisliste hinzu.
			if node_quest_id == quest_id:
				objectives_for_quest.append_array(node.objectives)
				
	return objectives_for_quest

## Wird von einem Knoten aufgerufen, wenn er seine Aufgabe erledigt hat.
func complete_node(node: GraphNodeResource) -> void:
	var logger = QuestWeaverServices.logger
	if is_instance_valid(logger):
		logger.log("Flow", "  <- Completing Node: '%s'" % [node.id])
	
	node.status = GraphNodeResource.Status.COMPLETED
	
	if node is TaskNodeResource:
		var executor = _executors.get(node.get_script())
		if executor and executor.has_method("cleanup_listeners"):
			executor.cleanup_listeners(_execution_context, node)
	
	_completed_nodes[node.id] = node
	if _active_nodes.has(node.id):
		_active_nodes.erase(node.id)
	
	# By default, use port 0. BranchNode and others handle this manually.
	_trigger_next_nodes_from_port(node, 0)

func complete_manual_objective(objective_id: String):
	var logger = QuestWeaverServices.logger
	if not is_instance_valid(logger): return
	
	for node in _active_nodes.values():
		if node is TaskNodeResource:
			for objective in node.objectives:
				if objective.id == objective_id and objective.trigger_type == ObjectiveResource.TriggerType.MANUAL:
					objective.set_status(ObjectiveResource.Status.COMPLETED)
					logger.log("Executor", "Manual Objective '%s' completed." % objective_id)
					return 
	logger.warn("Executor", "Could not find active, manual Objective with ID '%s'." % objective_id)

func get_save_data() -> Dictionary:
	return _persistence_manager.save_state(self)

func load_from_data(data: Dictionary):
	_persistence_manager.load_state(self, data)

# --- INTERNAL LOGIC & HELPERS ---

func _activate_node(node_definition: GraphNodeResource, from_input_port: int = 0) -> void:
	var logger = QuestWeaverServices.logger
	if not is_instance_valid(logger): return

	logger.log("Flow", ">>> Attempting to activate Node: '%s' (ID: %s)" % [node_definition.get_script().resource_path.get_file(), node_definition.id])
	
	if _active_nodes.has(node_definition.id) or _completed_nodes.has(node_definition.id):
		logger.log("Flow", "    - Skipped: Node is already active or completed.")
		return
	if node_definition is StartNodeResource and node_definition.status == GraphNodeResource.Status.COMPLETED:
		logger.log("Flow", "    - Skipped: StartNode was already completed in this session.")
		return

	logger.log("Flow", "  -> Activating Node: '%s'" % [node_definition.id])
	var node_instance = node_definition.duplicate(true)
	_active_nodes[node_instance.id] = node_instance
	
	node_instance.set_meta("activated_on_port_hack", from_input_port)
	
	var script_path = node_instance.get_script().resource_path
	var executor = _executors.get(script_path)

	if executor:
		logger.log("Flow", "    - Found Executor: '%s'" % executor.get_script().resource_path.get_file())
		executor.execute(_execution_context, node_instance)
	else:
		logger.warn("Flow", "No Executor registered for '%s'. Completing node by default." % script_path)
		complete_node(node_instance)

func _build_node_to_context_map():
	_node_to_context_map.clear()
	_quest_id_to_context_node_map.clear()

	for node_id in _node_definitions:
		var node = _node_definitions[node_id]
		if node is QuestContextNodeResource:
			if not node.quest_id.is_empty():
				_quest_id_to_context_node_map[node.quest_id] = node

			var queue: Array = [node.id]
			var visited: Dictionary = {node.id: true}
			_node_to_context_map[node.id] = node.id
			
			while not queue.is_empty():
				var current_node_id = queue.pop_front()
				var connections = _node_connections.get(current_node_id, [])
				for conn in connections:
					var next_node_id = conn.get("to_node")
					if not next_node_id or visited.has(next_node_id):
						continue
					
					var next_node_def = _node_definitions.get(next_node_id)
					if next_node_def is QuestContextNodeResource:
						continue

					visited[next_node_id] = true
					_node_to_context_map[next_node_id] = node.id
					queue.push_back(next_node_id)
	
	var logger = QuestWeaverServices.logger
	if is_instance_valid(logger):
		logger.log("Flow", "Context map built. %d nodes mapped." % _node_to_context_map.size())
		logger.log("Flow", "Quest ID map built. %d quests found." % _quest_id_to_context_node_map.size())

func _mark_node_as_complete(node: GraphNodeResource) -> void:
	var logger = QuestWeaverServices.logger
	if is_instance_valid(logger):
		logger.log("Flow", "  <- Marking Node as Complete (manual trigger): '%s'" % [node.id])
	
	node.status = GraphNodeResource.Status.COMPLETED
	
	# Perform necessary cleanup, e.g., for TaskNode listeners.
	if node is TaskNodeResource:
		var executor = _executors.get(node.get_script())
		if executor and executor.has_method("cleanup_listeners"):
			executor.cleanup_listeners(_execution_context, node)
	
	# Move the node from the active list to the completed list.
	_completed_nodes[node.id] = node
	if _active_nodes.has(node.id):
		_active_nodes.erase(node.id)

func get_quest_id_for_node(node_id: String) -> String:
	if _node_to_context_map.has(node_id):
		var context_node_id = _node_to_context_map[node_id]
		var context_node_def: QuestContextNodeResource = _node_definitions.get(context_node_id)
		if is_instance_valid(context_node_def):
			return context_node_def.quest_id
	return ""

func _on_objective_in_node_changed(_new_status: int, node: TaskNodeResource, objective: ObjectiveResource):
	var quest_id = get_quest_id_for_node(node.id)
	if not quest_id.is_empty():
		quest_data_changed.emit(quest_id)
	
	_check_task_node_completion(node)

func _check_task_node_completion(node: TaskNodeResource):
	for objective in node.objectives:
		if objective.status != ObjectiveResource.Status.COMPLETED:
			return
			
	var logger = QuestWeaverServices.logger
	if is_instance_valid(logger):
		logger.log("Flow", "  - All objectives for TaskNode '%s' complete!" % node.id)
	complete_node(node)

func _ensure_execution_context_exists() -> void:
	if not is_instance_valid(_execution_context):
		var game_state_instance = QuestWeaverServices.get_game_state()
		
		if not is_instance_valid(game_state_instance):
			print("[DEBUG] CRITICAL: QuestWeaverServices did not have a registered GameState instance.")
			return
		
		_execution_context = ExecutionContext.new(self, game_state_instance)

func _load_graph_data(graph_resource: QuestGraphResource):
	var path = graph_resource.resource_path
	if _node_definitions.has("start_node_root") and _get_quest_path_for_node("start_node_root") == path:
		return
	
	_quest_node_map[path] = []
	
	print("[QuestController] Loading data for graph: ", path)
	for node_id in graph_resource.nodes:
		var node_def = graph_resource.nodes[node_id]
		if is_instance_valid(node_def):
			_node_definitions[node_id] = node_def
			_quest_node_map[path].append(node_id) 

	for connection in graph_resource.connections:
		var from_id = connection.get("from_node")
		if from_id:
			if not _node_connections.has(from_id):
				_node_connections[from_id] = []
			_node_connections[from_id].append(connection)

func _on_interacted_with_object(interacted_node: Node):
	if not is_instance_valid(_execution_context) or not is_instance_valid(interacted_node):
		return
	
	# Die eindeutige ID eines Nodes im Spiel ist sein Pfad.
	var interaction_path = str(interacted_node.get_path())
	
	# Prüfe, ob es aktive Ziele gibt, die auf eine Interaktion mit genau diesem Pfad lauschen.
	if _execution_context.interact_objective_listeners.has(interaction_path):
		var listening_objectives = _execution_context.interact_objective_listeners[interaction_path].duplicate()
		
		for objective in listening_objectives:
			if objective.status == ObjectiveResource.Status.ACTIVE:
				# Interaktions-Ziele sind normalerweise "einmalige" Aktionen.
				# Wir setzen sie direkt auf COMPLETED.
				objective.set_status(ObjectiveResource.Status.COMPLETED)

func _on_enemy_was_killed(enemy_id: String):
	if not is_instance_valid(_execution_context) or enemy_id.is_empty():
		return
	
	# Prüfe, ob es überhaupt aktive Ziele gibt, die auf diese Gegner-ID lauschen.
	if _execution_context.kill_objective_listeners.has(enemy_id):
		# Wir arbeiten auf einer Kopie, falls sich die Liste während der Iteration ändert.
		var listening_objectives = _execution_context.kill_objective_listeners[enemy_id].duplicate()
		
		for objective in listening_objectives:
			if objective.status == ObjectiveResource.Status.ACTIVE:
				# Erhöhe den Fortschritt.
				objective.current_progress += 1
				
				# Benachrichtige die UI über die Fortschrittsänderung.
				var quest_id = get_quest_id_for_node(objective.owner_task_node_id)
				if not quest_id.is_empty():
					quest_data_changed.emit(quest_id)

				# Prüfe, ob das Ziel jetzt erfüllt ist.
				if objective.current_progress >= objective.required_progress:
					objective.set_status(ObjectiveResource.Status.COMPLETED)

func _check_item_collect_objectives():
	var logger = QuestWeaverServices.logger
	if not is_instance_valid(logger): return
	
	if not is_instance_valid(_execution_context) or not is_instance_valid(_inventory_adapter):
		return
	
	logger.log("Inventory", "_check_item_collect_objectives called!")
	
	var listening_item_ids = _execution_context.item_objective_listeners.keys()
	
	for item_id in listening_item_ids:
		var current_amount_in_inventory = _inventory_adapter.count_item(item_id)
		logger.log("Inventory", "  -> Checking for item '%s'. Player has: %d" % [item_id, current_amount_in_inventory])
		
		var listening_objectives = _execution_context.item_objective_listeners[item_id]
		
		for objective in listening_objectives.duplicate():
			if objective.status == ObjectiveResource.Status.ACTIVE:
				
				var collected_amount: int
				if objective.track_progress_since_activation:
					collected_amount = current_amount_in_inventory - objective._item_count_on_activation
				else:
					collected_amount = current_amount_in_inventory
				
				collected_amount = max(0, collected_amount)
				
				var required_amount = objective.trigger_params.get("amount", 1)
				
				objective.current_progress = min(collected_amount, required_amount)
				
				logger.log("Inventory", "     - Objective '%s' needs %d. Progress set to %d" % [objective.description, required_amount, objective.current_progress])
				
				var quest_id = get_quest_id_for_node(objective.owner_task_node_id)
				if not quest_id.is_empty():
					quest_data_changed.emit(quest_id)
				
				if collected_amount >= required_amount:
					logger.log("Inventory", "       -> Objective COMPLETED!")
					objective.set_status(ObjectiveResource.Status.COMPLETED)

func _on_entered_location(location_id: String):
	if not is_instance_valid(_execution_context) or location_id.is_empty():
		return

	if _execution_context.location_objective_listeners.has(location_id):
		var listening_objectives = _execution_context.location_objective_listeners[location_id].duplicate()
		for objective in listening_objectives:
			if objective.status == ObjectiveResource.Status.ACTIVE:
				objective.set_status(ObjectiveResource.Status.COMPLETED)

func _get_quest_path_for_node(node_id: String) -> String:
	for path in _quest_node_map:
		if _quest_node_map[path].has(node_id):
			return path
	return ""

func _trigger_next_nodes_from_port(from_node: GraphNodeResource, from_port_index: int):
	var logger = QuestWeaverServices.logger
	if not is_instance_valid(logger): return

	logger.log("Flow", "    - Triggering next nodes from '%s' at port %d..." % [from_node.id, from_port_index])
	var connections = _node_connections.get(from_node.id, [])
	var found_connection = false
	for connection in connections:
		if connection.get("from_port") == from_port_index:
			var next_node_id = connection.get("to_node")
			var to_port = connection.get("to_port", 0)
			var next_node_def = _node_definitions.get(next_node_id)
			if next_node_def:
				logger.log("Flow", "    - Found connection to '%s'. Activating it." % next_node_id)
				_activate_node(next_node_def, to_port)
				found_connection = true
				# In most cases, a port connects to only one other node.
				break 

	if not found_connection:
		logger.log("Flow", "    - End of graph branch reached from node '%s' at port %d." % [from_node.id, from_port_index])
