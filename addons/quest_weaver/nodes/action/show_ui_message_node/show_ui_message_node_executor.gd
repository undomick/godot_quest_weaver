# res://addons/quest_weaver/nodes/action/show_ui_message_node/show_ui_message_node_executor.gd
class_name ShowUIMessageNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var msg_node = node as ShowUIMessageNodeResource
	if not is_instance_valid(msg_node): return
	
	# --- NEW: SUPPRESSION CHECK ---
	var global_bus = context.services.get_tree().root.get_node_or_null("QuestWeaverGlobal")
	if is_instance_valid(global_bus) and global_bus.are_notifications_suppressed:
		# If suppressed, we treat it as if it completed instantly.
		# We do NOT show UI and do NOT lock the game.
		if is_instance_valid(context.logger):
			context.logger.log("Flow", "Suppressed UI Message '%s' due to global setting." % msg_node.id)
		
		context.quest_controller.complete_node(msg_node)
		return
	# ------------------------------
	
	var presentation_manager = null
	if is_instance_valid(context.services):
		presentation_manager = context.services.presentation_manager

	if not is_instance_valid(presentation_manager):
		push_warning("ShowUIMessageNodeExecutor: PresentationManager not found via Services.")
		context.quest_controller.complete_node(msg_node)
		return

	# --- GLOBAL LOCK START ---
	# If we wait, we treat this as a blocking interaction (cutscene/dialogue)
	if msg_node.wait_for_completion:
		if is_instance_valid(global_bus):
			global_bus.lock_interaction(msg_node.id)
	# -------------------------

	var presentation_data = {
		"_node_id": msg_node.id, # Pass Token for matching
		
		"type": msg_node.message_type,
		"title": msg_node.title_override,
		"message": msg_node.message_override,
		
		"anim_in": msg_node.animation_in,
		"ease_in": msg_node.ease_in,
		"per_character_in": msg_node.per_character_in,
		
		"anim_out": msg_node.animation_out,
		"ease_out": msg_node.ease_out,
		"per_character_out": msg_node.per_character_out,
		
		"duration_in": msg_node.duration_in,
		"duration_out": msg_node.duration_out,
		"delay_title_message": msg_node.delay_title_message,
		"hold_duration": msg_node.hold_duration,
		"character_stagger_ms": msg_node.character_stagger_ms
	}

	presentation_manager.queue_presentation(presentation_data)

	if msg_node.wait_for_completion:
		msg_node.status = GraphNodeResource.Status.ACTIVE
		
		# Wait loop: Only proceed if the signal returns THIS node's ID
		while true:
			var finished_id = await presentation_manager.presentation_completed
			if finished_id == msg_node.id:
				break
		
		# --- GLOBAL LOCK END ---
		if is_instance_valid(global_bus):
			global_bus.unlock_interaction(msg_node.id)
		# -----------------------
		
		# Check if node is still relevant (might have been skipped/reset externally)
		if is_instance_valid(context.quest_controller) and context.quest_controller._active_nodes.has(msg_node.id):
			context.quest_controller.complete_node(msg_node)
	else:
		context.quest_controller.complete_node(msg_node)
