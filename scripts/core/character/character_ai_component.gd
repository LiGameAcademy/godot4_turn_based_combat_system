extends Node
class_name CharacterAIComponent

## AI配置参数
@export var difficulty_level: int = 1  				## 1-简单, 2-普通, 3-困难
@export var aggression_level: float = 0.5  			## 0.0-1.0, 影响攻击性行为的倾向
@export var skill_usage_chance: float = 0.3  		## 使用技能而非基本攻击的概率
@export var healing_threshold: float = 0.3  		## 当HP低于此百分比时考虑治疗

## 是否启用AI（可用于玩家角色的自动战斗）
@export var ai_enabled: bool = false

## AI行为资源
@export var behavior_resource: AIBehavior

## 行为类型 - 如果没有指定资源，将使用这个类型创建默认行为
@export_enum("balanced", "aggressive", "defensive", "support", "random")
var behavior_type: String = "balanced"

# 引用
var _battle_manager: BattleManager								## 战斗管理器

## AI执行结果类
class AIActionResult:
	var is_valid: bool = false
	var source: Character = null
	var target: Character = null
	var damage: float = 0.0
	var action_type: int = -1
	var skill: SkillData = null
	
	func _init(p_is_valid: bool = false):
		is_valid = p_is_valid

## 初始化方法
## [param p_battle_manager] 战斗管理器
func initialize(p_battle_manager: BattleManager) -> void:
	_battle_manager = p_battle_manager
	
	# 初始化行为资源
	if not behavior_resource:
		behavior_resource = AIBehavior.new()
		behavior_resource.set_behavior_type(behavior_type)

## 执行AI决策并返回结果
## [return] AI决策结果
func execute_action() -> AIActionResult:
	if not ai_enabled:
		push_warning("AI未启用, 无法执行AI决策")
		return AIActionResult.new(false)
	
	# 获取角色
	var owner_character = get_parent() as Character
	if not is_instance_valid(owner_character) or not owner_character.combat_component:
		return AIActionResult.new(false)
	
	# 决定行动
	var action_decision : Dictionary = decide_action()
	
	# 检查决策是否有效
	if action_decision.action_type == null or action_decision.target == null:
		return AIActionResult.new(false)
	
	action_decision.params.merge({
		"skill_context": SkillExecutionContext.new(_battle_manager)
	})
	# 执行决策
	var combat_component : CharacterCombatComponent = owner_character.combat_component
	var result : Dictionary = await combat_component.execute_action(
		action_decision.action_type,
		action_decision.target,
		action_decision.params
	)
	
	# 创建结果对象
	var action_result : AIActionResult = AIActionResult.new(true)
	action_result.source = owner_character
	action_result.target = action_decision.target
	action_result.damage = result.get("damage", 0)
	action_result.action_type = action_decision.action_type
	if action_decision.params.has("skill"):
		action_result.skill = action_decision.params.skill
	
	return action_result

