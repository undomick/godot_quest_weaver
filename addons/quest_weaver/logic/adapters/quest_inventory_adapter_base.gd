# res://addons/quest_weaver/logic/quest_inventory_adapter_base.gd
@tool
class_name QuestInventoryAdapterBase
extends RefCounted

## ABSTRACT BASE CLASS (CONTRACT)
##
## Defines the interface that an inventory system must implement
## so the quest system can interact with it. Every function must be
## overridden in a concrete adapter class.

signal inventory_updated

## Returns the TOTAL amount of a specific item in the player's inventory.
func count_item(item_id: String) -> int:
	push_warning("The count_item function has not been implemented in the concrete inventory adapter.")
	return 0

## Checks if the player has AT LEAST a specific amount of an item.
## The default implementation uses count_item, but can be optimized if needed.
func check_item(item_id: String, amount: int) -> bool:
	return count_item(item_id) >= amount

## Gives the player a specific amount of an item.
func give_item(item_id: String, amount: int) -> void:
	push_warning("The give_item function has not been implemented in the concrete inventory adapter.")

## Takes a specific amount of an item away from the player.
## Should return 'true' if the action was successful, otherwise 'false'.
func take_item(item_id: String, amount: int) -> bool:
	push_warning("The take_item function has not been implemented in the concrete inventory adapter.")
	return false

## Is called by the QuestController when the adapter is initialized.
func initialize() -> void:
	pass
