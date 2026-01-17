# res://addons/quest_weaver/nodes/action/play_cutscene_node/play_cutscene_node_executor.gd
class_name PlayCutsceneNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var cutscene_node = node as PlayCutsceneNodeResource
	if not is_instance_valid(cutscene_node): return

	var controller = context.quest_controller
	var root = controller.get_tree().get_root()
	if not root:
		push_error("PlayCutsceneNode: Could not find the scene tree root.")
		controller._trigger_next_nodes_from_port(cutscene_node, 1)
		controller._mark_node_as_complete(cutscene_node)
		return

	var anim_player: AnimationPlayer = root.get_node_or_null(cutscene_node.animation_player_path)
	
	if not is_instance_valid(anim_player):
		push_error("PlayCutsceneNode '%s': AnimationPlayer at path '%s' not found." % [cutscene_node.id, cutscene_node.animation_player_path])
		controller._trigger_next_nodes_from_port(cutscene_node, 1)
		controller._mark_node_as_complete(cutscene_node)
		return

	if not anim_player.has_animation(cutscene_node.animation_name):
		push_error("PlayCutsceneNode '%s': Animation '%s' not found in AnimationPlayer." % [cutscene_node.id, cutscene_node.animation_name])
		controller._trigger_next_nodes_from_port(cutscene_node, 1)
		controller._mark_node_as_complete(cutscene_node)
		return

	# --- GLOBAL LOCK START ---
	if cutscene_node.wait_for_completion:
		var global_bus = controller.get_tree().root.get_node_or_null("QuestWeaverGlobal")
		if is_instance_valid(global_bus):
			global_bus.lock_interaction(cutscene_node.id)
	# -------------------------

	controller._trigger_next_nodes_from_port(cutscene_node, 0)
	anim_player.play(cutscene_node.animation_name)

	if cutscene_node.wait_for_completion:
		await anim_player.animation_finished
		
		# --- GLOBAL LOCK END ---
		var global_bus = controller.get_tree().root.get_node_or_null("QuestWeaverGlobal")
		if is_instance_valid(global_bus):
			global_bus.unlock_interaction(cutscene_node.id)
		# -----------------------
		
		var logger = context.logger
		if is_instance_valid(logger):
			logger.log("Executor", "  - PlayCutsceneNode '%s' finished waiting." % cutscene_node.id)
		
		# Only complete if still active (not skipped)
		if controller._active_nodes.has(cutscene_node.id):
			controller._trigger_next_nodes_from_port(cutscene_node, 1) # Port 1: "On Finish"
			controller._mark_node_as_complete(cutscene_node)
	else:
		# Fire and Forget logic
		anim_player.animation_finished.connect(
			func(_anim_name):
				if controller._active_nodes.has(cutscene_node.id):
					controller._trigger_next_nodes_from_port(cutscene_node, 1) # Port 1: "On Finish"
					controller._mark_node_as_complete(cutscene_node), 
			CONNECT_ONE_SHOT
		)
