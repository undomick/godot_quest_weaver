# res://addons/quest_weaver/nodes/action/show_ui_message_node/show_ui_message_node_executor.gd
class_name ShowUIMessageNodeExecutor
extends NodeExecutor

func execute(context: ExecutionContext, node: GraphNodeResource) -> void:
	var msg_node = node as ShowUIMessageNodeResource
	if not is_instance_valid(msg_node): return

	# FIX: Safe Dynamic Lookup for PresentationManager
	# We avoid accessing QuestWeaverServices statically to prevent import errors on fresh installs.
	var main_loop = Engine.get_main_loop()
	var presentation_manager = null
	if main_loop and main_loop.root:
		var services = main_loop.root.get_node_or_null("QuestWeaverServices")
		if is_instance_valid(services):
			presentation_manager = services.presentation_manager

	if not is_instance_valid(presentation_manager):
		push_warning("ShowUIMessageNodeExecutor: PresentationManager not found via Services.")
		context.quest_controller.complete_node(msg_node)
		return

	var presentation_data = {
		"_node_id": msg_node.id, # Pass the Node ID as a token
		
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
		_wait_and_complete(presentation_manager, context, msg_node)
	else:
		context.quest_controller.complete_node(msg_node)

func _wait_and_complete(p_manager: Node, p_context: ExecutionContext, p_node: ShowUIMessageNodeResource) -> void:
	# Loop until WE are the ones who finished.
	# This ignores signals from other messages that might finish before us or during our wait.
	while true:
		var finished_id = await p_manager.presentation_completed
		if finished_id == p_node.id:
			break
	
	if is_instance_valid(p_context.quest_controller) and p_context.quest_controller._active_nodes.has(p_node.id):
		p_context.quest_controller.complete_node(p_node)
