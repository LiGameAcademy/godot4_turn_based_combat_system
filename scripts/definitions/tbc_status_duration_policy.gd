extends StatusDurationPolicy
class_name TBC_StatusDurationPolicy

## 回合制持续时间策略

## 更新持续时间的阶段
@export var update_phase: StringName = "turn_ended"

func _handle_event(instance: GameplayStatusInstance, event_id : StringName, _event_context: Dictionary) -> bool:
	if event_id == update_phase:
		return _on_update_phase(instance)
	return false

## 当进入事件处理阶段
## [param] instance: GameplayStatusInstance 状态实例
## [return] bool 是否应该移除状态
func _on_update_phase(instance: GameplayStatusInstance) -> bool:
	var remaining = _get_remaining_duration(instance)
	if remaining > 0:
		remaining -= 1
		_set_remaining_duration(instance, remaining)
		return remaining <= 0.0
	return false
