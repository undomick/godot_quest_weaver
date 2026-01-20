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

# === STATE MANAGEMENT (v1.0) ===

# Holds the runtime data objects (QuestInstance). 
# Key: File ID (String) | Value: QuestInstance
var _active_instances: Dictionary = {}

# === STATIC DEFINITIONS (BLUEPRINTS) ===

# Maps file paths to a list of Node IDs contained within.
var _quest_node_map: Dictionary = {} 

# Maps Node ID -> GraphNodeResource (The static blueprint).
var _node_definitions: Dictionary = {} 

# Maps Node ID -> Array of Connection Dictionaries.
var _node_connections: Dictionary = {} 

# Maps Logical Quest ID (and File ID fallback) -> QuestContextNodeResource.
# Used to retrieve static UI data (Title/Description) for the Journal.
var _id_to_context_node_map: Dictionary = {} 

# Maps Node ID -> File ID. Essential to find the instance from a node.
var _node_to_file_id_map: Dictionary = {} 

var _call_stack: Array[Dictionary] = []
var _node_registry: NodeTypeRegistry


# --- INITIALIZATION & LIFECYCLE ---

func _get_services() -> Node:
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.root:
		return main_loop.root.get_node_or_null("QuestWeaverServices")
	return null

func _get_logger() -> QWLogger:
	if is_instance_valid(_logger): return _logger
	var services = _get_services()
	if is_instance_valid(services): return services.logger
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
	_send_debug_message("session_started")

func _notification(what):
	if what == NOTIFICATION_EXIT_TREE:
		_on_exit_cleanup()

func _on_exit_cleanup() -> void:
	_send_debug_message("session_ended")
	
	if is_instance_valid(_timer_manager): _timer_manager.clear_all_timers()
	if is_instance_valid(_sync_manager): _sync_manager.clear()
	if is_instance_valid(_event_manager): _event_manager.clear()
	if is_instance_valid(_scope_manager): _scope_manager.clear()

	_timer_manager = null
	_sync_manager = null
	_event_manager = null
	_scope_manager = null
	_persistence_manager = null
	_execution_context = null 
	_node_registry = null
	_inventory_adapter = null
	_presentation_manager = null
	_logger = null
	
	_active_instances.clear()
	_node_definitions.clear()
	_node_connections.clear()
	_quest_node_map.clear()
	_id_to_context_node_map.clear()
	_node_to_file_id_map.clear()
	
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
		if FileAccess.file_exists(graph_path):
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
	var event_bus = get_tree().root.get_node_or_null("QuestWeaverGlobal")
	if not is_instance_valid(event_bus):
		push_warning("[QuestController] QuestWeaverGlobal Singleton could not be found.")
		return

	if not event_bus.quest_event_fired.is_connected(_event_manager.on_global_event):
		event_bus.quest_event_fired.connect(_event_manager.on_global_event)
	if not event_bus.interacted_with_object.is_connected(_on_interacted_with_object):
		event_bus.interacted_with_object.connect(_on_interacted_with_object)
	if not event_bus.enemy_was_killed.is_connected(_on_enemy_was_killed):
		event_bus.enemy_was_killed.connect(_on_enemy_was_killed)
	if not event_bus.entered_location.is_connected(_on_entered_location):
		event_bus.entered_location.connect(_on_entered_location)

# --- PUBLIC API ---

## Main entry point to activate a quest logic flow.
## Sets status to ACTIVE, registers Logical ID, and emits signals.
func start_quest(context_node: QuestContextNodeResource) -> void:
	var logger = _logger
	
	# 1. Resolve File ID
	var file_id = _node_to_file_id_map.get(context_node.id, "")
	if file_id.is_empty():
		push_error("QuestController: ContextNode '%s' is not mapped to a file instance." % context_node.id)
		return
		
	# 2. Get or Create Instance
	var instance = _active_instances.get(file_id)
	if not instance:
		instance = QuestInstance.new(file_id)
		_active_instances[file_id] = instance
	
	# 3. Register Logical ID (from Context)
	if not context_node.quest_id.is_empty():
		instance.quest_id = context_node.quest_id

	# 4. Activate Logic (Only if not already running)
	# Note: We allow re-entry to update logs, but status change happens once.
	if instance.current_status != QWEnums.QuestState.ACTIVE:
		instance.current_status = QWEnums.QuestState.ACTIVE
		
		if not context_node.log_on_start.is_empty():
			instance.set_variable("_logs", [context_node.log_on_start])
		
		if logger: 
			logger.log("Flow", "Quest '%s' (File: %s) set to ACTIVE. LogicID: %s" % [context_node.quest_title, file_id, instance.quest_id])
		
		var signal_id = instance.quest_id if not instance.quest_id.is_empty() else file_id
		quest_started.emit(signal_id)
		quest_data_changed.emit(signal_id)

