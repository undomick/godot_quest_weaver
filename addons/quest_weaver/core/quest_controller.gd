# res://addons/quest_weaver/core/quest_controller.gd
class_name QuestController
extends Node

# --- SIGNALS ---
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)
signal quest_data_changed(quest_id: String)

# --- MANAGER INSTANCES ---
var _timer_manager: QuestTimerManager
var _sync_manager: QuestSyncManager
var _event_manager: QuestEventManager
var _scope_manager: QuestScopeManager
var _persistence_manager: QuestStatePersistenceManager
var _execution_context: ExecutionContext
var _inventory_adapter: QuestInventoryAdapterBase = null
var _presentation_manager: PresentationManager
var _logger: QWLogger

# === STATE MANAGEMENT ===
var _quest_node_map: Dictionary = {}
var _call_stack: Array[Dictionary] = []
var _node_to_context_map: Dictionary = {}
var _quest_id_to_context_node_map: Dictionary = {}
var _active_quests: Dictionary = {}
var _node_definitions: Dictionary = {}
var _node_connections: Dictionary = {}
var _active_nodes: Dictionary = {}
var _completed_nodes: Dictionary = {}
#var _executors: Dictionary = {}
var _node_registry: NodeTypeRegistry


# Helper to safely get the singleton without breaking compilation
func _get_services() -> Node:
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.root:
		return main_loop.root.get_node_or_null("QuestWeaverServices")
	return null

# Helper to safely access the logger, even if initialization order is messy
func _get_logger() -> QWLogger:
	# 1. Use local reference if available
	if is_instance_valid(_logger):
		return _logger
		
	# 2. Fallback: Try to find via Services
	var services = _get_services()
	if is_instance_valid(services):
		return services.logger
		
	return null

func _ready() -> void:	
	await get_tree().process_frame
	
	var global_bus = get_tree().root.get_node_or_null("QuestWeaverGlobal")
	if is_instance_valid(global_bus):
		global_bus.register_controller(self)
	
	var services = _get_services()
	if services:
		services.register_quest_controller(self)
	
	_initialize_dependencies_and_start()

func _notification(what):
	if what == NOTIFICATION_EXIT_TREE:
		_on_exit_cleanup()

func _on_exit_cleanup() -> void:
	# 1. Stop active processes in managers
	if is_instance_valid(_timer_manager):
		_timer_manager.clear_all_timers()
	
	if is_instance_valid(_sync_manager):
		_sync_manager.clear()
		
	if is_instance_valid(_event_manager):
		_event_manager.clear()
		
	if is_instance_valid(_scope_manager):
		_scope_manager.clear()

	# 2. Release Manager references
	_timer_manager = null
	_sync_manager = null
	_event_manager = null
	_scope_manager = null
	_persistence_manager = null
	
	# 3. Break Circular References
	# The ExecutionContext holds a reference to this Controller. 
	# Nullifying it here allows the Context to be freed.
	_execution_context = null 
	
	# 4. Release Node Type Registry
	_node_registry = null
	
	# 5. Clear External Dependencies
	_inventory_adapter = null
	_presentation_manager = null
	_logger = null
	
	# 6. Clear Data Structures
	# This releases references to specific Node Resources stored in dictionaries.
	_quest_node_map.clear()
	_node_to_context_map.clear()
	_quest_id_to_context_node_map.clear()
	_active_quests.clear()
	_node_definitions.clear()
	_node_connections.clear()
	_active_nodes.clear()
	_completed_nodes.clear()
	
	# 7. Clean up static references in singletons
	QWConstants.clear_static_references()

func _initialize_dependencies_and_start() -> void:
	_initialize_managers()
	_register_executors()
	_initialize_inventory_adapter()
	_initialize_quest_graphs()
	_scope_manager.initialize_scope_definitions(_node_definitions, _node_connections)
	_connect_global_signals()
	
	var services = _get_services()
	if services and not services.has_game_state():
		print("[QuestController] Waiting for GameState registration...")
		await services.game_state_ready
	
	start_all_loaded_graphs()

# --- CORE INITIALIZATION ---

func _initialize_managers():
	_persistence_manager = QuestStatePersistenceManager.new()
	_timer_manager = QuestTimerManager.new(self)
	_sync_manager = QuestSyncManager.new(self)
	_event_manager = QuestEventManager.new(self)
	_scope_manager = QuestScopeManager.new(self)
	
	_logger = QWLogger.new()
	_logger.initialize()
	
	var services = _get_services()
	if services:
		services.register_logger(_logger)
		
		_presentation_manager = PresentationManager.new()
		_presentation_manager.name = "PresentationManager"
		add_child(_presentation_manager)
		services.register_presentation_manager(_presentation_manager)

