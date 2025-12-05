# res://addons/quest_weaver/editor/presentation/presentation_registry.gd
@tool
class_name PresentationRegistry
extends Resource

## A central registry that maps specific use cases (e.g., "AreaName")
## to concrete UI panel templates.

@export var entries: Dictionary = {
	"Default": UIPanelTemplateResource,
	"AreaName": UIPanelTemplateResource,
	"Instruction": UIPanelTemplateResource,
	"BottomCentered": UIPanelTemplateResource
}