## Starts a quest by ID and injects parameters BEFORE activation.
## Useful for templated quests.
func start_quest_with_parameters(query_id: String, params: Dictionary) -> void:
	var logger = _logger
	
	# 1. Resolve File ID
	var file_id = _resolve_instance_file_id(query_id)
	
	# 2. Ensure Instance Exists (Pre-Creation)
	if not _active_instances.has(file_id):
		# Just checking if we have the definition loaded at all
		if _quest_node_map.is_empty() or not _id_to_context_node_map.has(query_id):
			# Optional: Try to auto-load if missing?
			pass
			
		var instance = QuestInstance.new(file_id)
		# We keep it INACTIVE for now, start_quest will flip it to ACTIVE
		instance.current_status = QWEnums.QuestState.INACTIVE 
		_active_instances[file_id] = instance

	var instance: QuestInstance = _active_instances[file_id]

	# 3. Inject Parameters
	for key in params:
		instance.set_variable(key, params[key])
	
	if logger:
		logger.log("Flow", " injected parameters into '%s': %s" % [file_id, params])

	# 4. Delegate to standard Start Logic
	var context_node = _id_to_context_node_map.get(query_id)
	
	# Fallback lookup if query was file_id
	if not context_node:
		context_node = _id_to_context_node_map.get(file_id)
	
	if context_node:
		# DRY: Reuse the main activation logic!
		start_quest(context_node)
		# Trigger the flow starting at this node
		_activate_node(context_node)
	else:
		# Fallback for raw graphs without ContextNode
		_start_specific_graph_entry(file_id)

func start_quest_by_id(query_id: String) -> void:
	# Resolve logical ID to file ID to find Context Node
	# (Mapping in _quest_id_to_context_node_map uses logical IDs primarily)
	if _id_to_context_node_map.has(query_id):
		var context_node = _id_to_context_node_map[query_id]
		_activate_node(context_node)
	else:
		if is_instance_valid(_logger):
			_logger.warn("System", "start_quest_by_id: No definition found for ID '%s'." % query_id)

## Resets all progress of a quest instance and restarts it from the beginning.
func restart_quest(query_id: String) -> void:
	var file_id = _resolve_instance_file_id(query_id)
	
	if not _active_instances.has(file_id):
		# If it doesn't exist yet, just start it normal
		start_quest_by_id(query_id)
		return

	var instance: QuestInstance = _active_instances[file_id]
	var logger = _get_logger()
	
	if logger: logger.log("Flow", "Restarting Quest '%s'..." % query_id)
	
	# 1. Cleanup running nodes (Timers, Listeners)
	for node_id in instance.active_node_ids.duplicate():
		_cleanup_node_runtime(node_id, instance)
	
	# 2. Hard Reset of Instance Data
	# We want a fresh start, so we clear objectives and node states.
	# We KEEP variables passed via start_quest_with_parameters? 
	# Usually a restart implies "Reset Progress", not "Reset Parameters".
	# So we clear node_states and objective_states, but keep variables.
	instance.active_node_ids.clear()
	instance.node_states.clear()
	instance.objective_states.clear()
	instance.current_status = QWEnums.QuestState.INACTIVE
	
	# 3. Trigger Start Logic again
	# Find Context Node to restart via standard flow
	var context_node = _id_to_context_node_map.get(query_id)
	if not context_node:
		context_node = _id_to_context_node_map.get(file_id)
		
	if context_node:
		start_quest(context_node) # Sets Active & Logs
		_activate_node(context_node)
	else:
		# Raw Graph fallback
		_start_specific_graph_entry(file_id)

