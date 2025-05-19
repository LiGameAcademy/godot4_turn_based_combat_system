extends Node
class_name CombatComponent

#region Signals
## 动作尝试失败
signal action_attempt_failed(character_node: Character, reason: String)
## 防御状态改变
signal defense_state_changed(character_node: Character, is_defending: bool)
#endregion

#region Variables
var character_owner: Character:
	get:
		return get_parent()
@export var skill_component_ref: SkillComponent
var battle_manager_ref: BattleManager  # 由 BattleManager 通过 Character 注入
var skill_system_ref: SkillSystem:      # 由 BattleManager 通过 Character 注入
	get:
		if battle_manager_ref:
			return battle_manager_ref.skill_system
		push_error("can not found battle_manager!")
		return null

@export var _is_defending: bool = false
var _last_action_fail_reason: String = ""
#endregion

func set_battle_manager_reference(p_battle_manager: BattleManager) -> void:
	battle_manager_ref = p_battle_manager

#region Action Readiness & Resource Consumption
# can_perform_action 方法 (根据我们之前的讨论，使用StringName数组)
func can_perform_action(skill_to_cast: SkillData = null, specific_action_category: StringName = &"") -> bool:
	_last_action_fail_reason = "" # 重置原因
	if not character_owner or not character_owner.is_alive or not is_instance_valid(skill_component_ref):
		_last_action_fail_reason = "角色状态无效或缺少SkillComponent。"
		return false

	# 1. 通用行动限制检查 (例如“眩晕”会阻止所有行动)
	for status_instance: SkillStatusData in skill_component_ref.get_all_active_status_instances():
		if not status_instance.restricted_action_categories.is_empty():
			if status_instance.restricted_action_categories.has(&"any_action"): # 假设 ActionTypes.ANY_ACTION
				_last_action_fail_reason = "所有行动均被状态 '%s' 阻止。" % status_instance.status_name
				action_attempt_failed.emit(character_owner, _last_action_fail_reason)
				return false
	
	# 2. 如果是施放特定技能，检查技能固有条件 (MP, 冷却) 和类别限制
	if skill_to_cast:
		if not skill_component_ref.is_skill_ready(skill_to_cast): # 检查MP, 冷却, 是否学习
			_last_action_fail_reason = skill_component_ref.get_last_skill_usability_reason()
			action_attempt_failed.emit(character_owner, _last_action_fail_reason)
			return false

		# 检查技能类别是否被状态限制
		if not skill_to_cast.action_categories.is_empty():
			for status_instance: SkillStatusData in skill_component_ref.get_all_active_status_instances():
				if status_instance.restricted_action_categories.is_empty(): continue
				
				# 检查是否限制所有技能
				if status_instance.restricted_action_categories.has(&"any_skill"): # 假设 ActionTypes.ANY_SKILL
					_last_action_fail_reason = "所有技能均被状态 '%s' 阻止。" % status_instance.status_name
					action_attempt_failed.emit(character_owner, _last_action_fail_reason)
					return false

				for category_of_skill in skill_to_cast.action_categories:
					if status_instance.restricted_action_categories.has(category_of_skill):
						_last_action_fail_reason = "技能类别 '%s' 被状态 '%s' 阻止。" % [category_of_skill, status_instance.status_name]
						action_attempt_failed.emit(character_owner, _last_action_fail_reason)
						return false
	
	# 3. 如果是检查通用行动类别 (非特定技能)
	elif specific_action_category != &"":
		for status_instance: SkillStatusData in skill_component_ref.get_all_active_status_instances():
			if status_instance.restricted_action_categories.has(specific_action_category):
				_last_action_fail_reason = "行动类别 '%s' 被状态 '%s' 阻止。" % [specific_action_category, status_instance.status_name]
				action_attempt_failed.emit(character_owner, _last_action_fail_reason)
				return false
				
	return true

## 执行基础攻击
func perform_basic_attack(target_character: Character) -> Dictionary:
	if not character_owner:
		return {"error": "invalid character_owner for basic attack!"}
	
	if not skill_system_ref:
		return {"error": "invalid skill_system_ref for basic attack!"}
	
	if not is_instance_valid(target_character):
		return {"error": "invalid target_character for basic attack!"}

	# 1. 获取基础攻击对应的 SkillData
	# 假设 CharacterData 中定义了基础攻击的技能ID
	var basic_attack_skill_id = character_owner.character_data.basic_attack_skill_id
	if basic_attack_skill_id == &"":
		push_warning("角色 %s 没有定义基础攻击技能ID (basic_attack_skill_id)。" % character_owner.character_name)
		return {"error": "no_basic_attack_skill_defined"}

	var basic_attack_skill_data: SkillData = skill_component_ref.get_skill_by_id(basic_attack_skill_id)
	if not basic_attack_skill_data:
		push_error("基础攻击技能未找到: %s" % basic_attack_skill_id)
		return {"error": "basic_attack_skill_not_found"}

	# 2. 检查是否能执行此行动 (MP通常为0，但可能被沉默等状态阻止)
	# 假设基础攻击的 action_type_flag 是 Character.ACTION_FLAG_ATTACK
	if not can_perform_action(basic_attack_skill_data, "basic_attack"):
		var reason = get_last_action_fail_reason()
		action_attempt_failed.emit(character_owner, reason) # CombatComponent 发出自己的信号
		return {"error": reason} # 返回失败原因

	# 3. 通过 SkillSystem 执行技能
	var results = await skill_system_ref.execute_skill(character_owner, basic_attack_skill_data, [target_character])
	return results

