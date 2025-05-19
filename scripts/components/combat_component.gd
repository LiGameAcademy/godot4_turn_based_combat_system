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
		return null

@export var _is_defending: bool = false
var _last_action_fail_reason: String = ""
#endregion

func set_battle_manager_references(p_battle_manager: BattleManager) -> void:
	battle_manager_ref = p_battle_manager

#region Action Readiness & Resource Consumption
## 检查是否能执行某个技能或通用行动类型
func can_perform_action(skill_to_cast: SkillData = null, specific_action_category: StringName = &"") -> bool:
	if not character_owner or not character_owner.is_alive or not is_instance_valid(skill_component_ref):
		_last_action_fail_reason = "角色状态无效或缺少SkillComponent。"
		return false

	# 1. MP 及其他技能自身条件检查 (通过 SkillComponent)
	if skill_to_cast:
		if not skill_component_ref.can_character_use_skill(skill_to_cast):
			# can_character_use_skill 内部会检查MP, 可能还有冷却等
			_last_action_fail_reason = "无法使用技能: " + (skill_component_ref.get_last_skill_usability_reason() if skill_component_ref.has_method("get_last_skill_usability_reason") else "MP不足或不满足其他条件。")
			action_attempt_failed.emit(character_owner, _last_action_fail_reason)
			return false
	
	# 2. 确定当前尝试的行动类别
	var categories_of_attempted_action: Array[String] = []
	if skill_to_cast and not skill_to_cast.action_categories.is_empty():
		categories_of_attempted_action = skill_to_cast.action_categories
	elif specific_action_category != &"":
		categories_of_attempted_action.append(specific_action_category)
	
	# (可选) 如果没有任何类别被指定，你可能需要一个默认行为，
	# 例如，如果一个行动没有类别，它是否会受 "any_action" 或 "any_skill" 的限制？
	# 这里我们假设如果 categories_of_attempted_action 为空，则只受 ActionTypes.ANY_ACTION 限制。

	# 3. 状态检查 (基于 SkillStatusData 的 restricted_action_categories)
	for status_instance: SkillStatusData in skill_component_ref.get_all_active_status_instances():
		if status_instance.restricted_action_categories.is_empty():
			continue # 此状态不限制任何特定类别的行动

		# 检查是否限制所有行动
		if status_instance.restricted_action_categories.has("any_action"):
			_last_action_fail_reason = "所有行动均被状态 '%s' 阻止。" % status_instance.status_name
			action_attempt_failed.emit(character_owner, _last_action_fail_reason)
			return false
		
		# 如果正在尝试一个有类别的行动
		if not categories_of_attempted_action.is_empty():
			for attempted_category in categories_of_attempted_action:
				if status_instance.restricted_action_categories.has(attempted_category):
					_last_action_fail_reason = "行动类别 '%s' 被状态 '%s' 阻止。" % [attempted_category, status_instance.status_name]
					action_attempt_failed.emit(character_owner, _last_action_fail_reason)
					return false
		# (可选) 如果 categories_of_attempted_action 为空 (例如，一个没有明确类别的通用行动)，
		# 而状态限制了 ActionTypes.ANY_SKILL 或其他通用类别，你可能也需要在这里处理。
		# 例如，如果一个技能没有明确的类别，但角色中了“沉默”（限制ActionTypes.ANY_SKILL），是否应阻止？
		# 这取决于你的设计细致程度。

	_last_action_fail_reason = ""
	return true

func perform_basic_attack(target_character: Character) -> Dictionary:
	if not character_owner or not is_instance_valid(target_character) or not skill_system_ref:
		return {"error": "invalid_params_for_basic_attack"}

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
		# else:
			# print_debug("技能 '%s' 因 '%s' 而无法使用。" % [skill_data.skill_name, get_last_action_fail_reason()])

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
func apply_damage_intake(base_damage: int, element: int, source_char: Character, source_effect: SkillEffectData) -> int:
	if not character_owner or not character_owner.is_alive or not is_instance_valid(skill_component_ref):
		return 0

	var final_damage_float = float(base_damage)

	var defense_val = skill_component_ref.get_calculated_attribute(&"DefensePower") # 从SkillComponent获取
	# TODO: 实现元素抗性、易伤等逻辑，从SkillComponent获取相关属性或状态效果
	# var elemental_modifier = ElementalSystem.get_damage_modifier(element, character_owner.element, skill_component_ref)
	
	final_damage_float = max(1.0, final_damage_float - defense_val * 0.5) # 简化伤害计算
	# final_damage_float *= elemental_modifier

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
	
	if _is_defending: # 再次检查，因为状态效果可能改变防御状态
		set_defending(false)
	# print("%s's turn processing finished." % character_owner.character_name)

func set_defending(is_defending_now: bool):
	if _is_defending == is_defending_now: return
	_is_defending = is_defending_now
	if character_owner:
		character_owner.show_defense_indicator(_is_defending) # Character负责UI
	defense_state_changed.emit(character_owner, _is_defending)
#endregion
