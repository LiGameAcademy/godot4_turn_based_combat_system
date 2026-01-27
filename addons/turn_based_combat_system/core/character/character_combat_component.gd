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

## 技能系统接口（通过鸭子类型访问，不依赖具体实现）
## 可以是任何实现了技能系统接口的节点
var _skill_system: Node = null

@export_enum("none", "fire", "water", "earth", "light")var element: int = 0 			## 元素属性 ElementTypes.Element.NONE
var attack_skill : Resource = null														## 攻击技能（使用 Resource 类型，不依赖具体实现）
var defense_skill : Resource = null														## 防御技能（使用 Resource 类型，不依赖具体实现）
## 能否行动
var can_action : bool = true:
	get:
		if not is_instance_valid(get_parent()):
			return false
		var skill_sys = _get_skill_system()
		if not skill_sys:
			return true  # 如果没有技能系统，默认可以行动
		if skill_sys.has_method("get_restricted_action_tags"):
			var restricted_tags: Array[String] = skill_sys.get_restricted_action_tags()
			return not restricted_tags.has(&"any_action")
		return true

# 信号
signal character_defeated()															## 死亡时发出信号
signal action_executed(action_type, target, result)									## 动作执行信号
signal attack_executed(attacker, target, damage)									## 攻击执行信号
signal defend_executed(character)													## 防御执行信号
signal skill_executed(caster, skill, targets, results)								## 技能执行信号
signal item_used(user, item, targets, results)										## 道具使用信号

## 初始化组件
func initialize(p_element : int = 0, p_attack_skill : Resource = null, p_defense_skill : Resource = null) -> void:
	element = p_element
	
	# 尝试获取技能系统（通过鸭子类型）
	_skill_system = _get_skill_system()
	
	# 连接技能系统的信号（如果存在）
	if _skill_system:
		if _skill_system.has_signal("attribute_current_value_changed"):
			if not _skill_system.attribute_current_value_changed.is_connected(_on_attribute_current_value_changed):
				_skill_system.attribute_current_value_changed.connect(_on_attribute_current_value_changed)
		if _skill_system.has_signal("action_tags_changed"):
			if not _skill_system.action_tags_changed.is_connected(_on_action_tags_changed):
				_skill_system.action_tags_changed.connect(_on_action_tags_changed)
	
	# 添加技能到技能系统（如果支持）
	if p_attack_skill:
		attack_skill = p_attack_skill
		if _skill_system and _skill_system.has_method("add_skill"):
			_skill_system.add_skill(p_attack_skill)
	if p_defense_skill:
		defense_skill = p_defense_skill
		if _skill_system and _skill_system.has_method("add_skill"):
			_skill_system.add_skill(p_defense_skill)

## 执行动作
## [param action_type] 动作类型
## [param target] 动作目标
## [param params] 额外参数（如技能数据、道具数据等）
## [return] 动作执行结果
func execute_action(action_type: ActionType, target : Node = null, params : Dictionary = {}) -> Dictionary:
	var result = {"success": false, "action_type": action_type, "target": target, "params": params}

	# 检查是否可以执行该动作类型
	if not can_perform_action(action_type):
		result["error"] = "无法执行该动作类型"
		return result

	# 如果是技能动作，检查技能是否可以使用（通过鸭子类型）
	if action_type == ActionType.SKILL:
		var skill : Resource = params.get("skill", null)
		if not skill:
			result["error"] = "技能数据为空"
			return result
		
		var skill_sys = _get_skill_system()
		if skill_sys:
			if skill_sys.has_method("is_skill_available") and not skill_sys.is_skill_available(skill):
				result["error"] = "技能不可用"
				return result
			if skill_sys.has_method("has_enough_mp_for_skill") and not skill_sys.has_enough_mp_for_skill(skill):
				result["error"] = "魔法值不足"
				return result

	var skill_context : SkillExecutionContext = params.get("skill_context", null)
	var targets : Array[Node] = []
	for t in params.get("targets", []):
		targets.append(t)
	match action_type:
		ActionType.ATTACK:
			result = await _execute_attack(target, skill_context)
		ActionType.DEFEND:
			result = await _execute_defend(skill_context)
		ActionType.SKILL:
			var skill : Resource = params.get("skill", null)
			targets.append(target)
			result = await _execute_skill(skill, targets, skill_context)
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
## [param source] 伤害来源
## [param p_element] 元素类型
## [param is_melee] 是否近战
## [return] 实际造成的伤害值
func take_damage(base_damage: float, source : Node, p_element : int, is_melee: bool = false) -> float:
	var final_damage: float = base_damage
	
	# 创建伤害信息对象
	var damage_info: CombatDamageInfo = CombatDamageInfo.new(
		base_damage, source, get_parent(), p_element, is_melee)
	
	# 触发伤害修改事件，允许状态效果修改伤害值
	var damage_event_context : DamageEventContext = DamageEventContext.new(
		source, 
		get_parent(), 
		damage_info
	)
	await SkillSystem.trigger_game_event(get_parent(), &"on_damage_taken", damage_event_context)
	
	# 获取可能被修改后的伤害值
	final_damage = damage_info.final_damage

	if final_damage <= 0:
		return 0
	
	# 播放受击动画（如果父节点有该方法）
	if get_parent().has_method("play_animation"):
		await get_parent().play_animation("hit")
	
	# 消耗生命值（通过鸭子类型）
	var skill_sys = _get_skill_system()
	if skill_sys and skill_sys.has_method("consume_hp"):
		skill_sys.consume_hp(final_damage)
	
	# 触发伤害完成事件
	await SkillSystem.trigger_game_event(get_parent(), &"on_damage_taken_completed", damage_event_context)
	return final_damage

