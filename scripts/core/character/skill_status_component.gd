extends Node
class_name SkillStatusComponent

var _active_statuses: Dictionary[StringName, SkillStatus] = {}          ## 状态字典, Key: status_id (StringName), Value: SkillStatus (运行时实例)
var _restricted_action_tags : Array[String] = []                        ## 角色限制动作标签

signal status_applied(status_instance: SkillStatus)																	## 当状态效果被应用到角色身上时发出
signal status_removed(status_id: StringName, status_instance_data_before_removal: SkillStatus)						## 当状态效果从角色身上移除时发出
signal status_updated(status_instance: SkillStatus, old_stacks: int, old_duration: int)								## 当状态效果更新时发出 (例如 stacks 或 duration 变化)
signal action_tags_changed(restricted_tags: Array[String])															## 角色限制动作标签改变																	## 当角色被限制执行某个动作类型时发出

class ApplyStatusResult:
	var applied_successfully : bool = false         ## 是否成功应用状态
	var status_instance : SkillStatus = null        ## 应用成功后返回的运行时状态实例
	var reason : String = "unknown"                 ## 未成功应用状态的原因

	func _init(p_applied_successfully: bool, p_status_instance: SkillStatus, p_reason: String) -> void:
		applied_successfully = p_applied_successfully
		status_instance = p_status_instance
		reason = p_reason

	func to_dict() -> Dictionary:
		return {
			"applied_successfully": applied_successfully,
			"status_instance": status_instance,
			"reason": reason
		}

	static func from_dict(p_dict: Dictionary) -> ApplyStatusResult:
		var result = ApplyStatusResult.new(false, null, "unknown")
		result.applied_successfully = p_dict["applied_successfully"]
		result.status_instance = p_dict["status_instance"]
		result.reason = p_dict["reason"]
		return result

## 获取所有活跃状态
## [return] 活跃状态字典
func get_active_statuses() -> Dictionary:
	return _active_statuses

## 添加状态效果到角色身上
## [param status_template] 状态模板
## [param p_source_char] 状态来源角色
## [param effect_data_from_skill] 是那个类型为STATUS的SkillEffect，用于获取duration_override等
## [return] 应用状态的结果
func apply_status(status_template: SkillStatusData, p_source_char: Character, effect_data_from_skill: ApplyStatusEffect) -> ApplyStatusResult:
	var result = ApplyStatusResult.new(false, null, "unknown")
	
	if not status_template:
		result.reason = "invalid status template!"
		return result
	
	var status_id: StringName = status_template.status_id
	var status_data : SkillStatusData = status_template.duplicate(true)
	# var duration_override = -1 # 默认使用状态模板中的持续时间
	# var stacks_to_apply = 1 # 默认添加一层
	
	# 如果提供了effect_data，则使用其中的参数
	if is_instance_valid(effect_data_from_skill):
		if effect_data_from_skill.status_duration_override > 0:
			status_data.duration = effect_data_from_skill.status_duration_override
		if effect_data_from_skill.status_stacks_to_apply > 0:
			status_data.stacks = effect_data_from_skill.status_stacks_to_apply
	
	# 检查是否已经存在相同的状态
	if _active_statuses.has(status_id):
		var status_instance : SkillStatus = _active_statuses[status_id]
		var result_dict = status_instance.update_status(status_data, p_source_char, result.to_dict())
		return ApplyStatusResult.from_dict(result_dict)
	
	# 处理状态覆盖机制
	_handle_status_override(status_template)
	
	# 检查是否被其他状态抗性
	if _check_status_resistance(status_template, result):
		return result
	
	# 创建新状态
	var runtime_status_instance = _apply_new_status(status_template, p_source_char, result)
	
	# 应用状态的动作限制标签
	if not runtime_status_instance.restricted_action_categories.is_empty():
		_add_action_restrictions(runtime_status_instance.restricted_action_categories)
	
	result.status_instance = runtime_status_instance
	result.applied_successfully = true
	result.reason = "applied"
	
	return result

## 移除状态效果
## [param status_id] 要移除的状态ID
## [param trigger_end_effects] 是否触发结束效果
## [return] 是否成功移除状态
func remove_status(status_id: StringName, trigger_end_effects: bool = true) -> bool:
	if not _active_statuses.has(status_id):
		return false
	
	var runtime_status_instance = _active_statuses[status_id]
	
	# 如果需要触发结束效果
	if trigger_end_effects:
		runtime_status_instance.on_remove()
	
	# 移除状态
	_active_statuses.erase(status_id)
	
	# 发出状态移除信号
	status_removed.emit(status_id, runtime_status_instance)
	
	print_rich("[color=red]%s 的状态 %s 被移除[/color]" % [owner.character_name, runtime_status_instance.status_name])
	
	return true