func _register_executors():
	_node_registry = NodeTypeRegistry.new()
	# initialization happens automatically in _init of Registry now
	
	if not is_instance_valid(_node_registry):
		push_error("QuestController: Could not load NodeTypeRegistry!")

func _initialize_quest_graphs() -> void:
	var logger = _logger
	if not is_instance_valid(logger): return

	logger.log("Flow", "Initializing quest graphs...")
	
	_load_auto_start_graphs()

	if not Engine.is_editor_hint():
		logger.log("Flow", "Skipping editor session data load in exported build.")
		return 

	var settings = QWConstants.get_settings()
	if not is_instance_valid(settings): return

	var paths_to_load: Array[String] = []
	var editor_data_path = settings.editor_data_path
	
	if editor_data_path and ResourceLoader.exists(editor_data_path):
		var editor_data: QuestEditorData = ResourceLoader.load(editor_data_path, "QuestEditorData", ResourceLoader.CACHE_MODE_REPLACE)
		if is_instance_valid(editor_data):
			for path in editor_data.open_files:
				if path is String and not path.is_empty():
					paths_to_load.append(path)
	
	for graph_path in paths_to_load:
		if not FileAccess.file_exists(graph_path):
			continue
		
		var graph_res = ResourceLoader.load(graph_path, "QuestGraphResource")
		if is_instance_valid(graph_res):
			graph_res.resource_path = graph_path 
			_load_graph_data(graph_res)

	logger.log("Flow", "Initialization complete.")

func _initialize_inventory_adapter():
	var logger = _logger
	var adapter_path = QWConstants.get_settings().inventory_adapter_script
	
	if adapter_path and not adapter_path.is_empty() and ResourceLoader.exists(adapter_path):
		var adapter_script = load(adapter_path)
		if is_instance_valid(adapter_script):
			_inventory_adapter = adapter_script.new()
			_inventory_adapter.initialize()
			_inventory_adapter.inventory_updated.connect(_check_item_collect_objectives)
			if is_instance_valid(logger):
				logger.log("Inventory", "Inventory Adapter initialized and connected successfully.")
		else:
			push_error("QuestController: The assigned adapter script could not be instantiated.")
	elif is_instance_valid(logger):
		logger.warn("Inventory", "No Inventory Adapter configured. Item-related quests will not function.")

func _connect_global_signals() -> void:
	var logger = _logger
	# FIX: Get Global Event Bus safely
	var event_bus = get_tree().root.get_node_or_null("QuestWeaverGlobal")
	
	if is_instance_valid(logger):
		logger.log("Flow", "Attempting to connect global signals. Found event_bus: %s" % is_instance_valid(event_bus))
	
	if not is_instance_valid(event_bus):
		push_warning("[QuestController] QuestWeaverGlobal Singleton could not be found via SceneTree. This is a critical issue.")
		return

	if not event_bus.quest_event_fired.is_connected(_event_manager.on_global_event):
		event_bus.quest_event_fired.connect(_event_manager.on_global_event)
	if not event_bus.interacted_with_object.is_connected(_on_interacted_with_object):
		event_bus.interacted_with_object.connect(_on_interacted_with_object)
	if not event_bus.enemy_was_killed.is_connected(_on_enemy_was_killed):
		event_bus.enemy_was_killed.connect(_on_enemy_was_killed)
	if not event_bus.entered_location.is_connected(_on_entered_location):
		event_bus.entered_location.connect(_on_entered_location)

# --- PUBLIC API & CORE LOGIC ---

