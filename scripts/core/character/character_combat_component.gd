extends Node
class_name CharacterCombatComponent

## 战斗组件，专注于战斗逻辑

## 动作类型枚举
enum ActionType {
	ATTACK,    ## 普通攻击
	DEFEND,    ## 防御
	SKILL,     ## 使用技能
	ITEM       ## 使用道具
}

## 依赖skill_component组件
@export var _skill_component : CharacterSkillComponent
@export_enum("none", "fire", "water", "earth", "light")var element: int = 0 			## 元素属性 ElementTypes.Element.NONE
var attack_skill : SkillData															## 攻击技能
var defense_skill : SkillData															## 防御技能

# 信号
signal character_defeated()															## 死亡时发出信号
signal action_executed(action_type, target, result)									## 动作执行信号
signal attack_executed(attacker, target, damage)									## 攻击执行信号
signal defend_executed(character)													## 防御执行信号
signal skill_executed(caster, skill, targets, results)								## 技能执行信号
signal item_used(user, item, targets, results)										## 道具使用信号

## 初始化组件
func initialize(p_element : int = 0, p_attack_skill : SkillData = null, p_defense_skill : SkillData = null) -> void:
	# 这里可以进行任何战斗组件特定的初始化
	if not _skill_component:
		_skill_component = get_parent().skill_component
	if not _skill_component:
		push_error("无法找到技能组件！")
		return
	
	_skill_component.attribute_current_value_changed.connect(_on_attribute_current_value_changed)
	element = p_element

	if p_attack_skill:
		attack_skill = p_attack_skill
		_skill_component.add_skill(p_attack_skill)
	if p_defense_skill:
		defense_skill = p_defense_skill
		_skill_component.add_skill(p_defense_skill)

## 执行动作
## [param action_type] 动作类型
## [param target] 动作目标
## [param params] 额外参数（如技能数据、道具数据等）
## [return] 动作执行结果
func execute_action(action_type: ActionType, target : Character = null, params : Dictionary = {}) -> Dictionary:
	var result = {}
	
	match action_type:
		ActionType.ATTACK:
			result = await _execute_attack(target, params)
		ActionType.DEFEND:
			result = await _execute_defend(params)
		ActionType.SKILL:
			var skill : SkillData = params.get("skill", null)
			var targets : Array[Character] = params.get("targets", [] as Array[Character])
			targets.append(target)
			var skill_context : SkillSystem.SkillExecutionContext = params.get("skill_context", null)
			result = await _execute_skill(skill, targets, skill_context)
		ActionType.ITEM:
			result = await _execute_item(params.item, params.targets)
		_:
			push_error("未知的动作类型：" + str(action_type))
			result = {"success": false, "error": "未知的动作类型"}
	
	# 发出动作执行信号
	action_executed.emit(action_type, target, result)
	
	return result

## 伤害处理方法
## [param base_damage] 基础伤害值
## [return] 实际造成的伤害值
func take_damage(base_damage: float, source : Character = null) -> float:
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
	_skill_component.consume_hp(final_damage)

	
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
## [return] 实际恢复的治疗量
func heal(amount: float) -> float:
	if amount <= 0:
		return 0
	# 恢复生命值
	_skill_component.restore_hp(amount)
	return amount

## 在回合开始时调用
func on_turn_start(battle_manager : BattleManager) -> void:
	# 可以在这里添加回合开始时的逻辑
	if not _skill_component:
		push_error("无法找到技能组件！")
		return
	_skill_component.process_active_statuses(battle_manager)
	_skill_component.update_status_durations()
	
## 在回合结束时调用
func on_turn_end(_battle_manager : BattleManager) -> void:
	pass

#region --- 私有方法 ---
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
	
	# 发出攻击执行信号
	attack_executed.emit(target, result)
	
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
func _execute_skill(skill: SkillData, targets: Array[Character], skill_context : SkillSystem.SkillExecutionContext = null) -> Dictionary:
	var caster = get_parent()
	if not is_instance_valid(caster) or not skill:
		return {"success": false, "error": "无效的施法者或技能"}
	
	print_rich("[color=lightblue]%s 使用技能 %s[/color]" % [caster.character_name, skill.skill_name])
	
	# 检查MP消耗
	if not _skill_component.has_enough_mp_for_skill(skill):
		return {"success": false, "error": "魔法值不足"}
	
	# 尝试执行技能
	var result = await SkillSystem.attempt_execute_skill(skill, caster, targets, skill_context)
	
	# 发出技能执行信号
	skill_executed.emit(caster, skill, targets, result)
	
	return result

## 执行使用道具
## [param item] 道具数据
## [param targets] 目标列表
## [return] 道具使用结果
func _execute_item(item, targets: Array) -> Dictionary:
	var user = get_parent()
	if not is_instance_valid(user) or not item:
		return {"success": false, "error": "无效的使用者或道具"}
	
	await get_tree().create_timer(0.1).timeout
	print_rich("[color=green]%s 使用道具 %s[/color]" % [user.character_name, item.name if item.has("name") else "未知道具"])
	
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
#endregion

#region --- 信号处理 ---
## 属性当前值变化的处理
func _on_attribute_current_value_changed(
		attribute_instance: SkillAttribute, _old_value: float, new_value: float
	) -> void:
	# 检查是否是生命值变化
	if attribute_instance.attribute_name == &"CurrentHealth" and new_value <= 0:
		_die()
#endregion
