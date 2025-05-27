@tool
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
# 添加元素属性
@export_enum("none", "fire", "water", "earth", "light")
var element: int = 0 # ElementTypes.Element.NONE
@export var attack_skill : SkillData

## 防御状态标记
var is_defending: bool = false:
	set(value):
		is_defending = value
		defending_changed.emit(value)


## 死亡时发出信号
signal character_defeated()
signal defending_changed(value: bool)
## 动作执行信号
signal action_executed(action_type, target, result)
## 攻击执行信号
signal attack_executed(attacker, target, damage)
## 防御执行信号
signal defend_executed()
## 技能执行信号
signal skill_executed(caster, skill, targets, results)
## 道具使用信号
signal item_used(user, item, targets, results)

#region --- Public API ---
## 初始化组件
func initialize(p_element: int, p_attack_skill : SkillData) -> void:
	# 这里可以进行任何战斗组件特定的初始化
	if not _skill_component:
		_skill_component = get_parent().skill_component
	if not _skill_component:
		push_error("无法找到技能组件！")
		return
	
	_skill_component.attribute_current_value_changed.connect(_on_attribute_current_value_changed)
	element = p_element
	attack_skill = p_attack_skill
	_skill_component.add_skill(attack_skill)

## 执行动作
## [param action_type] 动作类型
## [param target] 动作目标
## [param params] 额外参数（如技能数据、道具数据等）
## [return] 动作执行结果
func execute_action(action_type: ActionType, target : Character = null, params = null) -> Dictionary:
	var result = {}
	
	match action_type:
		ActionType.ATTACK:
			result = await _execute_attack(target, params.skill_context)
		ActionType.DEFEND:
			result = await _execute_defend()
		ActionType.SKILL:
			result = await _execute_skill(params.skill, params.targets, params.skill_context)
		ActionType.ITEM:
			result = await _execute_item(params.item, params.targets)
		_:
			push_error("未知的动作类型：" + str(action_type))
			result = {"success": false, "error": "未知的动作类型"}
	
	# 发出动作执行信号
	action_executed.emit(action_type, target, result)
	
	return result

## 当该角色回合开始时调用
func on_turn_start() -> void:
	var character_owner = get_parent() as Character
	if not is_instance_valid(character_owner):
		push_error("CharacterCombatComponent: Owner is not a valid Character for on_turn_started.")
		return

	print_rich("[color=green]%s's turn started.[/color]" % character_owner.character_name)

	# 重置技能组件的每回合触发计数
	if is_instance_valid(_skill_component):
		_skill_component.reset_turnly_trigger_counts()
	else:
		push_warning("CharacterCombatComponent: _skill_component is not valid in on_turn_started for %s." % character_owner.character_name)

	# 构建事件上下文
	var event_context = {
		"character": character_owner, # 事件主体是当前角色
		# 可以根据需要添加其他上下文信息，例如当前回合数等
	}
	# 通知 SkillSystem ON_TURN_START 事件
	SkillSystem.notify_game_event(SkillStatusData.TriggerType.ON_TURN_START, event_context)

## 在回合结束时调用
func on_turn_end() -> void:
	var character_owner = get_parent() as Character
	if not is_instance_valid(character_owner):
		push_error("CharacterCombatComponent: Owner is not a valid Character for on_turn_end.")
		return
	
	print_rich("[color=orange]%s's turn ended.[/color]" % character_owner.character_name)
	
	# 构建事件上下文
	var event_context = {
		"character": character_owner, # 事件主体是当前角色
		# 可以根据需要添加其他上下文信息
	}
	# 通知 SkillSystem ON_TURN_END 事件
	SkillSystem.notify_game_event(SkillStatusData.TriggerType.ON_TURN_END, event_context)
	
	# 处理状态效果并更新持续时间
	if _skill_component:
		await _skill_component.process_status_effects()
	
	# 可以在这里添加其他回合结束时的逻辑