## Debug/Cheat Tool: Forces the quest flow to jump to a specific node.
## Stops all currently active nodes in this quest before jumping.
func jump_to_node(node_id: String) -> void:
	var file_id = _get_file_id_for_node(node_id)
	var instance = _active_instances.get(file_id)
	var logger = _get_logger()
	
	if not instance:
		if logger: logger.warn("Flow", "Jump failed: No instance found for node '%s'." % node_id)
		return
		
	if logger: logger.log("Flow", ">>> FORCE JUMP to node '%s' in quest '%s'" % [node_id, file_id])
	
	# 1. Stop ALL currently active nodes in this instance
	# (Simulate that we left the previous state)
	for active_id in instance.active_node_ids.duplicate():
		_cleanup_node_runtime(active_id, instance)
	instance.active_node_ids.clear()
	
	# 2. Ensure Quest is Active (if we jump into a inactive quest)
	if instance.current_status != QWEnums.QuestState.ACTIVE:
		instance.current_status = QWEnums.QuestState.ACTIVE
		quest_started.emit(instance.quest_id if not instance.quest_id.is_empty() else file_id)
	
	# 3. Activate Target
	var node_def = _node_definitions.get(node_id)
	if node_def:
		_activate_node(node_def)

## Convenience: Completes a quest successfully.
func finish_quest(query_id: String) -> void:
	set_quest_status(query_id, QuestNodeResource.QuestAction.COMPLETE)

## Convenience: Fails a quest.
func fail_quest(query_id: String) -> void:
	set_quest_status(query_id, QuestNodeResource.QuestAction.FAIL)

func set_quest_status(query_id: String, action: QuestNodeResource.QuestAction) -> void:
	var logger = _logger
	if query_id.is_empty(): return
	
	# START Action: Logic is different (Activation)
	if action == QuestNodeResource.QuestAction.START:
		start_quest_by_id(query_id)
		return

	# Resolve Instance ID (File ID) from Query ID
	var file_id = _resolve_instance_file_id(query_id)

	if not _active_instances.has(file_id):
		if logger: logger.warn("Flow", "Cannot change status of inactive/unknown quest '%s'." % query_id)
		return

	var instance: QuestInstance = _active_instances[file_id]
	var target_status = QWEnums.QuestState.ACTIVE
	
	match action:
		QuestNodeResource.QuestAction.COMPLETE: target_status = QWEnums.QuestState.COMPLETED
		QuestNodeResource.QuestAction.FAIL: target_status = QWEnums.QuestState.FAILED
	
	if instance.current_status != target_status:
		instance.current_status = target_status
		
		if logger: logger.log("Flow", "Quest '%s' status changed to %d." % [query_id, target_status])
		
		# Prefer logic ID for signals
		var signal_id = instance.quest_id if not instance.quest_id.is_empty() else file_id
		
		if target_status == QWEnums.QuestState.COMPLETED:
			quest_completed.emit(signal_id)
		elif target_status == QWEnums.QuestState.FAILED:
			quest_failed.emit(signal_id)

func get_quest_state(query_id: String) -> int:
	var file_id = _resolve_instance_file_id(query_id)
	if _active_instances.has(file_id):
		return _active_instances[file_id].current_status
	return 0 # INACTIVE

func get_quest_data(query_id: String) -> Dictionary:
	var result = {}
	
	# 1. Static Data (Title/Description)
	var context_node = _id_to_context_node_map.get(query_id)
	if context_node:
		result["title"] = context_node.quest_title
		result["description"] = context_node.quest_description
		result["quest_type"] = context_node.quest_type
	
	# 2. Dynamic Data (Status, Logs)
	var file_id = _resolve_instance_file_id(query_id)
	if _active_instances.has(file_id):
		var instance: QuestInstance = _active_instances[file_id]
		result["id"] = query_id # Keep the requested ID
		result["status"] = instance.current_status
		result["log_entries"] = instance.get_variable("_logs", [])
		
		var runtime_desc = instance.get_variable("_description_override", "")
		if not runtime_desc.is_empty():
			result["description"] = runtime_desc
	else:
		result["id"] = query_id
		result["status"] = 0
		result["log_entries"] = []
	
	return result

func get_all_managed_quests_data() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var processed_nodes: Dictionary = {} # Deduplication Cache
	
	for q_id in _id_to_context_node_map:
		var context_node = _id_to_context_node_map[q_id]
		
		if processed_nodes.has(context_node):
			continue
		
		processed_nodes[context_node] = true
		
		var primary_id = q_id
		if not context_node.quest_id.is_empty():
			primary_id = context_node.quest_id
			
		list.append(get_quest_data(primary_id))
		
	return list