## 更新状态持续时间（通常在回合结束时调用）
func update_status_durations() -> void:
	var expired_status_ids: Array[StringName] = []
	
	# 更新所有状态的持续时间
	for status_id in _active_statuses:
		var status = _active_statuses[status_id]
		
		# 如果状态是永久的，跳过
		if status.is_permanent:
			continue
		
		# 减少持续时间
		status.remaining_duration -= 1
		
		# 检查是否过期
		if status.remaining_duration <= 0:
			expired_status_ids.append(status_id)
		else:
			print("%s 的状态 %s 剩余持续时间: %d" % [owner.to_string(), status.status_name, status.remaining_duration])
	
	# 移除过期的状态
	for status_id in expired_status_ids:
		print("%s 的状态 %s 已过期" % [owner.to_string(), _active_statuses[status_id].status_name])
		remove_status(status_id)

## 获取状态实例
func get_status(status_id: StringName) -> SkillStatus:
	return _active_statuses.get(status_id)

## 检查是否有指定状态
func has_status(status_id: StringName) -> bool:
	return _active_statuses.has(status_id)

## 获取指定状态的层数
func get_status_stacks(status_id: StringName) -> int:
	if not _active_statuses.has(status_id):
		return 0
	return _active_statuses[status_id].stacks

## 处理
func process_active_statuses(battle_manager : BattleManager) -> void: 
	var status_ids_to_process = _active_statuses.keys().duplicate() 
	for status_id in status_ids_to_process: 
		if not _active_statuses.has(status_id): continue
		var status_instance: SkillStatus = _active_statuses[status_id]
        status_instance.on_tick()
#endregion

## 私有方法：更新状态触发次数
## [param status] 要更新的状态
func update_status_trigger_counts(status: SkillStatus) -> void:
	status.current_turn_trigger_count += 1
	status.current_total_trigger_count += 1
	
	# 检查是否达到最大触发次数
	if status.trigger_count > 0 and status.current_total_trigger_count >= status.trigger_count:
		print_rich("[color=orange]状态 %s 已达到最大触发次数 %d，将被移除[/color]" % [status.status_name, status.trigger_count])
		# 使用延迟调用移除状态，避免在遍历过程中修改集合
		call_deferred("remove_status", status.status_id)

## 重置状态触发计数
func reset_status_trigger_counts() -> void:
	# 重置所有状态的回合触发计数
	for status_id in _active_statuses.keys():
		var status = _active_statuses[status_id]
		status.current_turn_trigger_count = 0

## 处理回合开始时的状态更新
func process_turn_start() -> void:
	# 更新所有状态的持续时间
	var expired_status_ids: Array[StringName] = []
	
	for status_id in _active_statuses.keys():
		var status = _active_statuses[status_id]
		
		if status.duration_type == SkillStatus.DurationType.TURNS:
			status.remaining_duration -= 1
			if status.remaining_duration <= 0:
				expired_status_ids.append(status_id)
			else:
				# 触发回合开始事件
				SkillSystem.trigger_game_event(get_parent(), &"on_turn_start", EventContext.new(get_parent()))
	
	# 移除过期状态
	for status_id in expired_status_ids:
		remove_status(status_id)

## 获取触发状态
func get_triggerable_status(event_type: StringName) -> Array[SkillStatus]:
	var triggerable_statuses: Array[SkillStatus] = []
	for status in _active_statuses.values():
		if status.can_trigger_on_event(event_type):
			triggerable_statuses.append(status)

	return triggerable_statuses

## 私有方法：应用或移除属性修饰符
## [param runtime_status_inst] 运行时状态实例
## [param add] 是否添加修饰符
func _apply_attribute_modifiers_for_status(runtime_status_inst: SkillStatus, add: bool = true) -> void:
	if not _active_attribute_set or not is_instance_valid(runtime_status_inst): 
		push_error("_apply_attribute_modifiers_for_status: _active_attribute_set or runtime_status_inst is invalid")
		return
	if runtime_status_inst.attribute_modifiers.is_empty(): return
	
	for modifier_template: SkillAttributeModifier in runtime_status_inst.attribute_modifiers:
		# 创建运行时修饰符实例
		var runtime_modifier : SkillAttributeModifier = modifier_template.duplicate()
		
		# 设置源和层数
		runtime_modifier.set_source(runtime_status_inst.get_instance_id())
		
		# 如果修饰符受层数影响，调整数值
		if runtime_status_inst.stacks > 0:
			runtime_modifier.magnitude *= runtime_status_inst.stacks
		
		# 应用或移除修饰符
		if add:
			_active_attribute_set.apply_modifier(runtime_modifier)
		else:
			_active_attribute_set.remove_modifiers_by_source_id(runtime_status_inst.get_instance_id())

