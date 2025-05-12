extends Node
class_name CombatComponent

# 信号
signal skill_executed(skill, source, targets, results)
signal status_applied(status, target, source)
signal status_removed(status, target)
signal status_updated(status, target, old_stacks, new_stacks)

# 引用
var character: Character :
	get:
		return owner

# 状态管理
var active_statuses = {} # Dictionary<String, Dictionary> - 键为状态ID，值为状态信息
var status_sources = {} # Dictionary<String, Character> - 键为状态ID，值为状态来源

# 控制效果管理
var control_effects = {} # 字典，键为控制类型，值为持续回合数

## 执行技能
func execute_skill(skill_data: SkillData, targets: Array) -> Array:
	if !can_execute_skill(skill_data):
		return []
	
	# 消耗MP
	character.use_mp(skill_data.mp_cost)
	
	var results = []
	
	# 处理直接效果
	for effect in skill_data.direct_effects:
		for target in targets:
			var result = effect.apply(character, target)
			results.append(result)
	
	# 处理状态效果
	for i in range(skill_data.statuses.size()):
		var status = skill_data.statuses[i]
		var chance = skill_data.status_chances[i] if i < skill_data.status_chances.size() else 1.0
		
		# 随机判断是否应用状态
		if randf() <= chance:
			for target in targets:
				add_status(status, character)
	
	# 发出信号
	skill_executed.emit(skill_data, character, targets, results)
	
	return results

## 检查是否可以执行技能
func can_execute_skill(skill_data: SkillData) -> bool:
	# 检查MP是否足够
	if character.current_mp < skill_data.mp_cost:
		return false
	
	# 检查是否被控制
	if !can_act():
		return false
	
	return true

## 添加状态
func add_status(status: SkillStatusData, source: Character = null) -> SkillStatusData:
	var status_id = status.effect_id
	
	# 检查是否已有此状态
	if active_statuses.has(status_id):
		var existing_info = active_statuses[status_id]
		var existing_status = existing_info["status"]
		
		# 判断是否可叠加
		if existing_status.can_stack:
			# 根据叠加行为处理
			var old_stacks = existing_info["stacks"]
			var new_stacks = old_stacks
			
			match existing_status.stack_behavior:
				"replace":
					# 重置持续时间
					existing_info["duration"] = status.duration
				"extend_duration":
					# 延长持续时间
					existing_info["duration"] += status.duration
				"increase_intensity":
					# 增加叠加层数
					new_stacks = min(old_stacks + 1, existing_status.max_stacks)
					existing_info["stacks"] = new_stacks
			
			# 发送更新信号
			status_updated.emit(existing_status, character, old_stacks, new_stacks)
			
			return existing_status
		else:
			# 不可叠加，替换为新状态
			remove_status(status_id)
	
	# 添加新状态
	active_statuses[status_id] = {
		"status": status,
		"duration": status.duration,
		"stacks": 1
	}
	
	# 记录状态来源
	if source:
		status_sources[status_id] = source
	
	# 执行初始效果
	for effect in status.initial_effects:
		effect.apply(source, character)
	
	# 发送添加信号
	status_applied.emit(status, character, source)
	
	return status

## 移除状态
func remove_status(status_id: String) -> void:
	if active_statuses.has(status_id):
		var status_info = active_statuses[status_id]
		var status = status_info["status"]
		var source = status_sources.get(status_id)
		
		# 执行结束效果
		for effect in status.end_effects:
			effect.apply(source, character)
		
		# 移除状态
		active_statuses.erase(status_id)
		
		# 移除状态来源
		if status_sources.has(status_id):
			status_sources.erase(status_id)
		
		# 发送移除信号
		status_removed.emit(status, character)

## 获取状态
func get_status_by_id(status_id: String) -> SkillStatusData:
	if active_statuses.has(status_id):
		return active_statuses[status_id]["status"]
	return null

## 获取状态来源
func get_status_source(status_id: String) -> Character:
	if status_sources.has(status_id):
		return status_sources[status_id]
	return null

## 获取所有状态
func get_all_statuses() -> Array:
	var statuses = []
	for status_id in active_statuses:
		statuses.append(active_statuses[status_id]["status"])
	return statuses

## 获取所有状态及其来源
func get_all_statuses_with_sources() -> Array:
	var result = []
	for status_id in active_statuses:
		var status_info = active_statuses[status_id]
		var source = status_sources.get(status_id, null)
		
		result.append({
			"status": status_info["status"],
			"source": source,
			"duration": status_info["duration"],
			"stacks": status_info["stacks"]
		})
	
	return result

