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

# --- PROPERTIES ---

## If true, Quest Weaver considers the game in a "blocking" state (Cutscene, Dialog).
var is_locked: bool = false

## If true, ShowUIMessage nodes will complete immediately without showing anything.
var are_notifications_suppressed: bool = false

# --- INTERNAL REFERENCES ---
var _current_blocker_node_id: String = ""
var _controller_ref: Node = null # Weak reference to QuestController

func register_controller(controller: Node) -> void:
	_controller_ref = controller

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
	
	# Optimization: Call dedicated method instead of fetching full data dict
	if controller.has_method("get_quest_state"):
		return controller.get_quest_state(quest_id)
		
	return 0

## Checks if a specific objective is marked complete (Status 2).
func is_objective_completed(objective_id: String) -> bool:
	var controller = _get_controller_safe()
	if not controller: return false
	
	if controller.has_method("get_objective_status"):
		# 2 = ObjectiveResource.Status.COMPLETED
		return controller.get_objective_status(objective_id) == 2
	return false

## Returns the current progress count of an objective.
func get_objective_progress(objective_id: String) -> int:
	var controller = _get_controller_safe()
	if controller and controller.has_method("get_objective_progress"):
		return controller.get_objective_progress(objective_id)
	return 0

## Retrieves a runtime variable from a specific quest instance.
func get_quest_variable(quest_id: String, key: String, default: Variant = null) -> Variant:
	var controller = _get_controller_safe()
	if controller and controller.has_method("get_quest_variable"):
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
# 3. MANUAL TRIGGERS (Cheats / Debug / Edge Cases)
# ==============================================================================

## Manually starts a quest by ID (if it exists in the definitions).
func start_quest(quest_id: String) -> void:
	var controller = _get_controller_safe()
	if controller and controller.has_method("start_quest_by_id"):
		controller.start_quest_by_id(quest_id)

## Starts a quest with parameters (Templates).
## Example: start_quest_with_parameters("fetch_generic", {"item": "apple", "amount": 10})
func start_quest_with_parameters(quest_id: String, params: Dictionary) -> void:
	var controller = _get_controller_safe()
	if controller and controller.has_method("start_quest_with_parameters"):
		controller.start_quest_with_parameters(quest_id, params)

## Resets and restarts a quest from the beginning.
func restart_quest(quest_id: String) -> void:
	var controller = _get_controller_safe()
	if controller: controller.restart_quest(quest_id)

## Forces the quest flow to jump to a specific node (Debug/Cheat).
func jump_to_node(node_id: String) -> void:
	var controller = _get_controller_safe()
	if controller: controller.jump_to_node(node_id)

## Completes a quest successfully.
func finish_quest(quest_id: String) -> void:
	var controller = _get_controller_safe()
	if controller: controller.finish_quest(quest_id)

## Marks a quest as failed.
func fail_quest(quest_id: String) -> void:
	var controller = _get_controller_safe()
	if controller: controller.fail_quest(quest_id)

## Manually completes a specific objective by ID.
func complete_objective(objective_id: String) -> void:
	var controller = _get_controller_safe()
	if controller and controller.has_method("set_manual_objective_status"):
		# 2 = COMPLETED
		controller.set_manual_objective_status(objective_id, 2)

# ==============================================================================
# 4. FLOW CONTROL (Locking & Skipping)
# ==============================================================================

## Call this to force-skip the currently blocking action (Cutscene/Dialog).
func skip_action() -> void:
	if is_locked and not _current_blocker_node_id.is_empty():
		var controller = _get_controller_safe()
		if controller and controller.has_method("force_skip_node"):
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

func _get_controller_safe() -> Node:
	if is_instance_valid(_controller_ref):
		return _controller_ref
	return null

func _get_gamestate_safe() -> Node:
	# Fallback lookup if services aren't injected
	var services = get_tree().root.get_node_or_null("QuestWeaverServices")
	if services and services.has_method("get_game_state"):
		return services.get_game_state()
	return null