func get_active_objectives_for_quest(query_id: String) -> Array[ObjectiveResource]:
	var objectives: Array[ObjectiveResource] = []
	var file_id = _resolve_instance_file_id(query_id)
	
	if not _active_instances.has(file_id): return objectives
	
	var instance: QuestInstance = _active_instances[file_id]
	
	# Scan active nodes in this instance
	for node_id in instance.active_node_ids:
		var node_def = _node_definitions.get(node_id)
		if node_def is TaskNodeResource:
			# Inject state into temporary objective copies for UI
			for bp_obj in node_def.objectives:
				var obj_status = instance.get_objective_status(bp_obj.id)
				var obj_progress = instance.get_objective_progress(bp_obj.id)
				
				if obj_status == 1: # ACTIVE
					var ui_obj = bp_obj.duplicate()
					ui_obj.current_progress = obj_progress
					ui_obj.status = obj_status
					
					# Resolve Description Override
					ui_obj.description = instance.get_objective_description(bp_obj.id, bp_obj.description)
					
					objectives.append(ui_obj)
					
	return objectives

func get_objective_status(p_objective_id: String) -> int:
	if p_objective_id.is_empty(): return 0
	
	# Search all active instances
	for instance in _active_instances.values():
		var status = instance.get_objective_status(p_objective_id)
		if status != 0:
			return status
	return 0

func set_manual_objective_status(objective_id: String, new_status: int):
	for instance in _active_instances.values():
		if instance.objective_states.has(objective_id):
			instance.set_objective_status(objective_id, new_status)
			
			var signal_id = instance.quest_id if not instance.quest_id.is_empty() else instance.file_id
			quest_data_changed.emit(signal_id)
			
			_check_tasks_in_instance(instance)
			return

func set_quest_description(node_id: String, description: String) -> void:
	var file_id = _get_file_id_for_node(node_id)
	if not file_id.is_empty() and _active_instances.has(file_id):
		var instance = _active_instances[file_id]
		instance.set_variable("_description_override", description)
		
		var signal_id = instance.quest_id if not instance.quest_id.is_empty() else file_id
		quest_data_changed.emit(signal_id)

func add_quest_log_entry(node_id: String, log_text: String) -> void:
	var file_id = _get_file_id_for_node(node_id)
	if not file_id.is_empty() and _active_instances.has(file_id):
		var instance = _active_instances[file_id]
		var logs: Array = instance.get_variable("_logs", [])
		logs.append(log_text)
		instance.set_variable("_logs", logs)
		
		var signal_id = instance.quest_id if not instance.quest_id.is_empty() else file_id
		quest_data_changed.emit(signal_id)

func force_skip_node(node_id: String) -> void:
	var file_id = _get_file_id_for_node(node_id)
	var instance = _active_instances.get(file_id)
	
	if not instance or not instance.is_node_active(node_id): return
	
	var node_def = _node_definitions.get(node_id)
	if not node_def: return

	var logger = _get_logger()
	if logger: logger.log("System", "Force skipping node: %s" % node_id)

	# Cleanup specific blocking behaviors
	if node_def is ShowUIMessageNodeResource:
		if is_instance_valid(_presentation_manager):
			_presentation_manager.force_close_current()
	elif node_def is PlayCutsceneNodeResource:
		var root = get_tree().get_root()
		var anim_player = root.get_node_or_null(node_def.animation_player_path)
		if is_instance_valid(anim_player) and anim_player.is_playing():
			anim_player.seek(anim_player.current_animation_length, true)
			anim_player.stop()

	var global_bus = get_tree().root.get_node_or_null("QuestWeaverGlobal")
	if is_instance_valid(global_bus):
		global_bus.unlock_interaction(node_id)

	complete_node(node_def)

func reset_all_graphs_and_quests():
	var logger = _logger
	if is_instance_valid(logger):
		logger.log("Flow", "Resetting all graphs and quest states.")
	
	_active_instances.clear()
	_timer_manager.clear_all_timers()
	_sync_manager.clear()
	_event_manager.clear()
	_scope_manager.clear()

func start_all_loaded_graphs():
	_ensure_execution_context_exists()
	
	var settings = QWConstants.get_settings()
	if settings and not settings.auto_start_quests.is_empty():
		for raw_path in settings.auto_start_quests:
			if raw_path.is_empty(): continue
			
			var final_path = raw_path
			if raw_path.begins_with("uid://"):
				var id = ResourceLoader.get_resource_uid(raw_path)
				if id != -1: final_path = ResourceUID.get_id_path(id)
			
			if is_instance_valid(_logger):
				_logger.log("System", "Auto-starting: " + final_path)
			_start_specific_graph_entry(final_path)

