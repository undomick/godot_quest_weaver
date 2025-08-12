# res://addons/quest_weaver/examples/scenes/main_quest_test.gd
extends Node

# This scene demonstrates how to interact with the QuestWeaver system from your game.
# The correct way is to use the global signals provided by QuestWeaverGlobal.
# This keeps your game code decoupled from the internal quest logic.

var inventory_controller: Node


func _ready() -> void:
	# NEW: We find the inventory controller when the scene starts.
	# The adapter looks for it via the group, so we do the same here.
	# This is more robust than a fixed node path.
	inventory_controller = get_tree().get_first_node_in_group("inventory_controller")
	if not is_instance_valid(inventory_controller):
		push_error("Test Scene: Could not find the 'inventory_controller' in the scene!")

func _unhandled_input(event: InputEvent): 
	# --- Example 1: Firing a generic quest event ---
	# This can be used to trigger EventListenerNodes in your quests.
	if event.is_action_pressed("ui_accept"):
		var event_name = "test_button_pressed"
		var payload = {"button": "accept", "timestamp": Time.get_unix_time_from_system()}
		
		print("--- [Test Scene] Firing global quest event: '%s' ---" % event_name)
		QuestWeaverServices.logger.log("Flow", "--- [Test Scene] Firing global quest event: '%s' ---" % event_name)
		QuestWeaverGlobal.quest_event_fired.emit(event_name, payload)

	# --- Example 2: Adding an item to the inventory ---
	# This simulates collecting "metal_scraps".
	# The quest system will automatically react to this if a corresponding objective is active.
	if event.is_action_pressed("ui_left"):
		if not is_instance_valid(inventory_controller):
			return
			
		var item_id_to_give = "metal_scraps"
		var amount_to_give = 1
		
		print("--- [Test Scene] Simulating collection of: %d x '%s' ---" % [amount_to_give, item_id_to_give])
		
		# We call the inventory controller's function directly.
		inventory_controller.give_item(item_id_to_give, amount_to_give)

	# --- Example 3: Simulating an enemy kill ---
	# This can be used to update objectives in TaskNodes that require killing specific enemies.
	if event.is_action_pressed("ui_right"): 
		var enemy_id_to_kill = "goblin_scout"
		print("--- [Test Scene] Simulating enemy kill: '%s' ---" % enemy_id_to_kill)
		QuestWeaverServices.logger.log("Inventory", "--- [Test Scene] Simulating enemy kill: '%s' ---" % enemy_id_to_kill)
		QuestWeaverGlobal.enemy_was_killed.emit(enemy_id_to_kill)
