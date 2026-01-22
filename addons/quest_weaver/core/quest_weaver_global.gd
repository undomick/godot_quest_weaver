# res://addons/quest_weaver/core/quest_weaver_global.gd
extends Node

## Global Event Bus and Facade for Quest Weaver.
## Provides easy access to quest states, variables and flow control.

# --- SIGNALS ---
signal quest_event_fired(event_name: String, payload: Dictionary)
signal interacted_with_object(node: Node)
signal enemy_was_killed(enemy_id: String)
signal entered_location(location_id: String)
signal interaction_lock_changed(is_locked: bool)
signal quest_objective_progress_changed(quest_id: String, objective_id: String, current_progress: int, max_progress: int)
signal quest_objective_state_changed(quest_id: String, objective_id: String, new_status: int)

# --- PROPERTIES ---

## If true, Quest Weaver considers the game in a "blocking" state (Cutscene, Dialog).
var is_locked: bool = false

## If true, ShowUIMessage nodes will complete immediately without showing anything.
var are_notifications_suppressed: bool = false

# --- INTERNAL REFERENCES ---
var _current_blocker_node_id: String = ""
var _controller_weak: WeakRef = null  # Weak reference to QuestController

func register_controller(controller: Node) -> void:
	_controller_weak = weakref(controller)

# ==============================================================================
# 1. STATE QUERIES (Read-Only)
# ==============================================================================

func is_quest_active(quest_id: String) -> bool:
	return get_quest_state(quest_id) == 1 # 1 = ACTIVE (QWEnums.QuestState)

func is_quest_completed(quest_id: String) -> bool:
	return get_quest_state(quest_id) == 2 # 2 = COMPLETED

func is_quest_failed(quest_id: String) -> bool:
	return get_quest_state(quest_id) == 3 # 3 = FAILED

## Returns the raw enum value (0=INACTIVE, 1=ACTIVE, 2=COMPLETED, 3=FAILED).
func get_quest_state(quest_id: String) -> int:
	var controller = _get_controller_safe()
	if not controller: return 0
	
	return controller.get_quest_state(quest_id)

## Checks if a specific objective is marked complete (Status 2).
func is_objective_completed(objective_id: String) -> bool:
	var controller = _get_controller_safe()
	if not controller: return false
	
	# 2 = ObjectiveResource.Status.COMPLETED
	return controller.get_objective_status(objective_id) == 2

## Returns the current progress count of an objective.
func get_objective_progress(objective_id: String) -> int:
	var controller = _get_controller_safe()
	if controller:
		return controller.get_objective_progress(objective_id)
	return 0

## Retrieves a runtime variable from a specific quest instance.
func get_quest_variable(quest_id: String, key: String, default: Variant = null) -> Variant:
	var controller = _get_controller_safe()
	if controller:
		return controller.get_quest_variable(quest_id, key, default)
	return default

# ==============================================================================
# 2. VARIABLE ACCESS (GameState Bridge)
# ==============================================================================

func set_variable(key: String, value: Variant) -> void:
	var gs = _get_gamestate_safe()
	if gs and gs.has_method("set_variable"):
		gs.set_variable(key, value)

func get_variable(key: String, default: Variant = null) -> Variant:
	var gs = _get_gamestate_safe()
	if gs and gs.has_method("get_variable"):
		return gs.get_variable(key, default)
	return default

# ==============================================================================
# 3. MANUAL TRIGGERS & CONTROL
# ==============================================================================

## Starts a quest by its Logical ID (QuestContext). Auto-loads if registered.
func start_quest_id(quest_id: String) -> void:
	var controller = _get_controller_safe()
	if controller: controller.start_quest_id(quest_id)

## Starts a quest by its File Name (without .quest). Does NOT auto-load from registry reliably.
func start_quest_file(file_id: String) -> void:
	var controller = _get_controller_safe()
	if controller: controller.start_quest_file(file_id)

## Restarts a quest by ID (Full Reset). Use it for Debug.
func restart_quest_id(quest_id: String) -> void:
	var controller = _get_controller_safe()
	if controller: controller.restart_quest_id(quest_id)

func restart_quest_file(file_id: String) -> void:
	var controller = _get_controller_safe()
	if controller: controller.restart_quest_file(file_id)

## Starts a quest with parameters (Templates). Uses Logical ID preference.
func start_quest_with_parameters(quest_id: String, params: Dictionary) -> void:
	var controller = _get_controller_safe()
	if controller: controller.start_quest_with_parameters(quest_id, params)

## Completes a quest. Success=true -> COMPLETED, Success=false -> FAILED.
func complete_quest_id(quest_id: String, success: bool = true) -> void:
	var controller = _get_controller_safe()
	if controller: controller.complete_quest_id(quest_id, success)

func complete_quest_file(file_id: String, success: bool = true) -> void:
	var controller = _get_controller_safe()
	if controller: controller.complete_quest_file(file_id, success)

## Manually completes a specific objective by ID.
func complete_objective(objective_id: String) -> void:
	var controller = _get_controller_safe()
	if controller: controller.set_manual_objective_status(objective_id, 2)

## Debug: Jump to node
func jump_to_node(node_id: String) -> void:
	var controller = _get_controller_safe()
	if controller: controller.jump_to_node(node_id)

# ==============================================================================
# 4. FLOW CONTROL (Locking & Skipping)
# ==============================================================================

## Call this to force-skip the currently blocking action (Cutscene/Dialog).
func skip_action() -> void:
	if is_locked and not _current_blocker_node_id.is_empty():
		var controller = _get_controller_safe()
		if controller:
			controller.force_skip_node(_current_blocker_node_id)

## Internal: Called by Nodes.
func lock_interaction(node_id: String) -> void:
	if is_locked: return
	is_locked = true
	_current_blocker_node_id = node_id
	interaction_lock_changed.emit(true)

## Internal: Called by Nodes.
func unlock_interaction(node_id: String) -> void:
	if _current_blocker_node_id == node_id:
		is_locked = false
		_current_blocker_node_id = ""
		interaction_lock_changed.emit(false)

# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

func _get_controller_safe() -> QuestController:
	if _controller_weak:
		return _controller_weak.get_ref() as QuestController
	return null

func _get_gamestate_safe() -> Node:
	# Fallback lookup if services aren't injected
	var services = get_tree().root.get_node_or_null("QuestWeaverServices")
	if services and services.has_method("get_game_state"):
		return services.get_game_state()
	return null

## Gracefully shuts down the Quest Weaver system and then quits the application.
## Use this instead of get_tree().quit() to prevent memory leaks in debug builds.
func quit_game() -> void:
	var controller = _get_controller_safe()
	if is_instance_valid(controller) and controller.has_method("shutdown"):
		controller.shutdown()
	
	await get_tree().process_frame
	get_tree().quit()

## Returns a proxy via Quest ID (Registry Lookup).
## Usage: QuestWeaverGlobal.quest_id("the_rat_killer").start()
func quest_id(quest_id: String) -> QuestProxy:
	var controller = _get_controller_safe()
	if controller:
		return QuestProxy.new(quest_id, controller, false)
	return QuestProxy.new(quest_id, null, false)

## Returns a proxy via Filename (Direct File Access).
## Usage: QuestWeaverGlobal.quest_file("main_quest_act1").start()
func quest_file(filename_id: String) -> QuestProxy:
	var controller = _get_controller_safe()
	if controller:
		return QuestProxy.new(filename_id, controller, true)
	return QuestProxy.new(filename_id, null, true)
