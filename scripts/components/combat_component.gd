# res://scripts/components/combat_component.gd
extends Node
class_name CombatComponent

#region Signals
## 行动被阻止
signal action_blocked(character_node: Character, reason: String)
## 防御状态改变
signal defense_state_changed(character_node: Character, is_defending: bool)
# HP/MP/Status 相关的信号现在主要由 SkillComponent 或 Character 发出
#endregion

#region Variables
var character_owner: Character:
	get:
		return get_parent()
var _battle_manager_ref: BattleManager   # 由 BattleManager 注入
var _skill_system_ref: SkillSystem:
	get:
		if _battle_manager_ref:
			return _battle_manager_ref.skill_system
		return null
@export var skill_component_ref: SkillComponent # 由 Character 注入

var _is_defending: bool = false
var _last_action_block_reason: String = ""
#endregion

func set_battle_manager_reference(p_battle_manager: BattleManager):
	_battle_manager_ref = p_battle_manager

#region Action Readiness & Resource Consumption
func can_perform_action(skill_to_cast: SkillData = null, action_type_flag: int = 0) -> bool:
	if not character_owner or not character_owner.is_alive or not skill_component_ref:
		_last_action_block_reason = "Invalid state for action."
		return false

	# 1. MP 检查 (通过 SkillComponent)
	if skill_to_cast:
		if skill_component_ref.get_calculated_attribute(&"CurrentMana") < skill_to_cast.mp_cost:
			_last_action_block_reason = "Not enough MP."
			action_blocked.emit(character_owner, _last_action_block_reason)
			return false
	
	# 2. 状态检查 (通过 SkillComponent 查询状态，但具体行动限制逻辑可能在 SkillStatusData 定义)
	# 假设 SkillStatusData 有 'action_restrictions' 标志位属性 (需要你在SkillStatusData中实现)
	# 例如: Character.ACTION_FLAG_SKILL = 4
	for status_info in skill_component_ref.get_all_active_statuses_info():
		var status_res: SkillStatusData = status_info.status_res
		if status_res.has_meta("action_restrictions"): # 或者直接访问属性 status_res.action_restrictions
			var restrictions = status_res.get_meta("action_restrictions", 0) 
			var current_action_type_flag = action_type_flag
			if skill_to_cast : # 如果是施法，就用技能行动标志
				 # current_action_type_flag = Character.ACTION_FLAG_SKILL # 假设值
				 pass # 你需要定义这个

			if current_action_type_flag > 0 and (restrictions & current_action_type_flag):
				 _last_action_block_reason = "Action type blocked by status: %s" % status_res.status_name
				 action_blocked.emit(character_owner, _last_action_block_reason)
				 return false
			# 你可能还需要一个通用的 "无法行动" 标志，如眩晕
			# elif restrictions & Character.ACTION_FLAG_ANY:
			#      _last_action_block_reason = "All actions blocked by status: %s" % status_res.status_name
			#      action_blocked.emit(character_owner, _last_action_block_reason)
			#      return false
				 
	_last_action_block_reason = ""
	return true

## 获取最后一次行动被阻止的原因
func get_last_action_block_reason() -> String:
	return _last_action_block_reason

## 指示 SkillComponent 或 Character 消耗资源
func consume_skill_resources(skill_data: SkillData):
	if character_owner and skill_data: # Character.gd 有 modify_mp
		character_owner.modify_mp(-skill_data.mp_cost, skill_data)
#endregion

#region Damage & Healing Application (Called by EffectProcessors)
## 应用伤害效果，返回实际造成的伤害 (正值)
func apply_damage_intake(base_damage: int, element: int, source_char: Character, source_effect: SkillEffectData) -> int:
	if not character_owner or not character_owner.is_alive() or not skill_component_ref:
		return 0

	var final_damage_float = float(base_damage)

	# 1. 从 SkillComponent 获取防御、抗性等属性
	var defense_val = skill_component_ref.get_calculated_attribute(&"DefensePower") # 示例
	# TODO: var elemental_resistance = skill_component_ref.get_elemental_resistance(element)

	# 2. 计算伤害减免 (这里是简化逻辑)
	final_damage_float = max(1.0, final_damage_float - defense_val * 0.5) # 保证至少1点伤害
	# final_damage_float *= (1.0 - elemental_resistance)

	if _is_defending:
		final_damage_float *= 0.5 # 防御减伤
	
	# 3. 应用到 Character 的 HP (Character.modify_hp 会处理钳制和信号)
	var actual_hp_change = character_owner.modify_hp(-int(round(final_damage_float)), source_effect)
	
	return -actual_hp_change # 返回伤害值 (正数)

## 应用治疗效果，返回实际治疗量
func apply_heal_intake(base_heal: int, source_char: Character, source_effect: SkillEffectData) -> int:
	if not character_owner or not skill_component_ref: # 允许对死亡单位治疗 (复活)
		return 0
	
	var final_heal_float = float(base_heal)
	# TODO: 从 SkillComponent 获取治疗效果加成等属性
	# var healing_bonus_multiplier = skill_component_ref.get_calculated_attribute(&"HealingBonus")
	# final_heal_float *= healing_bonus_multiplier

	var actual_hp_change = character_owner.modify_hp(int(round(final_heal_float)), source_effect)
	return actual_hp_change
#endregion

#region Turn Lifecycle Callbacks (Called by BattleManager)
## 回合开始时的逻辑
func on_begin_turn():
	if _is_defending: # 如果上一回合在防御，回合开始时取消
		set_defending(false)
	# 其他回合开始时的逻辑...
	print("%s's turn begins." % character_owner.character_name)

## 回合结束时的逻辑
func on_end_of_turn():
	if not character_owner or not character_owner.is_alive() or not skill_component_ref:
		return

	# 指示 SkillComponent 处理状态的持续时间和周期效果
	await skill_component_ref.process_statuses_end_of_turn()
	
	# 防御状态通常在受到攻击或回合结束时自动解除，这里也在回合结束时确保解除
	if _is_defending:
		set_defending(false)
	print("%s's turn processing finished." % character_owner.character_name)

## 设置角色是否处于防御状态
func set_defending(is_defending_now: bool):
	if _is_defending == is_defending_now: return
	_is_defending = is_defending_now
	if character_owner: # 更新 Character 节点的视觉提示
		character_owner.show_defense_indicator(_is_defending)
	defense_state_changed.emit(character_owner, _is_defending)
#endregion
