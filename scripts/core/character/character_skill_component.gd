extends Node
class_name CharacterSkillComponent

## 运行时角色实际持有的AttributeSet实例 (通过模板duplicate而来)
var _active_attribute_set: SkillAttributeSet = null		
## 状态字典, Key: status_id (StringName), Value: SkillStatusData (运行时实例)
var _active_statuses: Dictionary = {}
## 可用的技能
var _skills: Array[SkillData] = []
## 角色标签系统，用于控制角色可执行的动作类型
var _restricted_action_tags : Array[String] = []

## 信号
signal status_applied(status_instance: SkillStatusData)																	## 当状态效果被应用到角色身上时发出
signal status_removed(status_id: StringName, status_instance_data_before_removal: SkillStatusData)						## 当状态效果从角色身上移除时发出
signal status_updated(status_instance: SkillStatusData, old_stacks: int, old_duration: int)								## 当状态效果更新时发出 (例如 stacks 或 duration 变化)
signal attribute_base_value_changed(attribute_instance: SkillAttribute, old_value: float, new_value: float)				## 属性基础值改变
signal attribute_current_value_changed(attribute_instance: SkillAttribute, old_value: float, new_value: float)			## 属性当前值改变
signal action_tags_changed(restricted_tags: Array[String])																## 角色限制动作标签改变																	## 当角色被限制执行某个动作类型时发出

## 初始化组件
func initialize(attribute_set_resource: SkillAttributeSet, skills: Array[SkillData]) -> void:
	# 这是因为AttributeSet本身是一个Resource, 直接使用会导致所有实例共享数据
	_active_attribute_set = attribute_set_resource.duplicate(true)
	# 初始化技能列表
	_skills = skills
	if not _active_attribute_set:
		push_error("无法初始化AttributeSet，资源无效！")
		return
	if not _skills.is_empty() and not _skills:
		push_error("无法初始化技能列表，技能数据无效！")
		return

	# 初始化AttributeSet，这将创建并配置所有属性实例
	_active_attribute_set.initialize_set()
	
	_active_attribute_set.current_value_changed.connect(
		func(attribute_instance: SkillAttribute, old_value: float, new_value: float) -> void:
			attribute_current_value_changed.emit(attribute_instance, old_value, new_value)
	)
	_active_attribute_set.base_value_changed.connect(
		func(attribute_instance: SkillAttribute, old_value: float, new_value: float) -> void:
			attribute_base_value_changed.emit(attribute_instance, old_value, new_value)
	)

#region --- 属性管理 ---
## 获取属性基础值
func get_attribute_base_value(attribute_name: StringName) -> float:
	return _active_attribute_set.get_base_value(attribute_name)

## 获取属性当前值
func get_attribute_current_value(attribute_name: StringName) -> float:
	return _active_attribute_set.get_current_value(attribute_name)

## 设置属性基础值
func set_attribute_base_value(attribute_name: StringName, value: float) -> void:
	_active_attribute_set.set_base_value(attribute_name, value)

## 添加属性修改器
func add_attribute_modifier(attribute_name: StringName, modifier: SkillAttributeModifier) -> void:
	_active_attribute_set.add_attribute_modifier(attribute_name, modifier)

## 移除属性修改器
func remove_attribute_modifier(attribute_name: StringName, modifier: SkillAttributeModifier) -> void:
	_active_attribute_set.remove_attribute_modifier(attribute_name, modifier)

## 获取属性修改器
func get_attribute_modifiers(attribute_name: StringName) -> Array[SkillAttributeModifier]:
	return _active_attribute_set.get_attribute_modifiers(attribute_name)

## 获取属性实例
func get_attribute(attribute_name: StringName) -> SkillAttribute:
	return _active_attribute_set.get_attribute(attribute_name)

## 获取AttributeSet
func get_attribute_set() -> SkillAttributeSet:
	return _active_attribute_set

## 使用MP
func use_mp(amount: float) -> bool:
	var current_mp = _active_attribute_set.get_current_value(&"CurrentMana")
	if current_mp < amount:
		return false
	_active_attribute_set.modify_base_value(&"CurrentMana", -amount)
	return true