## 决策方法 - 返回一个包含行动信息的字典
## [return] 决策结果
func decide_action() -> Dictionary:
	# 检查AI是否启用
	if not ai_enabled:
		print_rich("[color=red]AI未启用[/color]")
		return {"action_type": null, "target": null, "params": {}}

	var owner_character : Character = get_parent() as Character
	# 基础检查
	if not is_instance_valid(owner_character) or not owner_character.combat_component:
		return {"action_type": null, "target": null, "params": {}}
	
	# 获取可用技能列表
	var available_skills : Array = _get_available_skills()
	
	# 获取可能的目标
	var potential_targets = get_potential_targets()
	if potential_targets.is_empty():
		return {"action_type": null, "target": null, "params": {}}
	
	# 决定使用技能还是基本攻击
	if not available_skills.is_empty() and randf() < skill_usage_chance:
		# 评估每个技能的价值
		var best_skill = null
		var best_skill_score = -1.0
		var best_skill_targets : Array[Character] = []
		
		for skill in available_skills:
			var skill_targets := get_targets_for_skill(skill, potential_targets)
			if not skill_targets.is_empty():
				var skill_score = behavior_resource.evaluate_skill(owner_character, skill, skill_targets)
				if skill_score > best_skill_score:
					best_skill = skill
					best_skill_score = skill_score
					best_skill_targets = skill_targets
		
		# 如果找到了合适的技能
		if best_skill and best_skill_score > 0:
			return {
				"action_type": CharacterCombatComponent.ActionType.SKILL,
				"target": best_skill_targets[0],  # 主要目标
				"params": {
					"skill": best_skill,
					"targets": best_skill_targets  # 可能的多目标
				}
			}
	
	# 如果没有使用技能，则使用基本攻击
	# 评估是否适合防御
	var should_defend = _should_use_defense(owner_character)
	if should_defend and owner_character.combat_component.defense_skill:
		return {
			"action_type": CharacterCombatComponent.ActionType.DEFEND,
			"target": owner_character,
			"params": {
				"skill": owner_character.combat_component.defense_skill
			}
		}
	
	# 评估每个可能的攻击目标
	var valid_attack_targets = []
	var enemies : Array[Character] = _battle_manager.get_valid_enemy_targets(get_parent())
	for target in potential_targets:
		if target in enemies:
			valid_attack_targets.append(target)
	
	if valid_attack_targets.is_empty():
		return {"action_type": null, "target": null, "params": {}}
	
	# 找出最佳攻击目标
	var best_target = null
	var best_target_score = -1.0
	
	for target in valid_attack_targets:
		var target_score = behavior_resource.evaluate_attack_target(owner_character, target)
		if target_score > best_target_score:
			best_target = target
			best_target_score = target_score
	
	return {
		"action_type": CharacterCombatComponent.ActionType.ATTACK,
		"target": best_target,
		"params": {}
	}

## 获取潜在目标
## [return] 潜在目标列表
func get_potential_targets() -> Array:
	var targets : Array[Character]= []
	var owner_character = get_parent() as Character
	# 根据技能类型获取不同的目标列表
	var enemy_targets = _battle_manager.get_valid_enemy_targets(owner_character)
	var ally_targets = _battle_manager.get_valid_ally_targets(true, owner_character)
	
	# 合并目标列表
	targets.append_array(enemy_targets)
	targets.append_array(ally_targets)
	
	return targets

## 为特定技能选择合适的目标
## [param skill] 技能数据
## [param potential_targets] 可能的目标列表
## [return] 适合的目标列表
func get_targets_for_skill(skill: SkillData, potential_targets: Array[Character]) -> Array[Character]:
	var valid_targets : Array[Character] = []
	var owner_character = get_parent() as Character

	var enemy_targets = _battle_manager.get_valid_enemy_targets(owner_character)
	var ally_targets = _battle_manager.get_valid_ally_targets(true, owner_character)
	
	# 根据技能目标类型筛选目标
	match skill.target_type:
		SkillData.TargetType.ENEMY_SINGLE:
			for target in potential_targets:
				if target in enemy_targets:
					valid_targets.append(target)
		
		SkillData.TargetType.ALLY_SINGLE, SkillData.TargetType.ALLY_SINGLE_INC_SELF:
			for target in potential_targets:
				if not target in ally_targets:
					# 如果是ALLY_SINGLE，不包含自己
					if skill.target_type == SkillData.TargetType.ALLY_SINGLE and target == owner_character:
						continue
					valid_targets.append(target)
		
		SkillData.TargetType.SELF:
			valid_targets.append(owner_character)
		
		SkillData.TargetType.ENEMY_ALL:
			for target in potential_targets:
				if target in enemy_targets:
					valid_targets.append(target)
		
		SkillData.TargetType.ALLY_ALL, SkillData.TargetType.ALLY_ALL_INC_SELF:
			for target in potential_targets:
				if not target in ally_targets:
					# 如果是ALLY_ALL，不包含自己
					if skill.target_type == SkillData.TargetType.ALLY_ALL and target == owner_character:
						continue
					valid_targets.append(target)
	
	# 如果是单体技能，确保只返回一个目标
	if skill.target_type in [SkillData.TargetType.ENEMY_SINGLE, SkillData.TargetType.ALLY_SINGLE, 
						SkillData.TargetType.ALLY_SINGLE_INC_SELF, SkillData.TargetType.SELF]:
		if not valid_targets.is_empty():
			# 选择最合适的目标
			return [_select_best_target_for_skill(skill, valid_targets)]
	
	return valid_targets

