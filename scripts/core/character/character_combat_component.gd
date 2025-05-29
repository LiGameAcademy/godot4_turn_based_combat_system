@tool
extends Node
class_name CharacterCombatComponent

## 战斗组件，专注于战斗逻辑

## 动作类型枚举
enum ActionType {
	ATTACK,    ## 普通攻击
	DEFEND,    ## 防御
	SKILL,     ## 使用技能
	ITEM,      ## 使用道具
	FLEE       ## 逃跑
}

## 依赖skill_component组件
@export var _skill_component : CharacterSkillComponent
## 防御状态伤害减免系数
@export var defense_damage_reduction: float = 0.5
# 添加元素属性
@export_enum("none", "fire", "water", "earth", "light")
var element: int = 0 # ElementTypes.Element.NONE
## 攻击技能
var attack_skill : SkillData
## 防御技能
var defense_skill : SkillData

## 死亡时发出信号
signal character_defeated()
## 动作执行信号
signal action_executed(action_type, target, result)
## 攻击执行信号
signal attack_executed(target, damage)
## 防御执行信号
signal defend_executed(character)
## 技能执行信号
signal skill_executed(skill, targets, results)
## 道具使用信号
signal item_used(user, item, targets, results)

## 初始化组件
func initialize(p_element: int, p_attack_skill: SkillData, p_defense_skill: SkillData = null) -> void:
	element = p_element
	attack_skill = p_attack_skill
	defense_skill = p_defense_skill
	
	_skill_component.action_tags_changed.connect(_on_action_tags_changed)
	_skill_component.attribute_current_value_changed.connect(_on_attribute_current_value_changed)
	_skill_component.add_skill(attack_skill)
	_skill_component.add_skill(defense_skill)

## 执行动作
## [param action_type] 动作类型
## [param target] 目标角色
## [param params] 动作参数
## [return] 动作执行结果
func execute_action(
		action_type: ActionType, 
		target: Character = null, 
		params: Dictionary = {}) -> Dictionary:
	var result = {"success": false, "action_type": action_type}
	
	if not _skill_component:
		result["error"] = "技能组件未初始化"
		return result
	
	# 检查是否可以执行该动作类型
	if not can_perform_action(action_type):
		result["error"] = "无法执行该动作类型"
		return result
	
	# 如果是技能动作，还需要检查具体技能是否可用
	if action_type == ActionType.SKILL and params.has("skill"):
		if not _skill_component.is_skill_available(params.skill):
			result["error"] = "无法使用该技能"
			return result
	
	print_rich("[color=green]%s 执行动作: %s[/color]" % [owner.character_name, ActionType.keys()[action_type]])
	
	match action_type:
		ActionType.ATTACK:
			result = await _execute_attack(target, params)
		ActionType.DEFEND:
			result = await _execute_defend(params)
		ActionType.SKILL:
			result = await _execute_skill(params.skill, params.targets, params.skill_context)
		ActionType.ITEM:
			result = await _execute_item(params.item, params.targets)
		ActionType.FLEE:
			result = _execute_flee() # 不需要await
		_:
			result["error"] = "无效的动作类型"
			return result
	
	# 发出动作执行信号
	action_executed.emit(action_type, target, result)
	
	return result

## 伤害处理方法
## [param base_damage] 基础伤害值
## [param source] 伤害来源角色
## [return] 实际造成的伤害值
func take_damage(base_damage: float, source: Variant = null) -> float:
	var final_damage: float = base_damage
	
	# 创建伤害信息对象（根据记忆中的DamageInfo结构）
	var damage_info = {
		"original_base_damage": base_damage,
		"current_base_damage": base_damage,
		"damage_value": base_damage,
		"source_character": source,
		"target_character": owner,
		"can_be_modified": true,
		"modifications": []
	}
	
	# 触发伤害修改事件，允许状态效果修改伤害值
	SkillSystem.trigger_game_event(&"on_damage_taken", {
		"source_character": source,
		"target_character": owner,
		"damage_info": damage_info
	})
	
	# 获取可能被修改后的伤害值
	final_damage = damage_info.damage_value

	if final_damage <= 0:
		return 0
	
	# 播放受击动画
	owner.play_animation("hit") # 不等待动画完成，允许并行处理
	
	# 消耗生命值
	_skill_component.consume_hp(final_damage, source)
	
	# 触发伤害完成事件
	SkillSystem.trigger_game_event(&"on_damage_taken_completed", {
		"source_character": source,
		"target_character": owner,
		"original_damage": base_damage,
		"final_damage": final_damage
	})

	return final_damage

## 治疗处理方法
## [param amount] 治疗量
## [param source] 治疗来源角色
## [return] 实际恢复的治疗量
func heal(amount: float, source: Variant = null) -> float:
	if amount <= 0:
		return 0
	# 恢复生命值
	_skill_component.restore_hp(amount, source)
	return amount

func get_available_skills() -> Array[SkillData]:
	var skills = _skill_component.get_available_skills()
	skills.erase(attack_skill)
	skills.erase(defense_skill)
	return skills

## 在回合开始时调用
func on_turn_start() -> void:
	# 处理状态更新和触发计数重置
	if _skill_component:
		# 重置状态触发计数
		_skill_component.reset_status_trigger_counts()
		# 处理回合开始时的状态更新
		await _skill_component.process_turn_start()
	
	# 可以在这里添加其他回合开始时的逻辑