## 恢复MP
func restore_mp(amount: float) -> float:
	_active_attribute_set.modify_base_value(&"CurrentMana", amount)
	return amount

## 消耗生命值
func consume_hp(amount: float) -> bool:
	_active_attribute_set.modify_base_value(&"CurrentHealth", -amount)
	return true

## 恢复生命值
func restore_hp(amount: float) -> float:
	_active_attribute_set.modify_base_value(&"CurrentHealth", amount)
	return amount
#endregion

#region --- 技能管理 ---

## 是否有足够的MP释放技能
func has_enough_mp_for_any_skill() -> bool:
	var current_mp = _active_attribute_set.get_current_value(&"CurrentMana")
	for skill in _skills:
		if current_mp >= skill.mp_cost:
			return true
	return false

## 检查是否有足够的MP使用指定技能
func has_enough_mp_for_skill(skill: SkillData) -> bool:
	var current_mp = _active_attribute_set.get_current_value(&"CurrentMana")
	return current_mp >= skill.mp_cost

## 获取所有技能
## [return] 技能数据数组
func get_skills() -> Array[SkillData]:
	return _skills

## 添加技能
func add_skill(skill: SkillData) -> void:
	_skills.append(skill)

## 移除技能
func remove_skill(skill: SkillData) -> void:
	_skills.erase(skill)

## 获取技能
## [param skill_id] 技能ID
## [return] 技能数据
func get_skill(skill_id: StringName) -> SkillData:
	for skill in _skills:
		if skill.skill_id == skill_id:
			return skill
	return null

## 检查是否有指定技能
## [param skill_id] 技能ID
## [return] 是否有指定技能
func has_skill(skill_id: StringName) -> bool:
	return get_skill(skill_id) != null

## 获取技能数量
## [return] 技能数量
func get_skill_count() -> int:
	return _skills.size()

## 获取可用技能列表
## [return] 可用技能列表
func get_available_skills() -> Array:
	var available_skills : Array = []
	for skill in _skills:
		if has_enough_mp_for_skill(skill):
			available_skills.append(skill)
	return available_skills
#endregion

#region --- 状态管理 ---
## 获取所有活跃状态
func get_active_statuses() -> Dictionary:
	return _active_statuses

## 添加状态效果到角色身上
## [param status_template] 状态模板
## [param p_source_char] 状态来源角色
## [param effect_data_from_skill] 是那个类型为STATUS的SkillEffectData，用于获取duration_override等
## [return] 应用状态的结果
func apply_status(status_template: SkillStatusData, p_source_char: Character, effect_data_from_skill: SkillEffectData) -> Dictionary:
	var result = {"applied_successfully": false, "status_instance": null, "reason": "unknown"}
	
	if not status_template:
		result.reason = "invalid_status_template"
		return result
	
	var status_id = status_template.status_id
	var duration_override = -1 # 默认使用状态模板中的持续时间
	var stacks_to_apply = 1 # 默认添加一层
	
	# 如果提供了effect_data，则使用其中的参数
	if effect_data_from_skill:
		if effect_data_from_skill.status_duration_override > 0:
			duration_override = effect_data_from_skill.status_duration_override
		stacks_to_apply = effect_data_from_skill.status_stacks_to_apply
	
	# 检查是否已经存在相同的状态
	if _active_statuses.has(status_id):
		# 更新已存在的状态
		var updated_status = _update_existing_status(status_template, p_source_char, duration_override, stacks_to_apply, result)
		if updated_status:
			result.status_instance = updated_status
			result.applied_successfully = true
			result.reason = "updated"
			return result
	
	# 处理状态覆盖机制
	_handle_status_override(status_template)
	
	# 检查是否被其他状态抗性
	if _check_status_resistance(status_template, result):
		return result
	
	# 创建新状态
	var runtime_status_instance = _apply_new_status(status_template, p_source_char, duration_override, stacks_to_apply, result)
	
	# 应用状态的动作限制标签
	if not runtime_status_instance.restricted_action_categories.is_empty():
		_add_action_restrictions(runtime_status_instance.restricted_action_categories)
	
	result.status_instance = runtime_status_instance
	result.applied_successfully = true
	result.reason = "applied"
	
	return result