## 启用/禁用AI
## [param enabled] 是否启用AI
func set_ai_enabled(enabled: bool) -> void:
	ai_enabled = enabled

func is_enemy(target: Character) -> bool:
	return _battle_manager.is_enemy(get_parent(), target)

# 判断是否应该使用防御动作
## [param character] 角色
## [return] 是否应该防御
func _should_use_defense(character: Character) -> bool:
	# 如果角色生命值低，更倾向于防御
	var health_percent = character.current_hp / float(character.max_hp)
	
	# 生命值低于30%时考虑防御
	if health_percent < 0.3:
		# 根据防御倾向和随机因素决定
		var defense_chance = behavior_resource.weights["self_preservation"] * (1.0 - health_percent) * 0.5
		
		# 添加随机性，避免总是防御
		return randf() < defense_chance
	
	# 如果生命值足够高，不需要防御
	return false

## 为技能选择最佳目标
## [param skill] 技能数据
## [param valid_targets] 有效目标列表
## [return] 最佳目标
func _select_best_target_for_skill(skill: SkillData, valid_targets: Array) -> Character:
	# 根据技能类型和行为选择最佳目标
	var owner_character = get_parent() as Character
	var best_target = null
	var best_score = -1.0

	var enemy_targets = _battle_manager.get_valid_enemy_targets(owner_character)
	var ally_targets = _battle_manager.get_valid_ally_targets(true, owner_character)
	
	for target in valid_targets:
		var score = 0.0
		
		# 根据技能效果评分
		for effect in skill.effects:
			if effect is DamageEffectData:
				# 攻击性技能优先选择低血量目标
				var health_percent = target.current_hp / float(target.max_hp)
				score += behavior_resource.weights["target_low_health"] * (1.0 - health_percent)
			elif effect is HealEffectData:
				# 治疗技能优先选择低血量友方
				var health_percent = target.current_hp / float(target.max_hp)
				score += behavior_resource.weights["heal_low_health"] * (1.0 - health_percent)
			elif effect is ApplyStatusEffectData:
				# 状态技能根据状态类型评分
				if effect.status_to_apply.status_type == SkillStatusData.StatusType.BUFF:
					# 增益状态优先给予友方
					if not target in enemy_targets:
						score += behavior_resource.weights["skill_support"]
				elif effect.status_to_apply.status_type == SkillStatusData.StatusType.DEBUFF:
					# 减益状态优先给予敌方
					if target in enemy_targets:
						score += behavior_resource.weights["skill_offensive"]
		
		# 随机因素
		score += randf_range(-0.2, 0.2)
		
		if score > best_score:
			best_score = score
			best_target = target
	
	# 如果没有找到合适的目标，随机选择一个
	if not best_target and not valid_targets.is_empty():
		best_target = valid_targets[randi() % valid_targets.size()]
	
	return best_target

## 获取角色可用的技能列表
## [return] 可用技能列表
func _get_available_skills() -> Array:
	var owner_character : Character = get_parent() as Character
	if not owner_character.skill_component or not owner_character.combat_component:
		print_rich("[color=red]技能组件或战斗组件未初始化[/color]")
		return []
	
	var skills : Array = owner_character.combat_component.get_available_skills()
	return skills

## 检查技能是否可用(状态、冷却、MP等)
## [param skill] 技能数据
## [return] 是否可用
func _can_use_skill(skill: SkillData) -> bool:
	var owner_character : Character = get_parent() as Character
	if not owner_character.skill_component or not owner_character.combat_component:
		return false
	
	# 检查角色是否可以执行技能动作
	if not owner_character.combat_component.can_perform_action(CharacterCombatComponent.ActionType.SKILL):
		return false
	
	# 检查MP消耗
	if not owner_character.skill_component.has_enough_mp_for_skill(skill):
		return false
	
	return true
