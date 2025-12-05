# res://addons/quest_weaver/systems/managers/quest_timer_manager.gd
class_name QuestTimerManager
extends Object

## Manages all active TimerNode instances for a QuestController.

var _active_timers: Dictionary = {} # { "node_id": { "timer_node": Timer, "ticks_elapsed": 0, "node_instance": TimerNodeResource } }
var _controller: QuestController

func _init(p_controller: QuestController):
	self._controller = p_controller

## Starts a new timer based on a TimerNode instance.
func start_timer(node_instance: TimerNodeResource):
	if _active_timers.has(node_instance.id):
		push_warning("TimerNode '%s' is already active." % node_instance.id)
		return

	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = false
	
	# Important: Connect the signal to the _on_timer_tick method of THIS manager.
	timer.timeout.connect(_on_timer_tick.bind(node_instance.id))
	
	# Important: The timer must be a child of the controller to exist in the SceneTree.
	_controller.add_child(timer)
	
	_active_timers[node_instance.id] = {
		"timer_node": timer,
		"ticks_elapsed": 0,
		"node_instance": node_instance
	}
	
	# The controller must still trigger the "On Start" output immediately.
	_controller._trigger_next_nodes_from_port(node_instance, 0) # Port 0: "On Start"
	
	timer.start()

## Stops and removes a specific timer based on its node ID.
func remove_timer(node_id: String) -> bool:
	if _active_timers.has(node_id):
		var timer_data = _active_timers[node_id]
		if is_instance_valid(timer_data.timer_node):
			timer_data.timer_node.queue_free()
		_active_timers.erase(node_id)
		return true # Returns true if a timer was removed.
	return false

## Called every second by a running timer.
func _on_timer_tick(node_id: String):
	if not _active_timers.has(node_id): return

	var timer_data = _active_timers[node_id]
	timer_data.ticks_elapsed += 1
	
	var node_instance: TimerNodeResource = timer_data.node_instance
	var logger = _controller._get_logger() # Safe access via controller helper
	
	if logger:
		logger.log("Flow", "  - TimerNode '%s' ticked. (%d/%d)" % [node_id, timer_data.ticks_elapsed, node_instance.duration])

	_controller._trigger_next_nodes_from_port(node_instance, 1) # Port 1: "On Tick"

	if timer_data.ticks_elapsed >= node_instance.duration:
		if logger: 
			logger.log("Flow", "  <- TimerNode '%s' finished." % node_id)
		
		_controller._trigger_next_nodes_from_port(node_instance, 2) # Port 2: "On Finish"
		
		var timer_node: Timer = timer_data.timer_node
		timer_node.stop()
		timer_node.queue_free()
		
		_active_timers.erase(node_id)
		
		# The controller is still responsible for managing the node status.
		node_instance.status = GraphNodeResource.Status.COMPLETED
		_controller._completed_nodes[node_instance.id] = node_instance
		if _controller._active_nodes.has(node_instance.id):
			_controller._active_nodes.erase(node_instance.id)

## Cleans up all running timers. Required when reloading/resetting.
func clear_all_timers():
	for timer_data in _active_timers.values():
		if is_instance_valid(timer_data.timer_node):
			timer_data.timer_node.queue_free()
	_active_timers.clear()

## Returns data of active timers for the save system.
func get_save_data() -> Dictionary:
	var timers_to_save = {}
	for node_id in _active_timers:
		timers_to_save[node_id] = _active_timers[node_id].ticks_elapsed
	return timers_to_save

## Restores timers from save data.
func load_save_data(timers_to_load: Dictionary, active_nodes: Dictionary):
	for node_id in timers_to_load:
		var node_instance = active_nodes.get(node_id)
		if is_instance_valid(node_instance) and node_instance is TimerNodeResource:
			start_timer(node_instance) # Calls our own method
			if _active_timers.has(node_id):
				_active_timers[node_id].ticks_elapsed = timers_to_load[node_id]