## 移除状态效果
func remove_status(status_id: StringName, trigger_end_effects: bool = true) -> bool:
	if not _active_statuses.has(status_id):
		return false
	
	var runtime_status_instance = _active_statuses[status_id]
	
	# 移除属性修饰符
	_apply_attribute_modifiers_for_status(runtime_status_instance, false)
	
	# 移除状态的动作限制
	if not runtime_status_instance.restricted_action_categories.is_empty():
		_remove_action_restrictions(runtime_status_instance.restricted_action_categories)
	
	# 如果需要触发结束效果
	if trigger_end_effects and not runtime_status_instance.end_effects.is_empty():
		print_rich("[color=purple]触发 %s 的状态 %s 的结束效果[/color]" % [owner.character_name, runtime_status_instance.status_name])
		var result = await SkillSystem.process_status_end_effects(runtime_status_instance, owner)
		if not result.success:
			push_warning("Failed to process end effects for status %s: %s" % [runtime_status_instance.status_name, result.get("error", "unknown error")])
	
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
func get_status(status_id: StringName) -> SkillStatusData:
	return _active_statuses.get(status_id)

## 检查是否有指定状态
func has_status(status_id: StringName) -> bool:
	return _active_statuses.has(status_id)

## 获取指定状态的层数
func get_status_stacks(status_id: StringName) -> int:
	if not _active_statuses.has(status_id):
		return 0
	return _active_statuses[status_id].stacks

func process_active_statuses(battle_manager : BattleManager) -> void: 
	var status_ids_to_process = _active_statuses.keys().duplicate() 
	for status_id in status_ids_to_process: 
		if not _active_statuses.has(status_id): continue
		var status_instance: SkillStatusData = _active_statuses[status_id]
		if not status_instance.ongoing_effects.is_empty():
			var effect_source = status_instance.source_character if is_instance_valid(status_instance.source_character) else get_parent()
			await SkillSystem.attempt_process_status_effects(status_instance.ongoing_effects, effect_source, get_parent(), SkillExecutionContext.new(battle_manager))
#endregion

## 私有方法：更新状态触发次数
## [param status] 要更新的状态
func update_status_trigger_counts(status: SkillStatusData) -> void:
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
		
		if status.duration_type == SkillStatusData.DurationType.TURNS:
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
func get_triggerable_status(event_type: StringName) -> Array[SkillStatusData]:
	var triggerable_statuses: Array[SkillStatusData] = []
	for status in _active_statuses.values():
		if status.can_trigger_on_event(event_type):
			triggerable_statuses.append(status)

	return triggerable_statuses

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

#region --- 私有方法 ---
## 私有方法：应用或移除属性修饰符
## [param runtime_status_inst] 运行时状态实例
## [param add] 是否添加修饰符
func _apply_attribute_modifiers_for_status(runtime_status_inst: SkillStatusData, add: bool = true) -> void:
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
func _check_status_resistance(_status_template: SkillStatusData, _result_info: Dictionary) -> bool:
	# 遍历所有当前已有的状态，检查是否有状态会抵抗即将应用的状态
	#for status_id in _active_statuses:
		#var active_status = _active_statuses[status_id]
		#if active_status.resists_statuses.has(status_template.status_id):
			#result_info["applied_successfully"] = false
			#result_info["reason"] = "resisted_by_status"
			#result_info["resisted_by"] = active_status.status_id
			#
			#print(owner.character_name + " 的状态 " + active_status.status_name + " 抵抗了 " + status_template.status_name)
			#return true
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