## 获取可供UI技能列表显示的、当前可用的特殊技能
func get_ui_usable_special_skills() -> Array[SkillData]:
	if not is_instance_valid(skill_component_ref) or not is_instance_valid(character_owner):
		return []

	var usable_skills: Array[SkillData] = []
	var basic_attack_id = character_owner.character_data.basic_attack_skill_id if character_owner.character_data else &""
	var defend_id = character_owner.character_data.defend_skill_id if character_owner.character_data else &""

	for skill_data: SkillData in skill_component_ref.get_learned_skills():
		if not is_instance_valid(skill_data): continue

		# 1. 排除普通攻击和防御（假设它们有专门的UI按钮）
		if skill_data.skill_id == basic_attack_id:
			continue
		if skill_data.skill_id == defend_id: # 如果防御也通过专用按钮触发
			continue
			
		# 2. 检查技能是否因角色状态 (如眩晕、沉默特定技能类别) 而无法施放
		# can_perform_action 会检查MP (通过调用skill_component.is_skill_ready) 
		# 以及角色是否因状态而无法行动或施放特定类型的技能。
		# 你需要在 SkillData 中定义 action_categories，并在 SkillStatusData 中定义 restricted_action_categories
		if can_perform_action(skill_data): # 此处can_perform_action已包含is_skill_ready的检查
			usable_skills.append(skill_data)
		else:
			print_debug("技能 '%s' 因 '%s' 而无法使用。" % [skill_data.skill_name, get_last_action_fail_reason()])

	return usable_skills

## 获取最后的行动失败原因
func get_last_action_fail_reason() -> String:
	return _last_action_fail_reason

## Character.gd 现在有 deduct_mp_for_skill, CombatComponent只需确保调用它
func consume_skill_resources(skill_data: SkillData):
	if character_owner and skill_data:
		character_owner.deduct_mp_for_skill(skill_data.mp_cost, skill_data)
#endregion

#region Damage & Healing Application (由 EffectProcessors 调用)
## 应用伤害效果，返回实际造成的伤害 (正值)
func apply_damage_intake(base_damage: int, source_effect: SkillEffectData) -> int:
	if not character_owner or not character_owner.is_alive or not is_instance_valid(skill_component_ref):
		return 0

	var final_damage_float = float(base_damage)

	if _is_defending:
		final_damage_float *= 0.5
	
	var actual_hp_change = character_owner.modify_hp(-int(round(final_damage_float)), source_effect) # Character处理HP修改
	return -actual_hp_change # 返回伤害值 (正数)

## 应用治疗效果，返回实际治疗量
func apply_heal_intake(base_heal: int, source_char: Character, source_effect: SkillEffectData) -> int:
	if not character_owner or not is_instance_valid(skill_component_ref):
		return 0 # 通常不治疗已不存在的组件的拥有者
	
	var final_heal_float = float(base_heal)
	# TODO: 从 SkillComponent 获取治疗效果加成等属性
	# var healing_bonus = skill_component_ref.get_calculated_attribute(&"HealingBonusPercent")
	# final_heal_float *= (1.0 + healing_bonus)

	var actual_hp_change = character_owner.modify_hp(int(round(final_heal_float)), source_effect)
	return actual_hp_change
#endregion

#region Turn Lifecycle Callbacks (由 BattleManager 调用)
func on_begin_turn():
	if _is_defending: # 如果上一回合在防御，回合开始时取消
		set_defending(false)
	# print("%s's turn begins." % character_owner.character_name)

func on_end_of_turn():
	if not character_owner or not character_owner.is_alive or not is_instance_valid(skill_component_ref):
		return

	# 1. 指示 SkillComponent 处理其状态的持续效果
	await skill_component_ref.process_ongoing_effects()
	
	# 角色可能在持续效果中死亡
	if not character_owner.is_alive: return

	# 2. 指示 SkillComponent 更新状态持续时间
	skill_component_ref.decrement_status_durations()
	
	# 3. 指示 SkillComponent 清理到期状态 (这会触发结束效果)
	skill_component_ref.reap_expired_statuses()

func set_defending(is_defending_now: bool):
	if _is_defending == is_defending_now: return
	_is_defending = is_defending_now
	if character_owner:
		character_owner.show_defense_indicator(_is_defending) # Character负责UI
	defense_state_changed.emit(character_owner, _is_defending)
#endregion
