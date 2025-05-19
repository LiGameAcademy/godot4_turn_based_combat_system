extends Node
class_name SkillComponent

#region Signals
signal status_applied(character_node: Character, status_instance: SkillStatusData) # 传递运行时实例
signal status_removed(character_node: Character, status_instance: SkillStatusData) # 传递运行时实例
signal status_updated(character_node: Character, status_instance: SkillStatusData, old_stacks: int, old_duration: int)
# AttributeSet的信号通常由Character或其他系统直接连接
#endregion

#region Variables
var character_owner: Character: # 由 initialize 设置
	get:
		return get_parent()
var skill_system_ref: SkillSystem # 由 Character 注入

@export var attribute_set_resource_template: SkillAttributeSet # 编辑器中分配
var attribute_set_instance: SkillAttributeSet # 运行时唯一的属性集实例

var learned_skills: Array[SkillData] = []

# 存储激活状态的运行时实例 (SkillStatusData的副本)
# Key: StringName (status_id from resource template), Value: SkillStatusData (runtime instance)
var active_statuses: Dictionary[StringName, SkillStatusData] = {}

var _last_skill_usability_reason: String = "" ## 用于存储上次检查失败的原因

#endregion

func initialize(p_character_data: CharacterData) -> void:
	if p_character_data:
		if p_character_data.attribute_set_resource: # CharacterData应包含这个
			attribute_set_resource_template = p_character_data.attribute_set_resource
		learned_skills = p_character_data.skills.duplicate(true)
		learned_skills.append(p_character_data.basic_attack_skill_resource)
	else:
		push_error("SkillComponent for '%s' received no CharacterData." % p_character_data.character_name)
		return # Or set defaults if CharacterData is optional

	if not attribute_set_resource_template:
		push_error("SkillComponent for '%s' requires an AttributeSet resource template." % character_owner.name)
		return

	attribute_set_instance = attribute_set_resource_template.duplicate(true) as SkillAttributeSet
	if not attribute_set_instance:
		push_error("Failed to duplicate AttributeSet for %s" % character_owner.name)
		return
	attribute_set_instance.initialize_set()
	print("SkillComponent for '%s' initialized. AttributeSet keys: %s" % [character_owner.name, attribute_set_instance._initialized_attributes.keys()])


func set_skill_system_reference(p_skill_system: SkillSystem):
	skill_system_ref = p_skill_system

#region Attribute Management
func get_calculated_attribute(attribute_name: StringName) -> float:
	if attribute_set_instance:
		return attribute_set_instance.get_current_value(attribute_name)
	push_warning("SkillComponent: AttributeSet not initialized when trying to get '%s'" % attribute_name)
	return 0.0

## 应用/移除与状态关联的属性修改器
func _apply_modifiers_from_status_instance(status_instance: SkillStatusData, add: bool):
	if not attribute_set_instance or not is_instance_valid(status_instance) or status_instance.attribute_modifiers.is_empty():
		return

	var status_id_source = status_instance.status_id # 使用原始status_id作为来源标识

	for mod_res_template in status_instance.get_attribute_modifiers(): # SkillStatusData中的是模板
		# 重要: Modifier也需要基于模板复制，如果它们有内部状态或需要唯一性
		# 为简单起见，如果你的SkillAttributeModifier是纯数据，可以直接用。
		# 但如果它们可能被改变或需要唯一ID，则也应duplicate()
		var modifier_to_apply = mod_res_template # .duplicate(true) if SkillAttributeModifier can have runtime state

		if add:
			attribute_set_instance.apply_modifier(modifier_to_apply.attribute_to_modify, modifier_to_apply, status_id_source)
		else:
			# AttributeSet.remove_modifier 需要能通过模板资源和来源ID移除
			attribute_set_instance.remove_modifier(modifier_to_apply.attribute_to_modify, modifier_to_apply, status_id_source)
#endregion