## 设置防御状态
func _set_defending(value: bool) -> void:
	is_defending = value

## 伤害处理方法
## [param base_damage] 基础伤害值
## [param source] 伤害来源角色
## [return] 实际造成的伤害值
func take_damage(base_damage: float, source: Variant = null) -> float:
	var final_damage: float = base_damage
	
	# 获取当前角色
	var character_owner = get_parent() as Character
	
	# 触发受到伤害前事件
	var before_damage_context = {
		"character": character_owner, # 受伤的角色
		"source_character": source,   # 伤害来源
		"damage_amount": final_damage, # 初始伤害数值
		"can_be_modified": true       # 标记伤害可以被修改
	}
	SkillSystem.notify_game_event(SkillStatusData.TriggerType.BEFORE_DAMAGE_TAKEN, before_damage_context)
	
	# 检查上下文中是否有修改后的伤害值
	if before_damage_context.has("modified_damage"):
		final_damage = before_damage_context.get("modified_damage")
	
	# 如果有伤害来源，触发造成伤害前事件
	if source is Character:
		var before_deal_damage_context = {
			"character": source,          # 造成伤害的角色
			"target_character": character_owner, # 受伤的角色
			"damage_amount": final_damage, # 当前伤害数值
			"can_be_modified": true       # 标记伤害可以被修改
		}
		SkillSystem.notify_game_event(SkillStatusData.TriggerType.BEFORE_DEAL_DAMAGE, before_deal_damage_context)
		
		# 检查上下文中是否有修改后的伤害值
		if before_deal_damage_context.has("modified_damage"):
			final_damage = before_deal_damage_context.get("modified_damage")

	# 如果处于防御状态，则减免伤害
	if is_defending:
		final_damage = round(final_damage * defense_damage_reduction)
		print(owner.to_string() + " 正在防御，伤害减半！")
		_set_defending(false)  # 防御效果通常在受到一次攻击后解除

	if final_damage <= 0:
		return 0
	
	# 播放受击动画
	owner.play_animation("hit") # 不等待动画完成，允许并行处理
	
	# 消耗生命值
	_skill_component.consume_hp(final_damage, source)
	
	# 构建事件上下文
	var event_context = {
		"character": character_owner, # 受伤的角色
		"source_character": source,   # 伤害来源
		"damage_amount": final_damage # 伤害数值
	}
	# 通知 SkillSystem ON_DAMAGE_TAKEN 事件
	SkillSystem.notify_game_event(SkillStatusData.TriggerType.ON_DAMAGE_TAKEN, event_context)
	
	# 触发受到伤害后事件
	var after_damage_context = {
		"character": character_owner, # 受伤的角色
		"source_character": source,   # 伤害来源
		"damage_amount": final_damage, # 伤害数值
		"current_hp": character_owner.current_hp, # 当前生命值
		"is_dead": character_owner.current_hp <= 0 # 是否死亡
	}
	SkillSystem.notify_game_event(SkillStatusData.TriggerType.AFTER_DAMAGE_TAKEN, after_damage_context)
	
	# 如果有伤害来源，触发造成伤害相关事件
	if source is Character:
		# 触发造成伤害时事件
		var deal_damage_context = {
			"character": source,          # 造成伤害的角色
			"target_character": character_owner, # 受伤的角色
			"damage_amount": final_damage  # 伤害数值
		}
		SkillSystem.notify_game_event(SkillStatusData.TriggerType.ON_DEAL_DAMAGE, deal_damage_context)
		
		# 触发造成伤害后事件
		var after_deal_damage_context = {
			"character": source,          # 造成伤害的角色
			"target_character": character_owner, # 受伤的角色
			"damage_amount": final_damage, # 伤害数值
			"target_current_hp": character_owner.current_hp, # 目标当前生命值
			"target_is_dead": character_owner.current_hp <= 0 # 目标是否死亡
		}
		SkillSystem.notify_game_event(SkillStatusData.TriggerType.AFTER_DEAL_DAMAGE, after_deal_damage_context)
		
		# 如果目标死亡，触发击杀事件
		if character_owner.current_hp <= 0:
			var kill_context = {
				"character": source,          # 击杀者
				"target_character": character_owner, # 被击杀的角色
				"damage_amount": final_damage  # 致命伤害
			}
			SkillSystem.notify_game_event(SkillStatusData.TriggerType.ON_KILL, kill_context)
			
			# 同时触发死亡事件
			var death_context = {
				"character": character_owner, # 死亡的角色
				"source_character": source,   # 死亡原因
				"damage_amount": final_damage # 致命伤害
			}
			SkillSystem.notify_game_event(SkillStatusData.TriggerType.ON_DEATH, death_context)

	return final_damage

