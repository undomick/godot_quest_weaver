# res://addons/quest_weaver/core/qw_enums.gd
class_name QWEnums
extends RefCounted

## Central repository for enums used throughout the Quest Weaver plugin
## to avoid dependencies on external game state scripts.

enum QuestState {
	INACTIVE,
	ACTIVE,
	COMPLETED,
	FAILED
}