func start_sub_graph(graph_path: String) -> void:
	if ResourceLoader.exists(graph_path):
		var graph_res = ResourceLoader.load(graph_path)
		_load_graph_data(graph_res)
	else:
		push_error("QuestController: Could not load sub-graph resource at '%s'." % graph_path)
		return
	
	var file_id = graph_path.get_file().get_basename()
	
	# Create Instance if missing, initially INACTIVE
	if not _active_instances.has(file_id):
		var instance = QuestInstance.new(file_id)
		instance.current_status = QWEnums.QuestState.INACTIVE 
		_active_instances[file_id] = instance
		
		if is_instance_valid(_logger):
			_logger.log("Flow", "Sub-Graph: Created instance '%s' (Status: INACTIVE)." % file_id)
	
	var nodes_in_graph = _quest_node_map.get(graph_path, [])
	
	# Try StartNode
	for node_id in nodes_in_graph:
		var node = _node_definitions.get(node_id)
		if node is StartNodeResource:
			_activate_node(node)
			return
	
	# Fallback: QuestContextNode
	for node_id in nodes_in_graph:
		var node = _node_definitions.get(node_id)
		if node is QuestContextNodeResource:
			push_warning("QuestController: Sub-graph '%s' has no StartNode. Starting at QuestContextNode." % graph_path)
			_activate_node(node)
			return
			
	push_error("QuestController: Sub-graph at '%s' has no entry point." % graph_path)

func push_to_call_stack(parent_node_id: String):
	var parent_graph_path = _get_quest_path_for_node(parent_node_id)
	if parent_graph_path.is_empty(): return
		
	var child_path = ""
	var node = _node_definitions.get(parent_node_id)
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
	
	if is_instance_valid(_logger):
		_logger.log("Flow", "Sub-Graph finished. Returning to parent node '%s'." % parent_node_id)
	
	var parent_def = _node_definitions.get(parent_node_id)
	if parent_def:
		complete_node(parent_def)

func jump_to_anchor(origin_node: GraphNodeResource, anchor_name: String) -> void:
	var current_graph_path = _get_quest_path_for_node(origin_node.id)
	if current_graph_path.is_empty(): return

	var node_ids_in_graph = _quest_node_map.get(current_graph_path, [])
	var target_anchor: AnchorNodeResource = null
	
	for id in node_ids_in_graph:
		var def = _node_definitions.get(id)
		if def is AnchorNodeResource and def.anchor_name == anchor_name:
			target_anchor = def
			break
	
	if target_anchor:
		if is_instance_valid(_logger):
			_logger.log("Flow", "  -> JUMPING to Anchor '%s'." % anchor_name)
		_activate_node(target_anchor)
	else:
		push_warning("JumpNode '%s' could not find Anchor '%s'." % [origin_node.id, anchor_name])

## Retrieves a runtime variable from a specific quest instance.
## Returns the default value if the quest is not active or the variable doesn't exist.
func get_quest_variable(query_id: String, key: String, default: Variant = null) -> Variant:
	var file_id = _resolve_instance_file_id(query_id)
	
	if _active_instances.has(file_id):
		var instance: QuestInstance = _active_instances[file_id]
		return instance.get_variable(key, default)
		
	return default

## Returns the current numeric progress of an objective (e.g. 3 out of 5 items).
## Returns 0 if the objective is inactive or not found.
func get_objective_progress(objective_id: String) -> int:
	if objective_id.is_empty(): return 0
	
	# Search in active instances
	# (Optimization potential: Cache ObjectiveID -> InstanceID)
	for instance: QuestInstance in _active_instances.values():
		# Only check if the objective is actually tracked in this instance
		if instance.objective_states.has(objective_id):
			return instance.get_objective_progress(objective_id)
			
	return 0

# --- SAVE / LOAD ---

func get_save_data() -> Dictionary:
	return _persistence_manager.save_state(self)

func load_from_data(data: Dictionary):
	_persistence_manager.load_state(self, data)

# --- CORE LOGIC ---

