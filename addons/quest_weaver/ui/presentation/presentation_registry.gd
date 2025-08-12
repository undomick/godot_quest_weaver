# res://addons/quest_weaver/data/presentation_registry.gd
@tool
class_name PresentationRegistry
extends Resource

## Eine zentrale Registry, die Anwendungsfälle (wie "AreaName")
## auf konkrete UI-Panel-Templates abbildet.

@export var entries: Dictionary = {
	"Default": UIPanelTemplateResource,
	"AreaName": UIPanelTemplateResource,
	"Instruction": UIPanelTemplateResource,
	"BottomCentered": UIPanelTemplateResource
}