#region Status Management
## 返回: Dictionary { applied_successfully: bool, reason: String, status_instance: SkillStatusData (runtime) }
func add_status(new_status_template: SkillStatusData, p_source_char: Character) -> Dictionary:
	if not character_owner or not new_status_template:
		return {"applied_successfully": false, "reason": "invalid_params"}

	var new_status_id: StringName = new_status_template.status_id
	var result_info = {"applied_successfully": false, "reason": "unknown", "status_instance": null}

	# 1. 检查是否被现有状态抵抗 (遍历当前激活的运行时状态实例)
	for active_status_instance: SkillStatusData in active_statuses.values():
		if new_status_template.is_countered_by(active_status_instance.status_id):
			result_info.reason = "resisted_by_status_%s" % active_status_instance.status_id
			return result_info

	# 2. 如果此新状态会覆盖某些现有状态，则先移除它们
	if not new_status_template.overrides_states.is_empty():
		var ids_to_remove_due_to_override: Array[StringName] = []
		for id_to_override in new_status_template.overrides_states:
			if active_statuses.has(id_to_override):
				ids_to_remove_due_to_override.append(id_to_override)
		for id_rem in ids_to_remove_due_to_override:
			await remove_status(id_rem, true) # 触发被覆盖状态的结束效果

	var old_stacks = 0
	var old_duration = 0
	var runtime_status_instance: SkillStatusData # 将持有新的或已更新的运行时实例

	if active_statuses.has(new_status_id): # 状态已存在，处理叠加
		runtime_status_instance = active_statuses[new_status_id]
		old_stacks = runtime_status_instance.stacks
		old_duration = runtime_status_instance.left_duration
		
		match new_status_template.stack_behavior: # 叠加行为由新应用的状态模板决定
			SkillStatusData.StackBehavior.NO_STACK:
				runtime_status_instance.source_char = p_source_char
				runtime_status_instance.left_duration = new_status_template.duration
				result_info.reason = "no_stack_refreshed"
			SkillStatusData.StackBehavior.REFRESH_DURATION:
				runtime_status_instance.left_duration = new_status_template.duration
				runtime_status_instance.source_char = p_source_char
				result_info.reason = "duration_refreshed"
			SkillStatusData.StackBehavior.ADD_DURATION:
				runtime_status_instance.left_duration += new_status_template.duration
				runtime_status_instance.source_char = p_source_char
				result_info.reason = "duration_added"
			SkillStatusData.StackBehavior.ADD_STACKS_REFRESH_DURATION:
				var new_s = min(runtime_status_instance.stacks + 1, new_status_template.max_stacks)
				if new_s > runtime_status_instance.stacks: # 层数实际增加
					_apply_modifiers_from_status_instance(new_status_template, true) # 应用新模板的modifier
				runtime_status_instance.stacks = new_s
				runtime_status_instance.left_duration = new_status_template.duration
				runtime_status_instance.source_char = p_source_char
				result_info.reason = "stacked_duration_refreshed"
			SkillStatusData.StackBehavior.ADD_STACKS_INDEPENDENT_DURATION: # 简化
				var new_s_ind = min(runtime_status_instance.stacks + 1, new_status_template.max_stacks)
				if new_s_ind > runtime_status_instance.stacks:
					_apply_modifiers_from_status_instance(new_status_template, true)
				runtime_status_instance.stacks = new_s_ind
				runtime_status_instance.left_duration = max(runtime_status_instance.left_duration, new_status_template.duration)
				runtime_status_instance.source_char = p_source_char
				result_info.reason = "stacked_independent_simplified"
		
		result_info.applied_successfully = true
		if old_stacks != runtime_status_instance.stacks or old_duration != runtime_status_instance.left_duration:
			status_updated.emit(character_owner, runtime_status_instance, old_stacks, old_duration)
	else: # 新状态添加
		runtime_status_instance = new_status_template.duplicate(true) as SkillStatusData
		if not runtime_status_instance:
			result_info.reason = "failed_to_duplicate_status_template"
			return result_info
			
		runtime_status_instance.source_char = p_source_char
		runtime_status_instance.left_duration = new_status_template.duration # 从模板获取初始持续时间
		runtime_status_instance.stacks = 1
		
		active_statuses[new_status_id] = runtime_status_instance
		_apply_modifiers_from_status_instance(runtime_status_instance, true) # 应用运行时实例的modifier
		result_info.reason = "newly_applied"
		result_info.applied_successfully = true
		status_applied.emit(character_owner, runtime_status_instance)

	result_info.status_instance = runtime_status_instance
	return result_info

## 移除状态，并可选地触发其结束效果 (通过SkillSystem)
func remove_status(status_id: StringName, trigger_end_effects: bool = true) -> bool:
	if active_statuses.has(status_id):
		var runtime_status_instance: SkillStatusData = active_statuses.get(status_id, null)

		_apply_modifiers_from_status_instance(runtime_status_instance, false) # 移除修改器
		status_removed.emit(character_owner, runtime_status_instance) # 传递运行时实例

		if trigger_end_effects and skill_system_ref and not runtime_status_instance.end_effects.is_empty():
			# 使用运行时实例中记录的来源角色
			var effect_source = runtime_status_instance.source_char if is_instance_valid(runtime_status_instance.source_char) else character_owner
			# SkillSystem.apply_effects 现在期望一个效果数组
			await skill_system_ref.apply_effects(runtime_status_instance.get_end_effects(), effect_source, [character_owner])
		return true
	return false

