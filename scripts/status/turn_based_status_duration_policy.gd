extends StatusDurationPolicy
class_name TurnBasedStatusDurationPolicy

## 回合制状态持续时间策略

@export_enum("turn_started", "turn_ended")
var duration_type : String = "turn_started"

func _handle_event(instance: GameplayStatusInstance, event_id : StringName, _event_context: Dictionary) -> bool:
	if event_id == duration_type:
		var remaining : float = _get_remaining_duration(instance)
		if remaining > 0:
			remaining -= 1
			_set_remaining_duration(instance, remaining)
			if remaining <= 0:
				return true
	return false