func _activate_node(node_definition: GraphNodeResource, from_input_port: int = 0) -> void:
	var logger = _logger
	if not is_instance_valid(node_definition): return

	var file_id = _node_to_file_id_map.get(node_definition.id, "")
	var instance: QuestInstance = _active_instances.get(file_id)
	
	if not instance and not (node_definition is QuestContextNodeResource):
		if logger: logger.warn("Flow", "Node '%s' activated but no Quest Instance found." % node_definition.id)
		return

	if logger: logger.log("Flow", "-> Activating Node: '%s' (Blueprint) in Instance '%s'" % [node_definition.id, file_id])
	
	_send_debug_message("node_activated", [node_definition.id]) # pulsate while live-debug
	
	if instance:
		# RE-ENTRY CHECK: Reset old state if loop detected
		if instance.is_node_active(node_definition.id):
			if logger: logger.log("Flow", "   - Node already active. Resetting previous execution state (Re-Entry).")
			_cleanup_node_runtime(node_definition.id, instance)
		
		instance.set_node_active(node_definition.id, true)
		
		if from_input_port > 0:
			instance.set_node_data(node_definition.id, "_entry_port", from_input_port)

	var executor: NodeExecutor = _node_registry.get_executor_for_node(node_definition)
	if executor:
		executor.execute(_execution_context, node_definition, instance)
	else:
		complete_node(node_definition)

func complete_node(node_definition: GraphNodeResource) -> void:
	var logger = _logger
	var file_id = _node_to_file_id_map.get(node_definition.id, "")
	var instance: QuestInstance = _active_instances.get(file_id)
	
	if logger: logger.log("Flow", "<- Completing Node: '%s'" % node_definition.id)
	
	_send_debug_message("node_completed", [node_definition.id]) # mark as complete while live-debug
	
	if instance:
		instance.set_node_active(node_definition.id, false)
	
	if node_definition is EndNodeResource:
		var current_graph_path = _get_quest_path_for_node(node_definition.id)
		_cleanup_graph_instances(current_graph_path)
		
		if not _call_stack.is_empty():
			var top = _call_stack.back()
			if top.child_graph_path == current_graph_path:
				pop_from_call_stack()
				return

	_trigger_next_nodes_from_port(node_definition, 0)

func _mark_node_as_logically_complete(node_definition: GraphNodeResource) -> void:
	_send_debug_message("node_completed", [node_definition.id])
	var file_id = _node_to_file_id_map.get(node_definition.id, "")
	var instance: QuestInstance = _active_instances.get(file_id)
	if instance:
		instance.set_node_active(node_definition.id, false)

func get_quest_id_for_node(node_id: String) -> String:
	return _get_file_id_for_node(node_id) # API legacy alias, actually returns FileID

func _get_file_id_for_node(node_id: String) -> String:
	return _node_to_file_id_map.get(node_id, "")

func _on_objective_in_node_changed(_new_status: int, node: TaskNodeResource, objective: ObjectiveResource):
	var file_id = _get_file_id_for_node(node.id)
	var instance = _active_instances.get(file_id)
	
	if instance:
		var signal_id = instance.quest_id if not instance.quest_id.is_empty() else instance.file_id
		quest_data_changed.emit(signal_id)
	
		var all_complete = true
		for obj in node.objectives:
			if instance.get_objective_status(obj.id) != 2: # 2 = COMPLETED
				all_complete = false
				break
		
		if all_complete:
			complete_node(node)

func _check_tasks_in_instance(instance: QuestInstance):
	for node_id in instance.active_node_ids:
		var node_def = _node_definitions.get(node_id)
		if node_def is TaskNodeResource:
			var all_complete = true
			for obj in node_def.objectives:
				if instance.get_objective_status(obj.id) != 2:
					all_complete = false
					break
			if all_complete:
				complete_node(node_def)

# --- INTERNAL HELPERS ---

func _resolve_instance_file_id(query_id: String) -> String:
	if _active_instances.has(query_id):
		return query_id
	
	for inst in _active_instances.values():
		if inst.quest_id == query_id:
			return inst.file_id
			
	return query_id

func _cleanup_node_runtime(node_id: String, instance: QuestInstance) -> void:
	var node_def = _node_definitions.get(node_id)
	if not node_def: return

	if node_def is TaskNodeResource:
		var executor = _node_registry.get_executor_for_node(node_def)
		if executor and executor.has_method("cleanup_listeners"):
			executor.cleanup_listeners(_execution_context, node_def)
	elif node_def is EventListenerNodeResource:
		_event_manager.unregister_listener(node_def)
	elif node_def is TimerNodeResource:
		_timer_manager.remove_timer(node_id)
	
	instance.set_node_active(node_id, false)

