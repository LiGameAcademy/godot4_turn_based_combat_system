extends Node

## 插件级别的系统单例

signal game_event_triggered(event_type: StringName, event_source: Node, context: EventContext)

func trigger_game_event(event_type: StringName, event_source: Node, context: EventContext) -> void:
	game_event_triggered.emit(event_type, event_source, context)