## 在回合结束时调用
func on_turn_end() -> void:
	# 处理状态效果并更新持续时间
	if _skill_component:
		await _skill_component.process_status_effects()
	
	# 可以在这里添加其他回合结束时的逻辑

## 死亡处理方法
func _die(death_source: Variant = null):
	print_rich("[color=red][b]%s[/b] has been defeated by %s![/color]" % [owner.character_name, death_source])
	character_defeated.emit()

## 执行攻击
## [param target] 目标
## [return] 攻击结果
func _execute_attack(target: Character, params : Dictionary) -> Dictionary:
	var attacker = get_parent()
	if not is_instance_valid(target):
		return {"success": false, "error": "无效的角色引用"}
	
	print_rich("[color=yellow]%s 攻击 %s[/color]" % [attacker.character_name, target.character_name])

	var targets : Array[Character] = [target]
	var result : Dictionary = await _execute_skill(attack_skill, targets, params.skill_context)
	
	var actual_damage = 0
	# 发出攻击执行信号
	attack_executed.emit(target, actual_damage)
	
	return result

## 执行防御
## [return] 防御结果
func _execute_defend(params : Dictionary) -> Dictionary:
	var character = get_parent()
	if not is_instance_valid(character):
		return {"success": false, "error": "无效的角色引用"}
	
	print_rich("[color=cyan]%s 选择防御[/color]" % [character.character_name])
	
	# 使用防御技能
	var targets: Array[Character] = [character] # 目标是自己
	var result: Dictionary = await _execute_skill(defense_skill, targets, params.skill_context)
	
	# 发出防御执行信号
	defend_executed.emit(character)
	
	return result

## 执行技能
## [param skill] 技能数据
## [param targets] 目标列表
## [param skill_context] 技能执行上下文
## [return] 技能执行结果
func _execute_skill(
		skill: SkillData, 
		targets: Array[Character], 
		skill_context : SkillSystem.SkillExecutionContext = null) -> Dictionary:
	var caster = get_parent()
	if not is_instance_valid(caster) or not skill:
		return {"success": false, "error": "无效的施法者或技能"}
	
	print_rich("[color=lightblue]%s 使用技能 %s[/color]" % [caster.character_name, skill.skill_name])
	
	# 检查MP消耗
	if not _skill_component.has_enough_mp_for_skill(skill):
		return {"success": false, "error": "魔法值不足"}
	
	# 尝试执行技能
	var result = await _skill_component.attempt_execute_skill(skill, targets, skill_context)
	
	# 发出技能执行信号
	skill_executed.emit(skill, targets, result)
	
	return result

## 执行使用道具
## [param item] 道具数据
## [param targets] 目标列表
## [return] 道具使用结果
func _execute_item(item, targets: Array) -> Dictionary:
	var user = get_parent()
	if not is_instance_valid(user) or not item:
		return {"success": false, "error": "无效的使用者或道具"}
	
	print_rich("[color=green]%s 使用道具 %s[/color]" % [user.character_name, item.name if item.has("name") else "未知道具"])
	
	# 播放使用道具动画
	await user.play_animation("item")
	
	# 这里是道具使用的占位实现
	# 实际项目中需要根据道具类型实现不同的效果
	var result = {
		"success": true,
		"item": item,
		"targets": {}
	}
	
	# 发出道具使用信号
	item_used.emit(user, item, targets, result)
	
	return result

## 执行逃跑
## [return] 逃跑结果
func _execute_flee() -> Dictionary:
	var character = get_parent()
	if not is_instance_valid(character):
		return {"success": false, "error": "无效的角色引用"}
	
	print_rich("[color=blue]%s 选择逃跑[/color]" % [character.character_name])
	
	# 这里是逃跑的占位实现
	# 实际项目中需要根据游戏逻辑实现不同的效果
	var result = {
		"success": true,
		"message": "逃跑成功"
	}
	
	return result

#region --- 信号处理 ---
## 属性当前值变化的处理
func _on_attribute_current_value_changed(
		attribute_instance: SkillAttribute, 
		_old_value: float, 
		new_value: float, 
		source: Variant) -> void:
	# 如果生命值变为0，则标记为死亡
	if attribute_instance.attribute_name == &"CurrentHealth" and new_value <= 0:
		_die(source)

## 当角色的动作标签变化时调用
func _on_action_tags_changed(restricted_tags: Array[StringName]) -> void:
	# 可以在这里添加额外的处理逻辑，例如更新UI
	print_rich("[color=yellow]%s 的动作限制更新: %s[/color]" % [owner.character_name, restricted_tags])
	
	# 可以发出信号通知UI更新
	# action_restriction_changed.emit(restricted_tags)

#endregion

## 检查是否可以执行该动作类型
func can_perform_action(action_type: ActionType) -> bool:
	if not _skill_component:
		return false
	
	# 根据动作类型检查相应的标签限制
	match action_type:
		ActionType.ATTACK:
			return _skill_component.can_perform_action_category(&"attack")
		ActionType.DEFEND:
			return _skill_component.can_perform_action_category(&"defend")
		ActionType.SKILL:
			return _skill_component.can_perform_action_category(&"any_skill")
		ActionType.ITEM:
			return _skill_component.can_perform_action_category(&"item")
		ActionType.FLEE:
			return _skill_component.can_perform_action_category(&"flee")
		_:
			return false

func _get_configuration_warnings() -> PackedStringArray:
	if not _skill_component:
		return ["CharacterCombatComponent: SkillComponent is not set."]
	return []
