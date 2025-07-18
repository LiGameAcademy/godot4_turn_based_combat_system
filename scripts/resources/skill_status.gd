extends Resource
class_name SkillStatus

## 技能状态运行时实例

var status_data: SkillStatusData = null				## 状态数据
var source_character: Character   					## 施加此状态的角色
var target_character: Character   					## 拥有此状态的角色 (方便状态效果内部逻辑访问目标)
var remaining_duration: int:       					## 剩余持续时间
	set(value):
		remaining_duration = value
		duration_changed.emit(value)
var stacks: int = 1:          						## 当前叠加层数
	set(value):
		stacks = value
		stacks_changed.emit(value)
var is_permanent: bool :							## 是否永久
	get :
		return status_data.is_permanent
	set(_value):
		push_error("is_permanent is read-only")

var current_turn_trigger_count: int = 0				## 本回合触发次数
var current_total_trigger_count: int = 0			## 触发总数

signal stacks_changed(new_stacks: int)				## 叠加层数变化
signal duration_changed(new_duration: int)			## 持续时间变化	
signal status_updated(old_stacks: int, old_duration: int)			## 状态更新

## 获取状态的完整描述
func get_full_description() -> String:
	return status_data.get_full_description()

## 检查此状态是否可以被抵抗
func is_countered_by(other_status_id: StringName) -> bool:
	return status_data.is_countered_by(other_status_id)

## 检查此状态是否可以覆盖其他状态
func overrides_other_status(other_status_id: StringName) -> bool:
	return status_data.overrides_other_status(other_status_id)

## 检查此状态是否可以被指定事件触发
func can_trigger_on_event(event_type: StringName) -> bool:
	if current_turn_trigger_count >= status_data.trigger_turns or current_total_trigger_count >= status_data.trigger_count:
		return false
	return status_data.can_trigger_on_event(event_type)

func is_resisted_by(other_status_id: StringName) -> bool:
	return status_data.is_resisted_by(other_status_id)

## 更新已存在的状态
## 处理状态的各种叠加行为，如刷新持续时间、增加层数等
## [param status_template] 状态模板
## [param p_source_char] 状态来源角色
## [param result_info] 结果信息字典
## [return] 更新后的状态实例
func update_status(status_data: SkillStatusData, p_source_char: Character, result_info: Dictionary) -> Dictionary:
	var result : Dictionary = result_info.duplicate(true)
	source_character = p_source_char
	var old_stacks: int = stacks
	var old_duration: int = remaining_duration
	
	var new_duration_base = status_data.duration
	var new_stack_count = status_data.stacks

	# 根据不同的堆叠行为处理状态
	match status_data.stack_behavior:
		SkillStatusData.StackBehavior.NO_STACK:
			remaining_duration = new_duration_base
			result_info.reason = "no_stack_refreshed"
		SkillStatusData.StackBehavior.REFRESH_DURATION:
			remaining_duration = new_duration_base
			result_info.reason = "duration_refreshed"
		SkillStatusData.StackBehavior.ADD_DURATION:
			remaining_duration += new_duration_base
			result_info.reason = "duration_added"
		SkillStatusData.StackBehavior.ADD_STACKS_REFRESH_DURATION:
			new_stack_count = min(old_stacks + status_data.stacks, status_data.max_stacks)
			remaining_duration = new_duration_base
			result_info.reason = "stacked_duration_refreshed"
		SkillStatusData.StackBehavior.ADD_STACKS_INDEPENDENT_DURATION:
			new_stack_count = min(old_stacks + status_data.stacks, status_data.max_stacks)
			remaining_duration = max(remaining_duration, new_duration_base)
			result_info.reason = "stacked_independent_simplified"
	
	# 如果层数变化，需要重新应用属性修改器
	if stacks != new_stack_count:
		on_remove()
		stacks = new_stack_count
		on_apply()
	
	result_info.applied_successfully = true
	
	# 如果状态有变化，发出信号
	if old_stacks != stacks or old_duration != remaining_duration:
		status_updated.emit(old_stacks, old_duration)
	return result

func on_apply() -> void:
	status_data.on_apply()

func on_remove() -> void:
	status_data.on_remove()

func on_tick() -> void:
	status_data.on_tick()