func has_status(status_id: StringName) -> bool:
	return active_statuses.has(status_id)

func get_status_instance(status_id: StringName) -> SkillStatusData: # 返回运行时实例
	return active_statuses.get(status_id, null)

func get_all_active_status_instances() -> Array[SkillStatusData]: # 返回运行时实例数组
	return active_statuses.values()

#endregion

#region Turn-Based Status Processing (Called by CombatComponent)
## 仅减少持续时间，不处理移除
func decrement_status_durations():
	for status_instance: SkillStatusData in active_statuses.values():
		if status_instance.duration_type == SkillStatusData.DurationType.TURNS:
			status_instance.left_duration -= 1
			# print("%s's status %s duration now %d" % [character_owner.name, status_instance.status_id, status_instance.left_duration])

## 移除所有已到期的状态
func reap_expired_statuses():
	var expired_ids: Array[StringName] = []
	for status_instance: SkillStatusData in active_statuses.values():
		if status_instance.duration_type == SkillStatusData.DurationType.TURNS and status_instance.left_duration <= 0:
			expired_ids.append(status_instance.status_id)
	
	for id_to_reap in expired_ids:
		if active_statuses.has(id_to_reap): # 可能已被其他效果移除
			await remove_status(id_to_reap, true)

## 处理所有激活状态的持续效果
func process_ongoing_effects():
	if not skill_system_ref: return

	# 获取键的副本进行迭代，因为 ongoing_effects 可能会修改 active_statuses
	var status_ids_to_process = active_statuses.keys() 
	for status_id in status_ids_to_process:
		if not active_statuses.has(status_id) or not character_owner.is_alive: continue

		var status_instance: SkillStatusData = active_statuses[status_id]
		if not status_instance.ongoing_effects.is_empty():
			var effect_source = status_instance.source_char if is_instance_valid(status_instance.source_char) else character_owner
			# SkillSystem.apply_effects 现在期望一个效果数组
			await skill_system_ref.apply_effects(status_instance.get_ongoing_effects(), effect_source, [character_owner])
		
		if not character_owner.is_alive: break # 如果角色在处理某个状态的持续效果时死亡，停止处理后续状态
#endregion

#region Skill Knowledge
func get_learned_skills() -> Array[SkillData]:
	return learned_skills # learned_skills 在 initialize 时从 CharacterData 加载

func can_character_use_skill(skill_data: SkillData) -> bool: # 内部检查
	if not learned_skills.has(skill_data):
		# print_debug("Skill '%s' not learned by %s" % [skill_data.skill_name, character_owner.name])
		return false
	if get_calculated_attribute(&"CurrentMana") < skill_data.mp_cost:
		# print_debug("%s: Not enough MP for skill '%s'" % [character_owner.name, skill_data.skill_name])
		return false
	# TODO: 检查技能冷却等其他条件
	return true

func get_skill_by_id(id: StringName) -> SkillData:
	for skill in learned_skills:
		if skill and skill.skill_id == id:
			return skill
	return null

func is_skill_ready(skill_data: SkillData) -> bool:
	if not is_instance_valid(skill_data):
		_last_skill_usability_reason = "无效的技能数据。"
		return false
	if not learned_skills.has(skill_data): # 或者通过 skill_data.skill_id 检查
		_last_skill_usability_reason = "角色未学习技能 '%s'。" % skill_data.skill_name
		return false
	if get_calculated_attribute(&"CurrentMana") < skill_data.mp_cost:
		_last_skill_usability_reason = "MP不足以施放 '%s' (需要 %d, 当前 %.0f)。" % [skill_data.skill_name, skill_data.mp_cost, get_calculated_attribute(&"CurrentMana")]
		return false
	
	# TODO: 在此添加技能冷却时间检查 (如果你的系统有这个功能)
	# if skill_data.is_on_cooldown(character_owner): # SkillData 可能需要一个方法或属性来追踪冷却
	#     _last_skill_usability_reason = "技能 '%s' 正在冷却中。" % skill_data.skill_name
	#     return false
		
	_last_skill_usability_reason = ""
	return true

func get_last_skill_usability_reason() -> String:
	return _last_skill_usability_reason

#endregion