## 更新已存在的状态
## 处理状态的各种叠加行为，如刷新持续时间、增加层数等
## [param status_template] 状态模板
## [param p_source_char] 状态来源角色
## [param duration_override] 持续时间覆盖
## [param stacks_to_apply] 要应用的层数
## [param result_info] 结果信息字典
## [return] 更新后的状态实例
func _update_existing_status(
		status_template: SkillStatusData, p_source_char: Character, 
		duration_override: int, stacks_to_apply: int, result_info: Dictionary) -> SkillStatusData:
	var status_id: StringName = status_template.status_id
	var runtime_status_instance: SkillStatusData = _active_statuses[status_id]
	var old_stacks: int = runtime_status_instance.stacks
	var old_duration: int = runtime_status_instance.remaining_duration
	
	runtime_status_instance.source_character = p_source_char
	var new_duration_base = duration_override if duration_override > -1 else status_template.duration
	var new_stack_count = runtime_status_instance.stacks

	# 根据不同的堆叠行为处理状态
	match status_template.stack_behavior:
		SkillStatusData.StackBehavior.NO_STACK:
			runtime_status_instance.remaining_duration = new_duration_base
			result_info.reason = "no_stack_refreshed"
		SkillStatusData.StackBehavior.REFRESH_DURATION:
			runtime_status_instance.remaining_duration = new_duration_base
			result_info.reason = "duration_refreshed"
		SkillStatusData.StackBehavior.ADD_DURATION:
			runtime_status_instance.remaining_duration += new_duration_base
			result_info.reason = "duration_added"
		SkillStatusData.StackBehavior.ADD_STACKS_REFRESH_DURATION:
			new_stack_count = min(old_stacks + stacks_to_apply, status_template.max_stacks)
			runtime_status_instance.remaining_duration = new_duration_base
			result_info.reason = "stacked_duration_refreshed"
		SkillStatusData.StackBehavior.ADD_STACKS_INDEPENDENT_DURATION:
			new_stack_count = min(old_stacks + stacks_to_apply, status_template.max_stacks)
			runtime_status_instance.remaining_duration = max(runtime_status_instance.remaining_duration, new_duration_base)
			result_info.reason = "stacked_independent_simplified"
	
	# 如果层数变化，需要重新应用属性修改器
	if runtime_status_instance.stacks != new_stack_count:
		_apply_attribute_modifiers_for_status(runtime_status_instance, false) # 先移除旧修改器
		runtime_status_instance.stacks = new_stack_count
		_apply_attribute_modifiers_for_status(runtime_status_instance) # 再应用新修改器
	
	result_info.applied_successfully = true
	
	# 如果状态有变化，发出信号
	if old_stacks != runtime_status_instance.stacks or old_duration != runtime_status_instance.remaining_duration:
		status_updated.emit(runtime_status_instance, old_stacks, old_duration)
	
	return runtime_status_instance

## 私有方法：应用新状态
func _apply_new_status(status_template: SkillStatusData, p_source_char: Character, 
		duration_override: int, stacks_to_apply: int, result_info: Dictionary) -> SkillStatusData:
	# 创建运行时状态实例（克隆模板）
	var runtime_status_instance: SkillStatusData = status_template.duplicate(true)
	
	# 设置源角色引用
	runtime_status_instance.source_character = p_source_char
	
	# 设置堆叠层数
	if runtime_status_instance.max_stacks > 0:
		runtime_status_instance.stacks = mini(stacks_to_apply, runtime_status_instance.max_stacks)
	else:
		runtime_status_instance.stacks = stacks_to_apply
	
	# 设置持续时间
	if duration_override > 0:
		runtime_status_instance.remaining_duration = duration_override
	else:
		runtime_status_instance.remaining_duration = runtime_status_instance.duration
	
	# 将状态添加到活跃状态字典
	_active_statuses[runtime_status_instance.status_id] = runtime_status_instance
	
	# 应用属性修饰符
	_apply_attribute_modifiers_for_status(runtime_status_instance, true)

	# 触发初始效果
	if not runtime_status_instance.initial_effects.is_empty():
		SkillSystem.attempt_process_status_effects(runtime_status_instance.initial_effects, runtime_status_instance.source_character, get_parent(), SkillExecutionContext.new())

	result_info["applied_successfully"] = true
	result_info["reason"] = "new_status_applied"
	
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
#endregion
