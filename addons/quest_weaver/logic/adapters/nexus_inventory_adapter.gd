# res://addons/quest_weaver/logic/nexus_inventory_adapter.gd
@tool
class_name NexusInventoryAdapter
extends QuestInventoryAdapterBase

var _inv_controller = null
var _item_registry = null
var _player_inventory_data = null
var _is_initialized_successfully := false

# This adapter isn't necessary for Quest Weaver to operate. 
# It is a bridge to my other plugin "Nexus Inventory". You can ignore it for now.

func initialize() -> void:
	if not Engine.has_singleton("NexusServices") or not Engine.has_singleton("GameManager"):
		push_error("QuestWeaver (NexusInventoryAdapter): The 'NexusServices' or 'GameManager' autoloads were not found. This adapter will not function.")
		return
		
	# Now that we know they exist, we get them using a string. This is also safe.
	var nexus_services = Engine.get_singleton("NexusServices")
	var game_manager = Engine.get_singleton("GameManager")
	
	_inv_controller = nexus_services.inventory_controller
	_item_registry = game_manager.item_registry
	_player_inventory_data = game_manager.player_inventory_data

	# Validate that all required components are valid
	if not is_instance_valid(_inv_controller) or not is_instance_valid(_item_registry) or not is_instance_valid(_player_inventory_data):
		push_error("QuestWeaver (NexusInventoryAdapter): One of the required components (InventoryController, ItemRegistry, PlayerInventoryData) is invalid. The adapter will not function.")
		return

	# Connect the signal for inventory updates
	if not _player_inventory_data.is_connected("updated", Callable(self, "_on_inventory_updated")):
		_player_inventory_data.updated.connect(_on_inventory_updated)
	
	_is_initialized_successfully = true
	QuestWeaverServices.logger.log("Inventory", "NexusInventoryAdapter initialized and connected to signals successfully.")

# This function is called when the inventory data resource emits its 'updated' signal.
func _on_inventory_updated():
	inventory_updated.emit()

# Counts the total amount of a specific item in the player's inventory.
func count_item(item_id: String) -> int:
	if not _is_initialized_successfully: return 0
	
	var count = 0
	for item in _player_inventory_data.items:
		if is_instance_valid(item) and item.definition_id == item_id:
			count += item.stack_size
	return count

# Gives a specified amount of an item to the player.
func give_item(item_id: String, amount: int) -> void:
	if not _is_initialized_successfully: return
	
	var definition = _item_registry.find(item_id)
	if not is_instance_valid(definition):
		QuestWeaverServices.logger.warn("Inventory", "give_item: Could not find ItemDefinition '%s'." % item_id)
		return
	
	var logger = QuestWeaverServices.logger
	var count_before = count_item(item_id)
	var remaining_amount = amount
	
	# Phase 1: Merging with existing stacks
	if definition.max_stack_size > 1:
		for existing_item in _player_inventory_data.items:
			if remaining_amount <= 0: break
			if existing_item.definition_id == item_id and existing_item.stack_size < definition.max_stack_size:
				var space = definition.max_stack_size - existing_item.stack_size
				var to_move = min(remaining_amount, space)
				existing_item.stack_size += to_move
				remaining_amount -= to_move

	# Phase 2: Adding new stacks
	while remaining_amount > 0:
		var stack_size = min(remaining_amount, definition.max_stack_size)
		var new_item = QWItem.new(definition, stack_size)
		
		var spot = _inv_controller.find_first_free_spot_for_size(_player_inventory_data, new_item.get_display_size())
		if spot != Vector2i(-1, -1):
			_player_inventory_data.add_item(new_item)
			_player_inventory_data.item_positions[new_item.get_instance_id()] = spot
		else:
			logger.warn("Inventory", "give_item: No space for '%s'. %d item(s) were lost." % [item_id, remaining_amount])
			break
		remaining_amount -= stack_size
	
	var count_after = count_item(item_id)
	logger.log("Inventory", "    -> [Adapter.give_item] Item '%s': Count before: %d, Count after: %d" % [item_id, count_before, count_after])

# Takes a specified amount of an item from the player.
func take_item(item_id: String, amount: int) -> bool:
	if not _is_initialized_successfully: return false

	var logger = QuestWeaverServices.logger
	
	if not check_item(item_id, amount):
		logger.log("Inventory", "    -> [Adapter.take_item] Pre-check failed for '%s'. Player has %d, needs %d." % [item_id, count_item(item_id), amount])
		return false

	var count_before = count_item(item_id)
	var amount_to_remove = amount
	
	# Iterate backwards to safely remove items from the array.
	for i in range(_player_inventory_data.items.size() - 1, -1, -1):
		var item = _player_inventory_data.items[i]
		if item.definition_id == item_id:
			var to_take = min(amount_to_remove, item.stack_size)
			item.stack_size -= to_take
			amount_to_remove -= to_take
			
			if item.stack_size <= 0:
				_player_inventory_data.remove_item(item)
			
			if amount_to_remove <= 0:
				break
	
	var count_after = count_item(item_id)
	logger.log("Inventory", "    -> [Adapter.take_item] Item '%s': Count before: %d, Count after: %d" % [item_id, count_before, count_after])
	return true