func _ensure_execution_context_exists() -> void:
	if not is_instance_valid(_execution_context):
		var services = _get_services()
		var game_state_instance = null
		if services:
			game_state_instance = services.get_game_state()
		
		_execution_context = ExecutionContext.new(self, game_state_instance, _logger, services)

func _load_auto_start_graphs() -> void:
	var settings = QWConstants.get_settings()
	if not is_instance_valid(settings): return

	var paths: Array[String] = []
	for raw_path in settings.auto_start_quests:
		if not raw_path.is_empty():
			var p = raw_path
			if p.begins_with("uid://"):
				var id = ResourceLoader.get_resource_uid(p)
				if id != -1: p = ResourceUID.get_id_path(id)
			paths.append(p)
	
	for path in paths:
		if ResourceLoader.exists(path):
			var res = ResourceLoader.load(path, "QuestGraphResource")
			_load_graph_data(res)

func _load_graph_data(graph_resource: QuestGraphResource):
	var path = graph_resource.resource_path
	if _quest_node_map.has(path): return 
	
	_quest_node_map[path] = []
	var file_id = path.get_file().get_basename()
	
	# 1. Map Context Nodes (Logical ID -> Node Resource)
	for node_id in graph_resource.nodes:
		var node = graph_resource.nodes[node_id]
		if node is QuestContextNodeResource:
			var logical_id = node.quest_id
			if not logical_id.is_empty():
				_id_to_context_node_map[logical_id] = node
			
			# Fallback mapping
			if logical_id != file_id:
				_id_to_context_node_map[file_id] = node
			break
	
	# 2. Register Nodes & File ID Mapping
	for node_id in graph_resource.nodes:
		var node = graph_resource.nodes[node_id]
		if is_instance_valid(node):
			_node_definitions[node_id] = node
			_quest_node_map[path].append(node_id)
			_node_to_file_id_map[node_id] = file_id 

	for connection in graph_resource.connections:
		var from_id = connection.get("from_node")
		if not _node_connections.has(from_id):
			_node_connections[from_id] = []
		_node_connections[from_id].append(connection)

func _start_specific_graph_entry(graph_path: String) -> void:
	if not _quest_node_map.has(graph_path):
		if ResourceLoader.exists(graph_path):
			var res = ResourceLoader.load(graph_path)
			_load_graph_data(res)
	
	var file_id = graph_path.get_file().get_basename()
	var nodes = _quest_node_map.get(graph_path, [])
	var start_node_def: StartNodeResource = null
	
	for id in nodes:
		var node = _node_definitions.get(id)
		if node is StartNodeResource:
			start_node_def = node
			break
	
	if start_node_def:
		if not _active_instances.has(file_id):
			var instance = QuestInstance.new(file_id)
			instance.current_status = QWEnums.QuestState.ACTIVE
			_active_instances[file_id] = instance
			
			if is_instance_valid(_logger):
				_logger.log("Flow", "Auto-Start: Created implicit instance for '%s'." % file_id)
				
			quest_started.emit(file_id)
			quest_data_changed.emit(file_id)
		
		_activate_node(start_node_def)
	else:
		push_warning("QuestController: Auto-start graph '%s' has no StartNode." % graph_path)

func _trigger_next_nodes_from_port(from_node: GraphNodeResource, from_port_index: int):
	var logger = _logger
	if logger: logger.log("Flow", "    - Triggering next nodes from '%s' port %d..." % [from_node.id, from_port_index])
	
	var connections = _node_connections.get(from_node.id, [])
	for connection in connections:
		if connection.get("from_port") == from_port_index:
			var next_node_id = connection.get("to_node")
			var to_port = connection.get("to_port", 0)
			var next_node_def = _node_definitions.get(next_node_id)
			if next_node_def:
				_activate_node(next_node_def, to_port)

