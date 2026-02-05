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
@export var _skill_component : SkillComponentInterface
@export_enum("none", "fire", "water", "earth", "light")var element: int = 0 			## 元素属性 ElementTypes.Element.NONE
var attack_skill_id : StringName															## 攻击技能
var defense_skill_id : StringName															## 防御技能
## 能否行动
var can_action : bool = true:
	get:
		if not is_instance_valid(get_parent()):
			return false
		if not is_instance_valid(_skill_component):
			return false
		var restricted_tags := _skill_component.get_restricted_action_tags()
		return not restricted_tags.has(&"any_action")

var is_alive : bool:
	get:
		if not is_instance_valid(_skill_component):
			return false
		return _skill_component.get_attribute_current_value(&"CurrentHealth") > 0

# 信号
signal character_defeated()															## 死亡时发出信号
signal action_started(action_type, target, params)									## 动作开始执行信号
signal action_executed(action_type, target, result)									## 动作执行完成信号
signal item_used(user, item, targets, results)										## 道具使用信号

## 初始化组件
func initialize(p_element : int = 0, p_attack_skill_id : StringName = "", p_defense_skill_id : StringName = "") -> void:
	# 这里可以进行任何战斗组件特定的初始化
	if not is_instance_valid(_skill_component):
		_skill_component = get_parent().skill_component
	if not is_instance_valid(_skill_component):
		push_error("CharacterCombatComponent: 无法找到技能组件！")
		return
	
	_skill_component.attribute_current_value_changed.connect(_on_attribute_current_value_changed)
	_skill_component.action_tags_changed.connect(_on_action_tags_changed)
	element = p_element

	if not p_attack_skill_id.is_empty():
		attack_skill_id = p_attack_skill_id
	if not p_defense_skill_id.is_empty():
		defense_skill_id = p_defense_skill_id

## 执行动作
## [param action_type] 动作类型
## [param target] 动作目标
## [param params] 额外参数（如技能数据、道具数据等）
## [return] 动作执行结果
func execute_action(action_type: ActionType, target : Character = null, params : Dictionary = {}) -> Dictionary:
	var result = {"success": false, "action_type": action_type, "target": target, "params": params}

	# 检查是否可以执行该动作类型
	if not can_perform_action(action_type):
		result["error"] = "无法执行该动作类型"
		return result

	# 发出动作开始执行信号
	action_started.emit(action_type, target, params)

	var skill_context : Dictionary = params
	var targets : Array[Node] = [target]
	for t in params.get("targets", []):
		targets.append(t)
	match action_type:
		ActionType.ATTACK:
			skill_context["skill_id"] = attack_skill_id
			result = await _execute_attack(target, skill_context)
		ActionType.DEFEND:
			skill_context["skill_id"] = defense_skill_id
			result = await _execute_defend(skill_context)
		ActionType.SKILL:
			var skill_id : StringName = params.get("skill_id", null)
			targets.append(target)
			result = await _execute_skill(skill_id, targets, skill_context)
		ActionType.ITEM:
			var item = params.get("item", null)
			targets.append(target)
			result = await _execute_item(item, targets)
		_:
			push_error("未知的动作类型：" + str(action_type))
			result = {"success": false, "error": "未知的动作类型"}
	
	# 发出动作执行信号
	action_executed.emit(action_type, target, result)
	return result

## 伤害处理方法
## [param base_damage] 基础伤害值
## [return] 实际造成的伤害值
func take_damage(base_damage: float, source : Character, p_element : int, is_melee: bool = false) -> float:
	var final_damage: float = base_damage
	
	# 创建伤害信息对象
	var damage_info: DamageInfo = DamageInfo.new(base_damage, source, get_parent(), p_element, is_melee)
	
	# 触发伤害修改事件，允许状态效果修改伤害值
	var damage_event_context : DamageEventContext = DamageEventContext.new(source, get_parent(), damage_info)
	TBCombatSystem.trigger_game_event(&"on_damage_taken", get_parent(), damage_event_context)
	
	# 获取可能被修改后的伤害值
	final_damage = damage_info.final_damage

	if final_damage <= 0:
		return 0
	
	# 播放受击动画
	await get_parent().play_animation("hit") # 不等待动画完成，允许并行处理
	
	# 消耗生命值
	_skill_component.consume_hp(final_damage)
	
	# 触发伤害完成事件
	TBCombatSystem.trigger_game_event(&"on_damage_taken_completed", get_parent(), damage_event_context)
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
	if not is_instance_valid(_skill_component):
		push_error("CharacterCombatComponent: 无法找到技能组件！")
		return
	_skill_component.process_active_statuses(battle_manager)
	_skill_component.update_status_durations()
	
## 在回合结束时调用
func on_turn_end(_battle_manager : BattleManager) -> void:
	pass