## 治疗处理方法
## [param amount] 治疗量
## [return] 实际恢复的治疗量
func heal(amount: float) -> float:
	if amount <= 0:
		return 0
	# 恢复生命值（通过鸭子类型）
	var skill_sys = _get_skill_system()
	if skill_sys and skill_sys.has_method("restore_hp"):
		return skill_sys.restore_hp(amount)
	return amount

## 在回合开始时调用
func on_turn_start(battle_manager : BattleManager) -> void:
	# 处理技能系统的回合开始逻辑（通过鸭子类型）
	var skill_sys = _get_skill_system()
	if skill_sys:
		if skill_sys.has_method("process_active_statuses"):
			await skill_sys.process_active_statuses(battle_manager)
		if skill_sys.has_method("update_status_durations"):
			skill_sys.update_status_durations()
	
## 在回合结束时调用
func on_turn_end(_battle_manager : BattleManager) -> void:
	pass

## 检查是否可以执行该动作类型
func can_perform_action(action_type: ActionType) -> bool:
	var skill_sys = _get_skill_system()
	if not skill_sys or not skill_sys.has_method("can_perform_action_category"):
		return true  # 如果没有技能系统，默认可以执行
	
	match action_type:
		ActionType.ATTACK:
			return skill_sys.can_perform_action_category(&"attack")
		ActionType.DEFEND:
			return skill_sys.can_perform_action_category(&"defend")
		ActionType.SKILL:
			return skill_sys.can_perform_action_category(&"any_skill")
		ActionType.ITEM:
			return skill_sys.can_perform_action_category(&"item")
		_:
			return false			

## 获取可用技能列表
## [return] 可用技能列表
func get_available_skills() -> Array:
	var skill_sys = _get_skill_system()
	if not skill_sys or not skill_sys.has_method("get_available_skills"):
		return []
	
	var available_skills : Array = skill_sys.get_available_skills().duplicate(true)
	available_skills.erase(attack_skill)
	available_skills.erase(defense_skill)
	return available_skills

#region --- 私有方法 ---
## 死亡处理方法
func _die(death_source: Variant = null):
	var owner_name = _get_character_name(get_parent())
	print_rich("[color=red][b]%s[/b] has been defeated by %s![/color]" % [owner_name, death_source])
	character_defeated.emit()

## 执行攻击
## [param target] 目标
## [return] 攻击结果
func _execute_attack(target: Node, skill_context: SkillExecutionContext) -> Dictionary:
	var attacker = get_parent()
	var attacker_name = _get_character_name(attacker)
	var target_name = _get_character_name(target) if target else ""
	
	print_rich("[color=yellow]%s 攻击 %s[/color]" % [attacker_name, target_name])
	
	var targets : Array[Node] = []
	if target:
		targets.append(target)
	var result : Dictionary = await _execute_skill(attack_skill, targets, skill_context)
	
	# 发出攻击执行信号
	attack_executed.emit(target, result)
	
	return result

## 执行防御
## [return] 防御结果
func _execute_defend(skill_context: SkillExecutionContext) -> Dictionary:
	var character = get_parent()
	if not is_instance_valid(character):
		return {"success": false, "error": "无效的角色引用"}
	
	var char_name = _get_character_name(character)
	print_rich("[color=cyan]%s 选择防御[/color]" % [char_name])
	
	# 使用防御技能
	var targets: Array[Node] = [character] # 目标是自己
	var result: Dictionary = await _execute_skill(defense_skill, targets, skill_context)

	# 发出防御执行信号
	defend_executed.emit(character)
	
	return result

## 执行技能
## [param skill] 技能数据（使用 Resource 类型，不依赖具体实现）
## [param targets] 目标列表
## [param skill_context] 技能执行上下文
## [return] 技能执行结果
func _execute_skill(
		skill: Resource, 
		targets: Array[Node], 
		skill_context: SkillExecutionContext) -> Dictionary:
	var caster = get_parent()
	if not is_instance_valid(caster) or not skill:
		return {"success": false, "error": "无效的施法者或技能"}
	
	# 通过鸭子类型获取技能名称
	var skill_name = _get_skill_name(skill)
	var caster_name = _get_character_name(caster)
	print_rich("[color=lightblue]%s 使用技能 %s[/color]" % [caster_name, skill_name])

	# 移动逻辑（如果父节点有该方法）
	# 通过鸭子类型检查是否是近战技能
	var is_melee = _is_skill_melee(skill)
	if is_melee and not targets.is_empty():
		if caster.has_method("move_to_target"):
			await caster.move_to_target(targets[0])
	else:
		if caster.has_method("move_to_cast_marker"):
			await caster.move_to_cast_marker()
	
	# 检查MP消耗（通过鸭子类型）
	var skill_sys = _get_skill_system()
	if skill_sys and skill_sys.has_method("has_enough_mp_for_skill"):
		if not skill_sys.has_enough_mp_for_skill(skill):
			return {"success": false, "error": "魔法值不足"}
	
	# 尝试执行技能
	var result = await SkillSystem.attempt_execute_skill(skill, caster, targets, skill_context)
	
	# 发出技能执行信号
	skill_executed.emit(caster, skill, targets, result)
	
	# 移动回原位（如果父节点有该方法）
	if caster.has_method("move_back"):
		await caster.move_back()
	return result