func force_skip_node(node_id: String) -> void:
	if not _active_nodes.has(node_id): return
	
	var node = _active_nodes[node_id]
	var logger = _get_logger()
	if logger: logger.log("System", "Force skipping node: %s" % node_id)

	# 1. Handle specific cleanup logic (Stop Audio, Close UI, Jump Anim)
	if node is ShowUIMessageNodeResource:
		if is_instance_valid(_presentation_manager):
			# We assume PresentationManager has a method to force close
			_presentation_manager.force_close_current()
			
	elif node is PlayCutsceneNodeResource:
		var root = get_tree().get_root()
		var anim_player = root.get_node_or_null(node.animation_player_path)
		if is_instance_valid(anim_player) and anim_player.is_playing():
			# Jump to end of animation instantly
			anim_player.seek(anim_player.current_animation_length, true)
			anim_player.stop()

	# 2. Unlock Global State
	var global_bus = get_tree().root.get_node_or_null("QuestWeaverGlobal")
	if is_instance_valid(global_bus):
		global_bus.unlock_interaction(node_id)

	# 3. Complete the node logic (Trigger output ports)
	# For Cutscenes/UI, we usually want to trigger the "Success/Finish" port.
	if node is PlayCutsceneNodeResource or node is ShowUIMessageNodeResource:
		# Assuming port 0 is the default continuation or we check logic
		complete_node(node)
	else:
		complete_node(node)

func reset_all_graphs_and_quests():
	var logger = _logger
	if is_instance_valid(logger):
		logger.log("Flow", "Resetting all graphs and quest states.")
	
	_active_nodes.clear()
	_completed_nodes.clear()
	_timer_manager.clear_all_timers()
	_sync_manager.clear()
	_event_manager.clear()
	_scope_manager.clear()
	_active_quests.clear()

func start_all_loaded_graphs():
	_ensure_execution_context_exists()
	
	var settings = QWConstants.get_settings()
	if settings and not settings.auto_start_quests.is_empty():
		for raw_path in settings.auto_start_quests:
			if raw_path.is_empty(): continue
			
			var final_path = raw_path
			
			if raw_path.begins_with("uid://"):
				var id = ResourceLoader.get_resource_uid(raw_path)
				if id != -1:
					final_path = ResourceUID.get_id_path(id)
			
			if QWConstants.get_settings().auto_start_quests.size() > 0:
				var logger = _get_logger()
				if logger:
					logger.log("System", "Auto-starting: " + final_path)
			_start_specific_graph_entry(final_path)

## Loads the list of auto-start quests defined in settings.
func _load_auto_start_graphs() -> void:
	var settings = QWConstants.get_settings()
	if not is_instance_valid(settings):
		return

	var paths_to_load: Array[String] = []

	# Use explicit loop to bypass Array[String] vs Array type mismatch error on loaded resources
	for raw_path in settings.auto_start_quests:
		if not raw_path is String or raw_path.is_empty():
			continue
			
		var final_path = raw_path

		if raw_path.begins_with("uid://"):
			var uid_int = ResourceLoader.get_resource_uid(raw_path) 
			if uid_int != -1:
				final_path = ResourceUID.get_id_path(uid_int) 
			
		if not final_path.is_empty():
			paths_to_load.append(final_path)
	
	for graph_path in paths_to_load:
		if not ResourceLoader.exists(graph_path):
			push_error("QuestController: Auto-start graph not found at '%s'." % graph_path)
			continue
		
		# Load the graph resource and ensure its path is set for the internal maps
		var graph_res = ResourceLoader.load(graph_path, "QuestGraphResource")
		if is_instance_valid(graph_res):
			graph_res.resource_path = graph_path 
			_load_graph_data(graph_res) # This method puts definitions into _quest_node_map, etc.
		
	if is_instance_valid(_logger):
		_logger.log("Flow", "Loaded %d auto-start graph definitions." % paths_to_load.size())