## 私有方法：检查状态抵抗
func _check_status_resistance(status_template: SkillStatusData, result_info: ApplyStatusResult) -> bool:
	# 遍历所有当前已有的状态，检查是否有状态会抵抗即将应用的状态
	for status_id in _active_statuses:
		var active_status = _active_statuses[status_id]
		if active_status.is_resisted_by(status_template.status_id):
			result_info.applied_successfully = false
			result_info.reason = "resisted_by_status"
			result_info.resisted_by = active_status.status_id
			
			print(owner.character_name + " 的状态 " + active_status.status_name + " 抵抗了 " + status_template.status_name)
			return true
	return false

## 私有方法：处理状态覆盖
func _handle_status_override(status_template: SkillStatusData) -> void:
	if not status_template.overrides_states.is_empty():
		var ids_to_remove_due_to_override: Array[StringName] = []
		
		# 检查此状态会覆盖哪些已有状态
		for status_id in _active_statuses:
			if status_template.overrides_states.has(status_id):
				ids_to_remove_due_to_override.append(status_id)
		
		# 移除被覆盖的状态
		for status_id in ids_to_remove_due_to_override:
			var status_to_remove = _active_statuses[status_id]
			print(status_template.status_name + " 覆盖了状态 " + status_to_remove.status_name)
			remove_status(status_id)

## 私有方法：应用新状态
func _apply_new_status(status_data: SkillStatusData, p_source_char: Character, result_info: ApplyStatusResult) -> SkillStatus:
	# 创建运行时状态实例（克隆模板）
	var runtime_status_instance: SkillStatus = SkillStatus.new()
	runtime_status_instance.status_data = status_data
	# 设置源角色引用
	runtime_status_instance.source_character = p_source_char
	
	# 将状态添加到活跃状态字典
	_active_statuses[runtime_status_instance.status_id] = runtime_status_instance
	
	runtime_status_instance.on_apply()

	result_info.applied_successfully = true
	result_info.reason = "new_status_applied"
	
	print("%s 获得状态: %s (%d层，持续%d回合)" % [
		owner.to_string(),
		runtime_status_instance.status_name,
		runtime_status_instance.stacks,
		runtime_status_instance.remaining_duration
	])
	
	# 发出状态应用信号
	status_applied.emit(runtime_status_instance)
	
	return runtime_status_instance

## 私有方法：添加动作限制
## [param categories] 动作限制类别
func _add_action_restrictions(categories: Array[String]) -> void:
	var changed = false
	for category in categories:
		if not _restricted_action_tags.has(category):
			_restricted_action_tags.append(category)
			changed = true
	
	# 发出动作限制改变信号
	if changed:
		print_rich("[color=orange]%s 添加动作限制标签: %s[/color]" % [get_parent().character_name, categories])
		action_tags_changed.emit(_restricted_action_tags)

## 私有方法：移除动作限制
## [param categories] 动作限制类别
func _remove_action_restrictions(categories: Array[String]) -> void:
	var changed = false
	for category in categories:
		if _restricted_action_tags.has(category):
			_restricted_action_tags.erase(category)
			changed = true
	
	# 发出动作限制改变信号
	if changed:
		print_rich("[color=green]%s 移除动作限制标签: %s[/color]" % [get_parent().character_name, categories])
		action_tags_changed.emit(_restricted_action_tags)

#region --- 标签管理 ---

## 获取当前的动作限制标签
func get_restricted_action_tags() -> Array[String]:
	return _restricted_action_tags

## 检查是否可以执行特定类别的动作
func can_perform_action_category(category: StringName) -> bool:
	return not _restricted_action_tags.has(category) and not _restricted_action_tags.has(&"any_action")

## 检查技能是否可用（基于动作限制）
func is_skill_available(skill: SkillData) -> bool:
	# 检查是否有任何动作限制标签与技能的动作类别冲突
	for category in skill.action_categories:
		if _restricted_action_tags.has(StringName(category)):
			return false
	
	# 检查是否有通用限制
	if _restricted_action_tags.has(&"any_action") or _restricted_action_tags.has(&"any_skill"):
		return false
	
	return true
#endregion
