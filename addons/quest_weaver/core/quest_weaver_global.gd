# res://addons/quest_weaver/core/quest_weaver_global.gd
extends Node

## Global Event Bus for Quest Weaver.
## Decouples the game logic from the quest system.

signal quest_event_fired(event_name: String, payload: Dictionary)
signal interacted_with_object(node: Node)
signal enemy_was_killed(enemy_id: String)
signal entered_location(location_id: String)