func _cleanup_graph_instances(graph_path: String) -> void:
	var file_id_to_cleanup = graph_path.get_file().get_basename()
	
	if _active_instances.has(file_id_to_cleanup):
		var instance = _active_instances[file_id_to_cleanup]
		
		for node_id in instance.active_node_ids:
			_cleanup_node_runtime(node_id, instance)
		
		instance.active_node_ids.clear()
		
		var keep_in_memory = not instance.quest_id.is_empty() or \
							 instance.current_status != QWEnums.QuestState.INACTIVE
		
		if keep_in_memory:
			if is_instance_valid(_logger):
				_logger.log("System", "Graph finished but Instance '%s' kept in memory (Status: %d)." % [file_id_to_cleanup, instance.current_status])
		else:
			_active_instances.erase(file_id_to_cleanup)
			if is_instance_valid(_logger):
				_logger.log("System", "Graph finished and Instance '%s' garbage collected." % file_id_to_cleanup)

func _get_quest_path_for_node(node_id: String) -> String:
	for path in _quest_node_map:
		if _quest_node_map[path].has(node_id):
			return path
	return ""

func _on_interacted_with_object(interacted_node: Node):
	if not is_instance_valid(_execution_context): return
	var path = str(interacted_node.get_path())
	
	if _execution_context.interact_objective_listeners.has(path):
		var wrappers = _execution_context.interact_objective_listeners[path]
		for w in wrappers:
			var obj: ObjectiveResource = w.objective
			var instance: QuestInstance = _active_instances.get(w.quest_id)
			
			if not instance:
				# Fallback resolution
				instance = _active_instances.get(w.file_id)

			if instance:
				instance.set_objective_status(obj.id, 2)
				_check_tasks_in_instance(instance)

func _on_enemy_was_killed(enemy_id: String):
	if not is_instance_valid(_execution_context): return
	if _execution_context.kill_objective_listeners.has(enemy_id):
		var wrappers = _execution_context.kill_objective_listeners[enemy_id]
		for w in wrappers:
			var obj: ObjectiveResource = w.objective
			var instance = _active_instances.get(w.file_id)
			
			if instance:
				var current = instance.get_objective_progress(obj.id)
				current += 1
				instance.set_objective_progress(obj.id, current)
				
				var sig_id = instance.quest_id if not instance.quest_id.is_empty() else instance.file_id
				quest_data_changed.emit(sig_id)
				
				var params = w.get("resolved_params", obj.trigger_params)
				# Prio: 1. resolved param 'amount', 2. static 'required_progress'
				var required = int(params.get("amount", obj.required_progress))
				
				if current >= required:
					instance.set_objective_status(obj.id, 2)
					_check_tasks_in_instance(instance)

func _on_entered_location(location_id: String):
	if not is_instance_valid(_execution_context): return
	if _execution_context.location_objective_listeners.has(location_id):
		var wrappers = _execution_context.location_objective_listeners[location_id]
		for w in wrappers:
			var obj: ObjectiveResource = w.objective
			var instance = _active_instances.get(w.file_id)
			
			if instance:
				instance.set_objective_status(obj.id, 2)
				_check_tasks_in_instance(instance)

func _check_item_collect_objectives():
	if not is_instance_valid(_execution_context) or not is_instance_valid(_inventory_adapter): return
	
	var item_ids = _execution_context.item_objective_listeners.keys()
	for item_id in item_ids:
		var current_amount = _inventory_adapter.count_item(item_id)
		var wrappers = _execution_context.item_objective_listeners[item_id]
		
		for w in wrappers:
			var obj: ObjectiveResource = w.objective
			var fid = _resolve_instance_file_id(w.file_id)
			var instance = _active_instances.get(fid)
			
			var params = w.get("resolved_params", obj.trigger_params)
			
			if instance:
				var snapshot_key = "start_amount_%s" % obj.id
				var start_amount = instance.get_node_data(w.task_node_id, snapshot_key, 0)
				
				var collected = current_amount
				if obj.track_progress_since_activation:
					collected = max(0, current_amount - start_amount)
				
				var required = int(params.get("amount", 1))
				var progress = min(collected, required)
				
				if instance.get_objective_progress(obj.id) != progress:
					instance.set_objective_progress(obj.id, progress)
					var sig_id = instance.quest_id if not instance.quest_id.is_empty() else instance.file_id
					quest_data_changed.emit(sig_id)
				
				if collected >= required:
					if instance.get_objective_status(obj.id) != 2:
						instance.set_objective_status(obj.id, 2)
						_check_tasks_in_instance(instance)

func _send_debug_message(message: String, data: Array = []) -> void:
	if not OS.is_debug_build(): return
	if not EngineDebugger.is_active(): return
	EngineDebugger.send_message("quest_weaver:%s" % message, data)
