extends Node
class_name CharacterCombatComponent

## 战斗组件，专注于战斗逻辑

## 动作类型枚举
enum ActionType {
	ATTACK,    # 普通攻击
	DEFEND,    # 防御
	SKILL,     # 使用技能
	ITEM       # 使用道具
}

## 依赖skill_component组件
@export var _skill_component : CharacterSkillComponent
## 防御状态伤害减免系数
@export var defense_damage_reduction: float = 0.5
## 防御状态标记
var is_defending: bool = false:
	set(value):
		is_defending = value
		defending_changed.emit(value)

## 死亡时发出信号
signal character_defeated()
signal defending_changed(value: bool)
## 动作执行信号
signal action_executed(action_type, source, target, result)
## 攻击执行信号
signal attack_executed(attacker, target, damage)
## 防御执行信号
signal defend_executed(character)
## 技能执行信号
signal skill_executed(caster, skill, targets, results)
## 道具使用信号
signal item_used(user, item, targets, results)

## 初始化组件
func initialize() -> void:
	# 这里可以进行任何战斗组件特定的初始化
	if not _skill_component:
		_skill_component = get_parent().skill_component
	if not _skill_component:
		push_error("无法找到技能组件！")
		return
	
	_skill_component.attribute_current_value_changed.connect(_on_attribute_current_value_changed)

## 执行动作
## [param action_type] 动作类型
## [param source] 动作执行者
## [param target] 动作目标
## [param params] 额外参数（如技能数据、道具数据等）
## [return] 动作执行结果
func execute_action(action_type: ActionType, source: Character, target = null, params = null) -> Dictionary:
	var result = {}
	
	match action_type:
		ActionType.ATTACK:
			result = await _execute_attack(source, target)
		ActionType.DEFEND:
			result = await _execute_defend(source)
		ActionType.SKILL:
			result = await _execute_skill(source, params.skill, params.targets, params.skill_context)
		ActionType.ITEM:
			result = await _execute_item(source, params.item, params.targets)
		_:
			push_error("未知的动作类型：" + str(action_type))
			result = {"success": false, "error": "未知的动作类型"}
	
	# 发出动作执行信号
	action_executed.emit(action_type, source, target, result)
	
	return result

## 设置防御状态
func set_defending(value: bool) -> void:
	is_defending = value

## 伤害处理方法
## [param base_damage] 基础伤害值
## [param source] 伤害来源角色
## [return] 实际造成的伤害值
func take_damage(base_damage: float) -> float:
	var final_damage: float = base_damage

	# 如果处于防御状态，则减免伤害
	if is_defending:
		final_damage = round(final_damage * defense_damage_reduction)
		print(owner.to_string() + " 正在防御，伤害减半！")
		set_defending(false)  # 防御效果通常在受到一次攻击后解除

	if final_damage <= 0:
		return 0
	# 消耗生命值	
	_skill_component.consume_hp(final_damage)

	return final_damage

## 治疗处理方法
## [param amount] 治疗量
## [param source] 治疗来源角色
## [return] 实际恢复的治疗量
func heal(amount: float) -> float:
	if amount <= 0:
		return 0
	# 恢复生命值
	_skill_component.restore_hp(amount)
	return amount

## 回合开始时重置标记
func reset_turn_flags() -> void:
	set_defending(false)

## 执行攻击
## [param attacker] 攻击者
## [param target] 目标
## [return] 攻击结果
func _execute_attack(attacker: Character, target: Character) -> Dictionary:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return {"success": false, "error": "无效的角色引用"}
	
	await get_tree().create_timer(0.5).timeout
	print_rich("[color=yellow]%s 攻击 %s[/color]" % [attacker.character_name, target.character_name])
	
	# 计算伤害
	var base_damage = attacker.physical_attack
	var damage_reduction = target.physical_defense / (target.physical_defense + 100.0)
	var final_damage = round(base_damage * (1.0 - damage_reduction))
	
	# 确保伤害至少为1
	final_damage = max(1, final_damage)
	
	# 应用伤害
	var actual_damage = target.combat_component.take_damage(final_damage)
	
	# 构建结果
	var result = {
		"success": true,
		"damage": actual_damage,
		"critical": false  # 可以在这里添加暴击判定
	}
	
	# 发出攻击执行信号
	attack_executed.emit(attacker, target, actual_damage)
	
	return result

## 执行防御
## [param character] 防御的角色
## [return] 防御结果
func _execute_defend(character: Character) -> Dictionary:
	if not is_instance_valid(character):
		return {"success": false, "error": "无效的角色引用"}
	
	await get_tree().create_timer(0.5).timeout
	print_rich("[color=cyan]%s 选择防御[/color]" % [character.character_name])
	
	# 设置防御状态
	set_defending(true)
	
	# 构建结果
	var result = {
		"success": true,
		"defending": true
	}
	
	# 发出防御执行信号
	defend_executed.emit(character)
	
	return result

## 执行技能
## [param caster] 施法者
## [param skill] 技能数据
## [param targets] 目标列表
## [param skill_context] 技能执行上下文
## [return] 技能执行结果
func _execute_skill(caster: Character, skill: SkillData, targets: Array, skill_context = null) -> Dictionary:
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
## [param user] 使用者
## [param item] 道具数据
## [param targets] 目标列表
## [return] 道具使用结果
func _execute_item(user: Character, item, targets: Array) -> Dictionary:
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

## 死亡处理方法
func _die(death_source: Variant = null):
	print_rich("[color=red][b]%s[/b] has been defeated by %s![/color]" % [owner.character_name, death_source])
	character_defeated.emit()

#region --- 信号处理 ---
## 属性当前值变化的处理
func _on_attribute_current_value_changed(
		attribute_instance: SkillAttribute, _old_value: float, 
		new_value: float, source: Variant
	) -> void:
	# 检查是否是生命值变化
	if attribute_instance.attribute_name == &"CurrentHealth" and new_value <= 0:
		_die(source)
#endregion