## 执行使用道具
## [param item] 道具数据
## [param targets] 目标列表
## [return] 道具使用结果
func _execute_item(item, targets: Array) -> Dictionary:
	var user = get_parent()
	if user.has_method("move_to_cast_marker"):
		await user.move_to_cast_marker()
	
	if not is_instance_valid(user) or not item:
		return {"success": false, "error": "无效的使用者或道具"}
	
	await get_tree().create_timer(0.1).timeout
	var user_name = _get_character_name(user)
	var item_name = item.name if item.has("name") else "未知道具"
	print_rich("[color=green]%s 使用道具 %s[/color]" % [user_name, item_name])
	
	# 这里是道具使用的占位实现
	# 实际项目中需要根据道具类型实现不同的效果
	var result = {
		"success": true,
		"item": item,
		"targets": {}
	}
	
	# 发出道具使用信号
	item_used.emit(user, item, targets, result)
	if user.has_method("move_back"):
		await user.move_back()
	return result
#endregion

#region --- 辅助方法（鸭子类型支持） ---
## 获取技能系统（通过鸭子类型）
## 按优先级尝试：get_skill_component() -> skill_component属性 -> 父节点本身
func _get_skill_system() -> Node:
	if not is_instance_valid(get_parent()):
		return null
	
	var parent = get_parent()
	
	# 优先尝试 get_skill_component() 方法
	if parent.has_method("get_skill_component"):
		var skill_comp = parent.get_skill_component()
		if is_instance_valid(skill_comp):
			return skill_comp
	
	# 尝试 skill_component 属性
	if "skill_component" in parent:
		var skill_comp = parent.skill_component
		if is_instance_valid(skill_comp):
			return skill_comp
	
	# 如果父节点本身实现了技能系统接口，返回父节点
	if _is_skill_system(parent):
		return parent
	
	return null

## 检查节点是否实现了技能系统接口（鸭子类型检查）
func _is_skill_system(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	
	# 检查关键方法是否存在
	var required_methods = ["get_restricted_action_tags", "can_perform_action_category"]
	for method in required_methods:
		if not node.has_method(method):
			return false
	
	return true

## 获取角色名称（鸭子类型）
func _get_character_name(character: Node) -> String:
	if not is_instance_valid(character):
		return "Unknown"
	if character.has_method("get_character_name"):
		return character.get_character_name()
	elif "character_name" in character:
		return character.character_name
	return "Unknown"

## 获取技能名称（鸭子类型）
func _get_skill_name(skill: Resource) -> String:
	if not is_instance_valid(skill):
		return "Unknown Skill"
	# 尝试多种方式获取技能名称
	if is_instance_valid(_skill_system) and _skill_system.has_method("get_skill_name"):
		return _skill_system.get_skill_name(skill)
	elif "skill_name" in skill:
		return skill.skill_name
	elif skill.has_method("get") and skill.get("skill_name"):
		return skill.get("skill_name")
	elif "name" in skill:
		return skill.name
	return "Unknown Skill"

## 检查技能是否是近战（鸭子类型）
func _is_skill_melee(skill: Resource) -> bool:
	if not is_instance_valid(skill):
		return false
	# 尝试多种方式获取 is_melee 属性
	if is_instance_valid(_skill_system) and _skill_system.has_method("is_skill_melee"):
		return _skill_system.is_skill_melee(skill)
	if "is_melee" in skill:
		return skill.is_melee
	elif skill.has_method("get") and skill.get("is_melee") != null:
		return skill.get("is_melee")
	return false
#endregion

#region --- 信号处理 ---
## 属性当前值变化的处理（如果技能系统发出此信号）
func _on_attribute_current_value_changed(
		attribute_instance: SkillAttribute, _old_value: float, new_value: float
	) -> void:
	# 检查是否是生命值变化
	if attribute_instance and attribute_instance.attribute_name == &"CurrentHealth" and new_value <= 0:
		_die()

func _on_action_tags_changed(restricted_tags: Array[String]) -> void:
	# 可以在这里添加额外的处理逻辑，例如更新UI
	var owner_name = _get_character_name(get_parent())
	print_rich("[color=yellow]%s 的动作限制更新: %s[/color]" % [owner_name, restricted_tags])
	
	# 可以发出信号通知UI更新
	# action_restriction_changed.emit(restricted_tags)
#endregion