func start_quest(node_data: QuestContextNodeResource) -> void:
	var logger = _logger
	var quest_id = node_data.quest_id
	if quest_id.is_empty():
		push_error("QuestContextNode '%s' has a missing Quest ID." % node_data.id)
		return
		
	if not _active_quests.has(quest_id):
		_active_quests[quest_id] = {
			"status": QWEnums.QuestState.ACTIVE,
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
		var current_status = _active_quests[quest_id].status
		var status_str = "UNKNOWN"
		if current_status == QWEnums.QuestState.ACTIVE: status_str = "ACTIVE"
		elif current_status == QWEnums.QuestState.COMPLETED: status_str = "COMPLETED"
		elif current_status == QWEnums.QuestState.FAILED: status_str = "FAILED"
		
		push_warning("QuestWeaver: Cannot start quest '%s'. It is already registered with status: %s." % [quest_id, status_str])

func start_quest_by_id(quest_id: String) -> void:
	if _quest_id_to_context_node_map.has(quest_id):
		var context_node = _quest_id_to_context_node_map[quest_id]
		_activate_node(context_node)
	else:
		if is_instance_valid(_logger):
			_logger.warn("System", "start_quest_by_id: No Quest Context found for ID '%s'." % quest_id)

func start_sub_graph(graph_path: String) -> void:
	if ResourceLoader.exists(graph_path):
		var graph_res = ResourceLoader.load(graph_path)
		_load_graph_data(graph_res)
	else:
		push_error("QuestController: Could not load sub-graph resource at '%s'." % graph_path)
		return
	
	var nodes_in_graph = _quest_node_map.get(graph_path, [])
	var start_node_found = false
	
	for node_id in nodes_in_graph:
		var node_def = _node_definitions.get(node_id)
		
		if node_def is StartNodeResource:
			_activate_node(node_def)
			start_node_found = true
	
	if not start_node_found:
		var context_found = false
		for node_id in nodes_in_graph:
			var node_def = _node_definitions.get(node_id)
			if node_def is QuestContextNodeResource:
				push_warning("QuestController: Sub-graph '%s' has no StartNode. Starting at QuestContextNode instead." % graph_path)
				_activate_node(node_def)
				context_found = true
				break
		
		if not context_found:
			push_error("QuestController: Sub-graph at '%s' has neither StartNode nor QuestContextNode. Cannot start." % graph_path)

func _start_specific_graph_entry(graph_path: String) -> void:
	if not _quest_node_map.has(graph_path):
		if ResourceLoader.exists(graph_path):
			var res = ResourceLoader.load(graph_path)
			_load_graph_data(res)
		else:
			push_error("QuestController: Could not auto-start '%s'. File not found." % graph_path)
			return

	var nodes_in_graph = _quest_node_map.get(graph_path, [])
	var start_node_found = false
	
	for node_id in nodes_in_graph:
		var node = _node_definitions.get(node_id)
		if node is StartNodeResource:
			_activate_node(node)
			start_node_found = true
	
	if not start_node_found:
		push_warning("QuestController: Auto-start graph '%s' has no StartNode." % graph_path)

func push_to_call_stack(parent_node_id: String):
	var parent_graph_path = _get_quest_path_for_node(parent_node_id)
	
	if parent_graph_path.is_empty():
		push_error("QuestController: Could not find parent graph for call stack (Node ID: %s)" % parent_node_id)
		return
		
	var child_path = ""
	var node = _active_nodes.get(parent_node_id)
	if node and node is SubGraphNodeResource:
		child_path = node.quest_graph_path
		if child_path.begins_with("uid://"):
			var uid = ResourceLoader.get_resource_uid(child_path)
			if uid != -1: child_path = ResourceUID.get_id_path(uid)
	
	_call_stack.append({
		"parent_node_id": parent_node_id,
		"parent_quest_path": parent_graph_path,
		"child_graph_path": child_path
	})

func pop_from_call_stack():
	if _call_stack.is_empty(): return
	
	var return_info = _call_stack.pop_back()
	var parent_node_id = return_info.get("parent_node_id")
	
	var child_graph_path = return_info.get("child_graph_path")
	if child_graph_path:
		_cleanup_graph_instances(child_graph_path)
	
	var logger = _logger
	if is_instance_valid(logger):
		logger.log("Flow", "Sub-Graph finished. Returning to parent graph at Node '%s'." % parent_node_id)
	
	var parent_subgraph_node = _active_nodes.get(parent_node_id)
	
	if is_instance_valid(parent_subgraph_node):
		complete_node(parent_subgraph_node)
	else:
		push_warning("QuestController: Could not find the calling SubGraphNode '%s' in active nodes to return to." % parent_node_id)

func set_quest_status(quest_id_str: String, action: QuestNodeResource.QuestAction) -> void:
	var logger = _logger
	if quest_id_str.is_empty(): return
	
	if action == QuestNodeResource.QuestAction.START:
		if _active_quests.has(quest_id_str) and _active_quests[quest_id_str].status == QWEnums.QuestState.ACTIVE:
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
	var target_status: QWEnums.QuestState

	match action:
		QuestNodeResource.QuestAction.COMPLETE: target_status = QWEnums.QuestState.COMPLETED
		QuestNodeResource.QuestAction.FAIL: target_status = QWEnums.QuestState.FAILED

	if current_status != target_status:
		_active_quests[quest_id_str].status = target_status
		if is_instance_valid(logger):
			logger.log("Flow", "Status of Quest '%s' set to %s." % [quest_id_str, QWEnums.QuestState.keys()[target_status]])
		if target_status == QWEnums.QuestState.COMPLETED:
			quest_completed.emit(quest_id_str)
		elif target_status == QWEnums.QuestState.FAILED:
			quest_failed.emit(quest_id_str)

func get_objective_status(p_objective_id: String) -> int:
	if p_objective_id.is_empty():
		return 0

	for node in _active_nodes.values():
		if node is TaskNodeResource:
			for objective in node.objectives:
				if objective.id == p_objective_id:
					return objective.status
	
	for node in _completed_nodes.values():
		if node is TaskNodeResource:
			for objective in node.objectives:
				if objective.id == p_objective_id:
					return objective.status
	
	return 0

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
		if _active_quests[quest_id].status == QWEnums.QuestState.ACTIVE:
			var data = _active_quests[quest_id].duplicate(true)
			data["id"] = quest_id
			result.append(data)
	return result

func get_quest_data(quest_id: String) -> Dictionary:
	if _active_quests.has(quest_id):
		return _active_quests[quest_id]
	return {}

func get_all_managed_quests_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for quest_id in _active_quests:
		if _active_quests[quest_id].status == QWEnums.QuestState.INACTIVE:
			continue

		var data = _active_quests[quest_id].duplicate(true)
		data["id"] = quest_id
		result.append(data)
	
	return result

func get_active_objectives_for_quest(quest_id: String) -> Array[ObjectiveResource]:
	var objectives_for_quest: Array[ObjectiveResource] = []
	
	for node in _active_nodes.values():
		if node is TaskNodeResource:
			var node_quest_id = get_quest_id_for_node(node.id)
			if node_quest_id == quest_id:
				objectives_for_quest.append_array(node.objectives)
				
	return objectives_for_quest

func complete_node(node: GraphNodeResource) -> void:
	var logger = _logger
	if is_instance_valid(logger):
		logger.log("Flow", "  <- Completing Node: '%s'" % [node.id])
	
	node.status = GraphNodeResource.Status.COMPLETED
	
	if node is TaskNodeResource:
		var executor = _node_registry.get_executor_for_node(node)
		if executor and executor.has_method("cleanup_listeners"):
			executor.cleanup_listeners(_execution_context, node)
	
	_completed_nodes[node.id] = node
	if _active_nodes.has(node.id):
		_active_nodes.erase(node.id)
	
	if node is EndNodeResource:
		var current_graph_path = _get_quest_path_for_node(node.id)
		_cleanup_graph_instances(current_graph_path)
		
		if not _call_stack.is_empty():
			var top = _call_stack.back()
			if top.child_graph_path == current_graph_path:
				pop_from_call_stack()
				return
	
	_trigger_next_nodes_from_port(node, 0)

func set_manual_objective_status(objective_id: String, new_status: int):
	var logger = _get_logger()
	
	var found = false
	
	# 1. Search in active nodes
	for node in _active_nodes.values():
		if node is TaskNodeResource:
			for objective in node.objectives:
				if objective.id == objective_id:
					objective.set_status(new_status)
					if logger: logger.log("Executor", "Objective '%s' status set to: %d" % [objective_id, new_status])
					found = true
					return

	# 2. Search in completed nodes
	for node in _completed_nodes.values():
		if node is TaskNodeResource:
			for objective in node.objectives:
				if objective.id == objective_id:
					objective.set_status(new_status)
					if logger: logger.log("Executor", "(Completed Node) Objective '%s' status set to: %d" % [objective_id, new_status])
					found = true
					return
	
	if not found:
		if logger:
			logger.warn("Executor", "Could not find Objective with ID '%s' to update (checked active and completed nodes)." % objective_id)
		else:
			push_warning("QuestWeaver: Could not find Objective '%s'." % objective_id)

func jump_to_anchor(origin_node: GraphNodeResource, anchor_name: String) -> void:
	var logger = _logger
	
	var current_graph_path = _get_quest_path_for_node(origin_node.id)
	
	if current_graph_path.is_empty():
		push_error("QuestController: JumpNode '%s' belongs to no known graph." % origin_node.id)
		return

	var node_ids_in_graph = _quest_node_map.get(current_graph_path, [])
	var target_anchor: AnchorNodeResource = null
	
	for id in node_ids_in_graph:
		var def = _node_definitions.get(id)
		if def is AnchorNodeResource and def.anchor_name == anchor_name:
			target_anchor = def
			break
	
	if target_anchor:
		if is_instance_valid(logger):
			logger.log("Flow", "  -> JUMPING from '%s' to Anchor '%s'." % [origin_node.id, anchor_name])
		
		_activate_node(target_anchor)
	else:
		push_warning("QuestController: JumpNode '%s' could not find Anchor '%s' in graph '%s'." % [origin_node.id, anchor_name, current_graph_path.get_file()])

func get_save_data() -> Dictionary:
	return _persistence_manager.save_state(self)

func load_from_data(data: Dictionary):
	_persistence_manager.load_state(self, data)

# --- INTERNAL LOGIC & HELPERS ---

func _activate_node(node_definition: GraphNodeResource, from_input_port: int = 0) -> void:
	var logger = _logger
	if not is_instance_valid(logger): return

	logger.log("Flow", ">>> Attempting to activate Node: '%s' (ID: %s)" % [node_definition.get_script().resource_path.get_file(), node_definition.id])
	
	if _active_nodes.has(node_definition.id):
		logger.log("Flow", "    - Skipped: Node '%s' is currently ACTIVE (running)." % node_definition.id)
		return

	if _completed_nodes.has(node_definition.id):
		_completed_nodes.erase(node_definition.id)
	
	if node_definition is StartNodeResource and node_definition.status == GraphNodeResource.Status.COMPLETED:
		logger.log("Flow", "    - Skipped: StartNode was already completed in this session.")
		return

	logger.log("Flow", "  -> Activating Node: '%s'" % [node_definition.id])
	var node_instance = node_definition.duplicate(true)
	_active_nodes[node_instance.id] = node_instance
	
	node_instance.set_meta("activated_on_port_hack", from_input_port)
	
	var executor: NodeExecutor = _node_registry.get_executor_for_node(node_instance)
	if executor:
		executor.execute(_execution_context, node_instance)
	else:
		logger.log("Flow", "    - No specific Executor found. Using Default behavior.")
		complete_node(node_instance)

func _mark_node_as_complete(node: GraphNodeResource) -> void:
	var logger = _logger
	if is_instance_valid(logger):
		logger.log("Flow", "  <- Marking Node as Complete (manual trigger): '%s'" % [node.id])
	
	node.status = GraphNodeResource.Status.COMPLETED
	
	if node is TaskNodeResource:
		var executor = _node_registry.get_executor_for_node(node)
		if executor and executor.has_method("cleanup_listeners"):
			executor.cleanup_listeners(_execution_context, node)
	
	_completed_nodes[node.id] = node
	if _active_nodes.has(node.id):
		_active_nodes.erase(node.id)

func get_quest_id_for_node(node_id: String) -> String:
	return _node_to_context_map.get(node_id, "")

func _on_objective_in_node_changed(_new_status: int, node: TaskNodeResource, objective: ObjectiveResource):
	var quest_id = get_quest_id_for_node(node.id)
	if not quest_id.is_empty():
		quest_data_changed.emit(quest_id)
	
	_check_task_node_completion(node)

func _check_task_node_completion(node: TaskNodeResource):
	for objective in node.objectives:
		if objective.status != ObjectiveResource.Status.COMPLETED:
			return
			
	var logger = _logger
	if is_instance_valid(logger):
		logger.log("Flow", "  - All objectives for TaskNode '%s' complete!" % node.id)
	complete_node(node)

func _ensure_execution_context_exists() -> void:
	if not is_instance_valid(_execution_context):
		var services = _get_services()
		var game_state_instance = null
		if services:
			game_state_instance = services.get_game_state()
		
		if not is_instance_valid(game_state_instance):
			print("[DEBUG] CRITICAL: GameState instance not found during context creation.")
			return
		
		_execution_context = ExecutionContext.new(self, game_state_instance, _logger, services)

func _load_graph_data(graph_resource: QuestGraphResource):
	var path = graph_resource.resource_path
	
	if _quest_node_map.has(path):
		var logger = _get_logger()
		if logger:
			logger.log("System", "Skipping load of '%s'. Definitions already in memory." % path.get_file())
		return
	
	_quest_node_map[path] = []
	
	var found_quest_id = ""
	
	for node_id in graph_resource.nodes:
		var node_def = graph_resource.nodes[node_id]
		if node_def is QuestContextNodeResource:
			found_quest_id = node_def.quest_id
			if not found_quest_id.is_empty():
				_quest_id_to_context_node_map[found_quest_id] = node_def
			break
	
	var logger = _get_logger()
	if logger:
		logger.log("System", "Loading graph: %s (Quest ID: %s)" % [path.get_file(), found_quest_id])
	
	for node_id in graph_resource.nodes:
		var node_def = graph_resource.nodes[node_id]
		if is_instance_valid(node_def):
			_node_definitions[node_id] = node_def
			_quest_node_map[path].append(node_id)
			
			if not found_quest_id.is_empty():
				_node_to_context_map[node_id] = found_quest_id

	for connection in graph_resource.connections:
		var from_id = connection.get("from_node")
		if from_id:
			if not _node_connections.has(from_id):
				_node_connections[from_id] = []
			_node_connections[from_id].append(connection)

func _on_interacted_with_object(interacted_node: Node):
	if not is_instance_valid(_execution_context) or not is_instance_valid(interacted_node):
		return
	
	var interaction_path = str(interacted_node.get_path())
	
	if _execution_context.interact_objective_listeners.has(interaction_path):
		var listening_objectives = _execution_context.interact_objective_listeners[interaction_path].duplicate()
		
		for objective in listening_objectives:
			if objective.status == ObjectiveResource.Status.ACTIVE:
				objective.set_status(ObjectiveResource.Status.COMPLETED)

func _on_enemy_was_killed(enemy_id: String):
	if not is_instance_valid(_execution_context) or enemy_id.is_empty():
		return
	
	if _execution_context.kill_objective_listeners.has(enemy_id):
		var listening_objectives = _execution_context.kill_objective_listeners[enemy_id].duplicate()
		
		for objective in listening_objectives:
			if objective.status == ObjectiveResource.Status.ACTIVE:
				objective.current_progress += 1
				
				var quest_id = get_quest_id_for_node(objective.owner_task_node_id)
				if not quest_id.is_empty():
					quest_data_changed.emit(quest_id)

				if objective.current_progress >= objective.required_progress:
					objective.set_status(ObjectiveResource.Status.COMPLETED)

func _check_item_collect_objectives():
	var logger = _logger
	if not is_instance_valid(logger): return
	
	if not is_instance_valid(_execution_context) or not is_instance_valid(_inventory_adapter):
		return
	
	logger.log("Inventory", "_check_item_collect_objectives called!")
	
	var listening_item_ids = _execution_context.item_objective_listeners.keys()
	for item_id in listening_item_ids:
		if not _execution_context.item_objective_listeners.has(item_id):
			continue
		
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
	var logger = _logger
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
				break 

	if not found_connection:
		logger.log("Flow", "    - End of graph branch reached from node '%s' at port %d." % [from_node.id, from_port_index])

func _cleanup_graph_instances(graph_path: String) -> void:
	var logger = _logger
	if is_instance_valid(logger):
		logger.log("Flow", "Cleaning up remaining nodes in graph: %s" % graph_path.get_file())

	var nodes_to_kill: Array[String] = []
	
	for node_id in _active_nodes:
		var current_path = _get_quest_path_for_node(node_id)
		if current_path == graph_path:
			nodes_to_kill.append(node_id)
	
	for node_id in nodes_to_kill:
		var node_instance = _active_nodes[node_id]
		
		if node_instance is EventListenerNodeResource:
			_event_manager.unregister_listener(node_instance)
		
		if node_instance is TimerNodeResource:
			_timer_manager.remove_timer(node_id)
			
		if node_instance is TaskNodeResource:
			var executor = _node_registry.get_executor_for_node(node_instance)
			if executor and executor.has_method("cleanup_listeners"):
				executor.cleanup_listeners(_execution_context, node_instance)

		_active_nodes.erase(node_id)
		
		if is_instance_valid(logger):
			logger.log("Flow", "  - Force-closed node: %s" % node_id)

# Helper function for ScopeManager to mark node complete without checking listeners or cleanup
func _mark_node_as_logically_complete(node: GraphNodeResource) -> void:
	var logger = _logger
	if is_instance_valid(logger):
		logger.log("Flow", "  <- Marking Node as Logically Complete (No trigger/cleanup): '%s'" % [node.id])
	
	node.status = GraphNodeResource.Status.COMPLETED
	
	_completed_nodes[node.id] = node
	if _active_nodes.has(node.id):
		_active_nodes.erase(node.id)