## 计算属性修改值 (用于Buff/Debuff)
func calculate_stat_modification(status_id: String, base_value: float) -> float:
	if !active_statuses.has(status_id):
		return 0.0
		
	var status_info = active_statuses[status_id]
	var status = status_info["status"]
	var stacks = status_info["stacks"]
	var modifier = 0.0
	
	# 应用固定值修改
	modifier += status.value_flat * stacks
	
	# 应用百分比修改
	modifier += base_value * (status.value_percent * stacks)
	
	# 根据效果类型决定是增加还是减少
	if status.effect_type == SkillStatusData.EffectType.DEBUFF:
		modifier = -modifier
		
	return modifier

## 获取状态每回合伤害/治疗值 (用于DoT/HoT)
func get_dot_hot_value(status_id: String) -> int:
	if !active_statuses.has(status_id):
		return 0
		
	var status_info = active_statuses[status_id]
	var status = status_info["status"]
	var stacks = status_info["stacks"]
	
	return status.dot_hot_value * stacks

## 更新状态持续时间
func update_statuses_duration() -> void:
	var statuses_to_remove = []
	
	# 更新所有状态的持续时间
	for status_id in active_statuses:
		var status_info = active_statuses[status_id]
		status_info["duration"] -= 1
		
		# 如果持续时间结束，准备移除
		if status_info["duration"] <= 0:
			statuses_to_remove.append(status_id)
	
	# 移除已结束的状态
	for status_id in statuses_to_remove:
		remove_status(status_id)
	
	# 执行持续效果
	for status_id in active_statuses:
		var status_info = active_statuses[status_id]
		var status = status_info["status"]
		var source = status_sources.get(status_id, null)
		
		for effect in status.ongoing_effects:
			effect.apply(source, character)

## 检查是否有指定状态
func has_status(status_id: String) -> bool:
	return active_statuses.has(status_id)

## 获取状态的叠加层数
func get_status_stacks(status_id: String) -> int:
	if active_statuses.has(status_id):
		return active_statuses[status_id]["stacks"]
	return 0

## 获取状态的剩余持续时间
func get_status_remaining_duration(status_id: String) -> int:
	if active_statuses.has(status_id):
		return active_statuses[status_id]["duration"]
	return 0

## 应用控制效果
func apply_control_effect(control_type: String, duration: int):
	if control_effects.has(control_type):
		# 如果已有此类控制效果，取更长的持续时间
		control_effects[control_type] = max(control_effects[control_type], duration)
	else:
		# 否则直接添加
		control_effects[control_type] = duration
	
	print("%s 被%s，持续%d回合" % [character.character_name, get_control_name(control_type), duration])

## 检查是否有特定控制效果
func has_control_effect(control_type: String) -> bool:
	return control_effects.has(control_type) and control_effects[control_type] > 0

## 获取所有控制效果
func get_all_control_effects() -> Dictionary:
	return control_effects.duplicate()

## 移除控制效果
func remove_control_effect(control_type: String):
	if control_effects.has(control_type):
		control_effects.erase(control_type)
		print("%s 的%s效果已结束" % [character.character_name, get_control_name(control_type)])

## 获取控制效果显示名称
func get_control_name(control_type: String) -> String:
	match control_type:
		"stun":
			return "眩晕"
		"silence":
			return "沉默"
		"root":
			return "定身"
		"sleep":
			return "睡眠"
		_:
			return control_type

## 检查是否可以行动
func can_act() -> bool:
	# 如果有眩晕效果，无法行动
	if has_control_effect("stun"):
		return false
	
	if has_control_effect("sleep"):
		return false
	
	# 检查状态效果
	for status_id in active_statuses:
		var status_info = active_statuses[status_id]
		var status = status_info["status"]
		if !status.allows_action():
			return false
			
	return true

## 处理回合结束时的控制效果
func process_control_effects_end_turn():
	var effects_to_remove = []
	
	# 减少所有控制效果的持续时间
	for effect_type in control_effects.keys():
		control_effects[effect_type] -= 1
		
		# 如果持续时间为0，准备移除
		if control_effects[effect_type] <= 0:
			effects_to_remove.append(effect_type)
	
	# 移除过期的控制效果
	for effect_type in effects_to_remove:
		remove_control_effect(effect_type)

## 处理回合结束时的状态效果
func process_status_effects_end_of_round() -> void:
	# 处理状态效果持续时间
	update_statuses_duration()
	
	# 处理控制效果持续时间
	process_control_effects_end_turn() 
