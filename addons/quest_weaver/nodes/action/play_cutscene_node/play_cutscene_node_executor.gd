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
		# --- In case of error, trigger "On Finish" (Port 1) ---
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

	controller._trigger_next_nodes_from_port(cutscene_node, 0)
	anim_player.play(cutscene_node.animation_name)

	if cutscene_node.wait_for_completion:
		_wait_for_animation_and_complete(anim_player, cutscene_node, controller)
	else:
		# The non-blocking variant also handles the "On Finish" trigger.
		anim_player.animation_finished.connect(
			func(_anim_name):
				controller._trigger_next_nodes_from_port(cutscene_node, 1) # Port 1: "On Finish"
				controller._mark_node_as_complete(cutscene_node), CONNECT_ONE_SHOT
		)

# This private helper function remains unchanged.
func _wait_for_animation_and_complete(anim_player: AnimationPlayer, node_instance: PlayCutsceneNodeResource, controller: QuestController):
	await anim_player.animation_finished
	
	var logger = QuestWeaverServices.logger
	if is_instance_valid(logger):
		logger.log("Executor", "  - PlayCutsceneNode '%s' finished waiting." % node_instance.id)
	
	controller._trigger_next_nodes_from_port(node_instance, 1) # Port 1: "On Finish"
	controller._mark_node_as_complete(node_instance)
