# res://addons/quest_weaver/systems/adapters/nexus_inventory_adapter.gd
@tool
class_name NexusInventoryAdapter
extends QuestInventoryAdapterBase

var _inv_controller = null
var _item_registry = null
var _player_inventory_data = null
var _is_initialized_successfully := false

# This adapter serves as a bridge to the "Nexus Inventory" system.
# It ensures Quest Weaver can interact with items without hard dependencies.

func initialize() -> void:
	# We access the SceneTree dynamically to avoid static dependency issues during plugin loading.
	var main_loop = Engine.get_main_loop()
	if not main_loop is SceneTree:
		return
		
	var root = main_loop.root
	
	# Check if the required external Autoloads exist
	if not root.has_node("NexusServices") or not root.has_node("GameManager"):
		push_error("QuestWeaver (NexusInventoryAdapter): 'NexusServices' or 'GameManager' autoloads not found. Adapter disabled.")
		return
		
	# Retrieve the nodes dynamically using string paths
	var nexus_services = root.get_node("NexusServices")
	var game_manager = root.get_node("GameManager")
	
	_inv_controller = nexus_services.inventory_controller
	_item_registry = game_manager.item_registry
	_player_inventory_data = game_manager.player_inventory_data

	# Validate components
	if not is_instance_valid(_inv_controller) or not is_instance_valid(_item_registry) or not is_instance_valid(_player_inventory_data):
		push_error("QuestWeaver (NexusInventoryAdapter): One of the required components is invalid. Adapter disabled.")
		return

	# Connect signals
	if not _player_inventory_data.is_connected("updated", Callable(self, "_on_inventory_updated")):
		_player_inventory_data.updated.connect(_on_inventory_updated)
	
	_is_initialized_successfully = true
	
	_log_safe("Inventory", "NexusInventoryAdapter initialized successfully.")

# --- Internal Helpers ---

# Helper to access the logger without causing static compilation errors on cold start
func _log_safe(category: String, message: String) -> void:
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.root:
		var services = main_loop.root.get_node_or_null("QuestWeaverServices")
		if is_instance_valid(services) and services.logger:
			services.logger.log(category, message)

func _warn_safe(category: String, message: String) -> void:
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop.root:
		var services = main_loop.root.get_node_or_null("QuestWeaverServices")
		if is_instance_valid(services) and services.logger:
			services.logger.warn(category, message)
	else:
		push_warning("[%s] %s" % [category, message])

# --- Event Handlers ---

func _on_inventory_updated():
	inventory_updated.emit()

# --- API Implementation ---

func count_item(item_id: String) -> int:
	if not _is_initialized_successfully: return 0
	
	var count = 0
	for item in _player_inventory_data.items:
		if is_instance_valid(item) and item.definition_id == item_id:
			count += item.stack_size
	return count

func give_item(item_id: String, amount: int) -> void:
	if not _is_initialized_successfully: return
	
	var definition = _item_registry.find(item_id)
	if not is_instance_valid(definition):
		_warn_safe("Inventory", "give_item: Could not find ItemDefinition '%s'." % item_id)
		return
	
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
		
		# Assuming QWItem is a class available in the project scope
		var new_item = QWItem.new(definition, stack_size)
		
		var spot = _inv_controller.find_first_free_spot_for_size(_player_inventory_data, new_item.get_display_size())
		if spot != Vector2i(-1, -1):
			_player_inventory_data.add_item(new_item)
			_player_inventory_data.item_positions[new_item.get_instance_id()] = spot
		else:
			_warn_safe("Inventory", "give_item: No space for '%s'. %d item(s) were lost." % [item_id, remaining_amount])
			break
		remaining_amount -= stack_size
	
	var count_after = count_item(item_id)
	_log_safe("Inventory", "    -> [Adapter.give_item] Item '%s': Count before: %d, Count after: %d" % [item_id, count_before, count_after])

func take_item(item_id: String, amount: int) -> bool:
	if not _is_initialized_successfully: return false

	if not check_item(item_id, amount):
		_log_safe("Inventory", "    -> [Adapter.take_item] Pre-check failed for '%s'. Player has %d, needs %d." % [item_id, count_item(item_id), amount])
		return false

	var count_before = count_item(item_id)
	var amount_to_remove = amount
	
	# Iterate backwards to safely remove items from the array
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
	_log_safe("Inventory", "    -> [Adapter.take_item] Item '%s': Count before: %d, Count after: %d" % [item_id, count_before, count_after])
	return true