## 治疗处理方法
## [param amount] 治疗量
## [param source] 治疗来源角色
## [return] 实际恢复的治疗量
func heal(amount: float, source: Variant = null) -> float:
	if amount <= 0:
		return 0
	
	var character_owner = get_parent() as Character
	
	# 触发治疗前事件
	var before_heal_context = {
		"character": character_owner, # 被治疗的角色
		"source_character": source,   # 治疗来源
		"heal_amount": amount,       # 初始治疗数值
		"can_be_modified": true      # 标记治疗量可以被修改
	}
	SkillSystem.notify_game_event(SkillStatusData.TriggerType.BEFORE_HEAL_RECEIVED, before_heal_context)
	
	# 检查上下文中是否有修改后的治疗量
	if before_heal_context.has("modified_heal"):
		amount = before_heal_context.get("modified_heal")
	
	# 恢复生命值
	_skill_component.restore_hp(amount, source)
	
	# 构建事件上下文
	var event_context = {
		"character": character_owner, # 被治疗的角色
		"source_character": source,   # 治疗来源
		"heal_amount": amount        # 治疗数值
	}
	# 通知 SkillSystem ON_HEAL_RECEIVED 事件
	SkillSystem.notify_game_event(SkillStatusData.TriggerType.ON_HEAL_RECEIVED, event_context)
	
	# 触发治疗后事件
	var after_heal_context = {
		"character": character_owner, # 被治疗的角色
		"source_character": source,   # 治疗来源
		"heal_amount": amount,       # 治疗数值
		"current_hp": character_owner.current_hp, # 当前生命值
		"max_hp": character_owner.max_hp          # 最大生命值
	}
	SkillSystem.notify_game_event(SkillStatusData.TriggerType.AFTER_HEAL_RECEIVED, after_heal_context)
	
	return amount

## 回合开始时重置标记
func reset_turn_flags() -> void:
	_set_defending(false)

#endregion