## 检查是否可以执行该动作类型
func can_perform_action(action_type: ActionType) -> bool:
	if not is_instance_valid(_skill_component):
		push_error("CharacterCombatComponent: 无法找到技能组件！")
		return false
	match action_type:
		ActionType.ATTACK:
			return _skill_component.can_perform_action_category(&"attack")
		ActionType.DEFEND:
			return _skill_component.can_perform_action_category(&"defend")
		ActionType.SKILL:
			return _skill_component.can_perform_action_category(&"any_skill")
		ActionType.ITEM:
			return _skill_component.can_perform_action_category(&"item")
		_:
			return false			

## 获取可用技能列表
## [return] 可用技能列表
func get_available_skills() -> Array[StringName]:
	var available_skills : Array[StringName] = _skill_component.get_available_skills().duplicate(true)
	available_skills.erase(attack_skill_id)
	available_skills.erase(defense_skill_id)
	return available_skills

## 检查动作是否需要目标
func need_target_for_action(action_type: ActionType) -> bool:
	match action_type:
		ActionType.ATTACK:
			return true
		ActionType.DEFEND:
			return false
		ActionType.SKILL:
			return true
		ActionType.ITEM:
			return true
		_:
			return false
	return false

#region --- 私有方法 ---
## 死亡处理方法
func _die(death_source: Variant = null):
	print_rich("[color=red][b]%s[/b] has been defeated by %s![/color]" % [owner.character_name, death_source])
	character_defeated.emit()

## 执行攻击
## [param target] 目标
## [return] 攻击结果
func _execute_attack(target: Character, skill_context: Dictionary) -> Dictionary:
	var attacker = get_parent()
	if not is_instance_valid(target):
		return {"success": false, "error": "无效的角色引用"}
	
	print_rich("[color=yellow]%s 攻击 %s[/color]" % [attacker.character_name, target.character_name if target else ""])
	
	var targets : Array[Node]
	if is_instance_valid(target):
		targets.append(target)
	var result : Dictionary = await _execute_skill(attack_skill_id, targets, skill_context)
	
	return result

## 执行防御
## [return] 防御结果
func _execute_defend(skill_context: Dictionary) -> Dictionary:
	var character = get_parent()
	if not is_instance_valid(character):
		return {"success": false, "error": "无效的角色引用"}
	
	print_rich("[color=cyan]%s 选择防御[/color]" % [character.character_name])
	
	# 使用防御技能
	var targets: Array[Node] = [character] # 目标是自己
	var result: Dictionary = await _execute_skill(defense_skill_id, targets, skill_context)

	return result

## 执行技能
## [param skill] 技能数据
## [param targets] 目标列表
## [param skill_context] 技能执行上下文
## [return] 技能执行结果
func _execute_skill(skill_id: StringName, targets: Array[Node], skill_context: Dictionary) -> Dictionary:
	var caster = get_parent()
	if not is_instance_valid(caster) or skill_id.is_empty():
		return {"success": false, "error": "无效的施法者或技能"}
	if skill_id.is_empty():
		return {"success": false, "error": "技能数据为空"}
	if not _skill_component.is_skill_available(skill_id):
		return {"success": false, "error": "技能不可用"}
	if not _skill_component.has_enough_mp_for_skill(skill_id):
		return {"success": false, "error": "魔法值不足"}

	print_rich("[color=lightblue]%s 使用技能 %s[/color]" % [caster.character_name, skill_id])

	if _skill_component.is_skill_melee(skill_id) and not targets.is_empty():
		await get_parent().move_to_target(targets[0])
	else:
		await get_parent().move_to_cast_marker()

	# 尝试执行技能
	var final_targets : Array[Node]
	for target in targets:
		final_targets.append(target)
	var result = await _skill_component.execute_skill(skill_id, final_targets, skill_context)
	
	await get_parent().move_back()
	return result

## 执行使用道具
## [param item] 道具数据
## [param targets] 目标列表
## [return] 道具使用结果
func _execute_item(item, targets: Array) -> Dictionary:
	await get_parent().move_to_cast_marker()
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
	await get_parent().move_back()
	return result
#endregion

#region --- 信号处理 ---
## 属性当前值变化的处理
func _on_attribute_current_value_changed(attribute_id: StringName, _old_value: float, new_value: float) -> void:
	# 检查是否是生命值变化
	if attribute_id == &"CurrentHealth" and new_value <= 0:
		_die()

## 动作标签改变的处理
func _on_action_tags_changed(restricted_tags: Array[String]) -> void:
	# 可以在这里添加额外的处理逻辑，例如更新UI
	print_rich("[color=yellow]%s 的动作限制更新: %s[/color]" % [owner.character_name, restricted_tags])
	
	# 可以发出信号通知UI更新
	# action_restriction_changed.emit(restricted_tags)
#endregion
