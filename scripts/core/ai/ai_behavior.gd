extends Resource
class_name AIBehavior

## 行为类型
@export var behavior_type: String = "balanced"

## 行为权重配置
@export_group("Weights")
@export var attack_weight: float = 1.0            		## 基础攻击倾向
@export var skill_offensive_weight: float = 1.0   		## 攻击性技能倾向
@export var skill_support_weight: float = 0.5     		## 支援性技能倾向
@export var skill_healing_weight: float = 0.5     		## 治疗技能倾向
@export var target_low_health_weight: float = 1.5  		## 优先攻击低血量目标
@export var target_high_threat_weight: float = 1.0 		## 优先攻击高威胁目标
@export var heal_low_health_weight: float = 2.0    		## 治疗低血量队友
@export var self_preservation_weight: float = 1.0  		## 自我保护倾向

## 所有权重的字典形式
var weights: Dictionary:
	get:
		return {
			"attack": attack_weight,							## 基础攻击倾向
			"skill_offensive": skill_offensive_weight,			## 攻击性技能倾向
			"skill_support": skill_support_weight,				## 支援性技能倾向
			"skill_healing": skill_healing_weight,				## 治疗技能倾向
			"target_low_health": target_low_health_weight,		## 优先攻击低血量目标
			"target_high_threat": target_high_threat_weight,	## 优先攻击高威胁目标
			"heal_low_health": heal_low_health_weight,			## 治疗低血量队友
			"self_preservation": self_preservation_weight		## 自我保护倾向
		}

## 技能类型标签
enum SkillTag {
	OFFENSIVE,  ## 攻击性技能
	DEFENSIVE,  ## 防御性技能
	HEALING,    ## 治疗技能
	SUPPORT,    ## 增益/辅助技能
	DEBUFF      ## 减益技能
}

## 设置行为类型
## [param type] 行为类型
func set_behavior_type(type: String) -> void:
	behavior_type = type
	_configure_behavior()

## 评估技能的价值
## [param character] 角色
## [param skill] 技能数据
## [param targets] 目标列表
## [return] 评分
func evaluate_skill(character: Character, skill: SkillData, targets: Array) -> float:
	var score = 0.0
	
	# 根据技能类型给予基础分数
	var skill_tags = _get_skill_tags(skill)
	
	if SkillTag.OFFENSIVE in skill_tags:
		score += weights["skill_offensive"]
	
	if SkillTag.HEALING in skill_tags:
		score += weights["skill_healing"]
		
		# 如果有队友血量低，增加治疗技能评分
		for target in targets:
			if not _is_enemy(character, target):
				var health_percent = target.current_hp / float(target.max_hp)
				if health_percent < 0.5:
					score += weights["heal_low_health"] * (1.0 - health_percent)
	
	if SkillTag.SUPPORT in skill_tags:
		score += weights["skill_support"]
	
	if SkillTag.DEFENSIVE in skill_tags:
		# 如果自身血量低，增加防御技能评分
		var health_percent = character.current_hp / float(character.max_hp)
		if health_percent < 0.5:
			score += weights["self_preservation"] * (1.0 - health_percent)
	
	# 考虑技能消耗
	var mp_percent_cost = 0.0
	if character.max_mp > 0:
		mp_percent_cost = skill.mp_cost / float(character.max_mp)
	score -= mp_percent_cost * 0.5  # 减少高消耗技能的评分

	# 随机因素，增加一些不可预测性
	score += randf_range(-0.2, 0.2)
	
	return score

## 评估攻击目标的价值
## [param _character] 角色
## [param target] 目标
## [return] 评分
func evaluate_attack_target(_character: Character, target: Character) -> float:
	var score = 0.0
	
	# 基础攻击倾向
	score += weights["attack"]
	
	# 目标血量因素
	var health_percent = target.current_hp / float(target.max_hp)
	score += weights["target_low_health"] * (1.0 - health_percent)
	
	# 目标威胁度（可以基于角色属性、职业等）
	# 这里简单实现，实际可能需要更复杂的威胁度计算
	var threat_score = 0.0
	if target.attack_power > 0:
		threat_score = target.attack_power / 100.0  # 假设100是一个标准值
	score += weights["target_high_threat"] * threat_score
	
	# 随机因素
	score += randf_range(-0.1, 0.1)
	
	return score

## 获取技能的标签（类型）
## [param skill] 技能数据
## [return] 标签列表
func _get_skill_tags(skill: SkillData) -> Array:
	var tags : Array[SkillTag] = []
	
	# 根据技能效果判断类型
	for effect in skill.effects:
		if effect is DamageEffectData or effect is ModifyDamageEffectData:
			tags.append(SkillTag.OFFENSIVE)
		elif effect is HealEffectData:
			tags.append(SkillTag.HEALING)
		elif effect is ApplyStatusEffectData:
			# 根据状态类型判断
			if effect.status_to_apply.status_type == SkillStatusData.StatusType.BUFF:
				tags.append(SkillTag.SUPPORT)
			elif effect.status_to_apply.status_type == SkillStatusData.StatusType.DEBUFF:
				tags.append(SkillTag.DEBUFF)
	# 去重
	var unique_tags : Array[SkillTag] = []
	for tag in tags:
		if not tag in unique_tags:
			unique_tags.append(tag)
	
	return unique_tags

## 判断两个角色是否敌对
## [param character1] 角色1
## [param character2] 角色2
## [return] 是否敌对
func _is_enemy(character1: Character, character2: Character) -> bool:
	# 使用角色组件中的character_registry来判断敌对关系
	if character1.ai_component:
		return character1.ai_component.is_enemy(character2)
	
	# 如果没有角色注册管理器，则无法判断
	return false

## 根据行为类型配置权重
func _configure_behavior() -> void:
	match behavior_type:
		"aggressive":
			attack_weight = 1.5
			skill_offensive_weight = 2.0
			skill_support_weight = 0.3
			skill_healing_weight = 0.2
			target_low_health_weight = 2.0
			target_high_threat_weight = 0.5
			heal_low_health_weight = 0.3
			self_preservation_weight = 0.5
		
		"defensive":
			attack_weight = 0.7
			skill_offensive_weight = 0.5
			skill_support_weight = 1.5
			skill_healing_weight = 1.5
			target_low_health_weight = 0.8
			target_high_threat_weight = 1.5
			heal_low_health_weight = 1.5
			self_preservation_weight = 2.0
		
		"support":
			attack_weight = 0.5
			skill_offensive_weight = 0.3
			skill_support_weight = 2.0
			skill_healing_weight = 2.0
			target_low_health_weight = 0.5
			target_high_threat_weight = 0.5
			heal_low_health_weight = 2.5
			self_preservation_weight = 1.0
		
		"random":
			# 随机权重，每次都不同
			attack_weight = randf_range(0.1, 2.0)
			skill_offensive_weight = randf_range(0.1, 2.0)
			skill_support_weight = randf_range(0.1, 2.0)
			skill_healing_weight = randf_range(0.1, 2.0)
			target_low_health_weight = randf_range(0.1, 2.0)
			target_high_threat_weight = randf_range(0.1, 2.0)
			heal_low_health_weight = randf_range(0.1, 2.0)
			self_preservation_weight = randf_range(0.1, 2.0)
		
		_: # "balanced" 或其他
			# 保持默认权重
			attack_weight = 1.0
			skill_offensive_weight = 1.0
			skill_support_weight = 0.5
			skill_healing_weight = 0.5
			target_low_health_weight = 1.5
			target_high_threat_weight = 1.0
			heal_low_health_weight = 2.0
			self_preservation_weight = 1.0