## 执行攻击
## [param target] 目标
## [param skill_context] 技能执行上下文
## [return] 攻击结果
func _execute_attack(target: Character, skill_context: SkillSystem.SkillExecutionContext) -> Dictionary:
	var character_owner = get_parent() as Character
	if not is_instance_valid(character_owner) or not is_instance_valid(target):
		return {"success": false, "error": "无效的角色引用"}
	
	print_rich("[color=yellow]%s 攻击 %s[/color]" % [character_owner.character_name, target.character_name])
	
	# 获取普攻技能
	if not attack_skill:
		push_error("CharacterCombatComponent: 未设置攻击技能数据")
		return {"success": false, "error": "未设置攻击技能数据"}
	
	# 创建攻击上下文
	var attack_context = {
		"character": character_owner,  # 攻击者
		"target_character": target,    # 攻击目标
		"is_attack": true,             # 标记这是一次攻击
		"skill": attack_skill,         # 使用的普攻技能
		"skill_context": skill_context # 技能执行上下文
	}
	
	# 触发攻击前事件
	SkillSystem.notify_game_event(SkillStatusData.TriggerType.BEFORE_ATTACK, attack_context)
	
	# 将目标转换为数组格式
	var targets = [target]
	
	# 触发攻击时事件
	SkillSystem.notify_game_event(SkillStatusData.TriggerType.ON_ATTACK, attack_context)
	
	# 使用技能系统执行普攻技能
	var skill_result : Dictionary = await _execute_skill(attack_skill, targets, skill_context)
	
	# 构建结果
	var result = {
		"success": skill_result["success"],
		"skill": attack_skill,
		"targets": targets
	}
	
	# 如果成功，处理攻击后逻辑
	if skill_result:
		# 尝试获取伤害数值（如果有）
		var damage_amount = 0
		if targets.size() > 0 and targets[0].combat_component:
			# 实际应用中，应该从技能结果中获取伤害值
			# 如果技能系统返回了伤害信息，可以从中提取
			if skill_context.has("damage_info") and skill_context["damage_info"] is Dictionary:
				damage_amount = skill_context["damage_info"].get("damage_value", 0)
		
		# 更新攻击上下文，添加伤害信息
		attack_context["damage_amount"] = damage_amount
		
		# 发出攻击执行信号
		attack_executed.emit(character_owner, target, damage_amount)
		
		# 触发攻击后事件
		SkillSystem.notify_game_event(SkillStatusData.TriggerType.AFTER_ATTACK, attack_context)
	
	return result

## 执行防御
## [param character] 防御的角色
## [return] 防御结果
func _execute_defend() -> Dictionary:
	var character_owner = get_parent() as Character
	if not is_instance_valid(character_owner):
		return {"success": false, "error": "无效的角色引用"}
	
	print_rich("[color=cyan]%s 选择防御[/color]" % [character_owner.character_name])
	
	# 播放防御动画
	await character_owner.play_animation("defend")
	
	# 设置防御状态
	_set_defending(true)
	
	# 构建结果
	var result = {
		"success": true,
		"defending": true
	}
	
	# 发出防御执行信号
	defend_executed.emit()
	
	return result

## 执行技能
## [param caster] 施法者
## [param skill] 技能数据
## [param targets] 目标列表
## [param skill_context] 技能执行上下文
## [return] 技能执行结果
func _execute_skill(skill: SkillData, targets: Array[Character], skill_context = null) -> Dictionary:
	var character_owner = get_parent() as Character
	if not is_instance_valid(character_owner) or not skill:
		return {"success": false, "error": "无效的施法者或技能"}
	
	print_rich("[color=lightblue]%s 使用技能 %s[/color]" % [character_owner.character_name, skill.skill_name])
	
	# 检查MP消耗
	if not _skill_component.has_enough_mp_for_skill(skill):
		return {"success": false, "error": "魔法值不足"}
	
	# 播放施法动画
	await character_owner.play_animation("skill")
	
	# 尝试执行技能
	var result = await _skill_component.attempt_execute_skill(character_owner, skill, targets, skill_context)
	
	# 发出技能执行信号
	skill_executed.emit(character_owner, skill, targets, result)
	
	return result

## 执行使用道具
## [param item] 道具数据
## [param targets] 目标列表
## [return] 道具使用结果
func _execute_item(item, targets: Array) -> Dictionary:
	var user = get_parent() as Character
	if not is_instance_valid(user) or not item:
		return {"success": false, "error": "无效的角色或道具"}
	
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

## 计算伤害
## [param attacker] 攻击者
## [param target] 目标
## [return] 计算后的伤害值
func _calculate_damage(attacker: Character, target: Character) -> float:
	# 基础伤害计算
	var base_damage := attacker.attack_power
	var final_damage = round(base_damage - target.defense_power)
	
	# 确保伤害至少为1
	final_damage = max(1, final_damage)
	
	return final_damage

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

func _get_configuration_warnings() -> PackedStringArray:
	if not _skill_component:
		return ["CharacterCombatComponent: SkillComponent is not set."]
	return []
