extends SkillEffect
class_name DamageEffect

## 最低伤害比例
const MIN_DAMAGE_PERCENT = 0.1

# 伤害效果参数
@export_group("伤害效果参数", "damage_")
@export var damage_amount: int = 10     		## 基础伤害值
@export var damage_power_scale: float = 1.0  	## 攻击力加成系数

@export_group("防御力加成")
@export var defense_power_scale: float = 0.0  	## 防御力加成系数

@export_group("随机伤害")
@export var apply_damage_random: bool = true 	## 是否应用伤害随机
@export var damage_random_range: float = 0.1 	## 伤害随机范围

## 获取伤害效果描述
## 获取伤害效果的基础描述 (重构后)
func _get_base_description() -> String:
	var description_parts: Array[String] = []

	# 1. 处理基础伤害部分
	if damage_amount > 0:
		description_parts.append("%d点" % damage_amount)

	# 2. 处理攻击力加成部分
	if damage_power_scale > 0:
		# 将小数（如1.0）转换为百分比（100%）
		description_parts.append("%d%%攻击力" % (damage_power_scale * 100))

	# 3. 处理防御力加成部分
	if defense_power_scale > 0:
		description_parts.append("%d%%防御力" % (defense_power_scale * 100))

	# 4. 如果没有任何伤害组件，返回一个明确的无伤害描述
	if description_parts.is_empty():
		return "不造成直接伤害"

	# 5. 将所有伤害组件用“+”连接，并组合成一句通顺的话
	var final_description = "造成 %s 的物理伤害" % " + ".join(description_parts)

	return final_description

## 处理伤害效果
func _process_effect(source: Node, target: Node, context : SkillExecutionContext) -> Dictionary:
	if not is_instance_valid(source):
		push_error("DamageEffect: 无效的源节点引用")
		return {
			"success": false,
			"reason": "Invalid source node reference!"
		}
	if not is_instance_valid(target):
		push_error("DamageEffect: 无效的目标节点引用")
		return {
			"success": false,
			"reason": "Invalid target node reference!"
		}
	
	var target_combat_component : CharacterCombatComponent = target.get_combat_component() if target.has_method("get_combat_component") else null
	if not is_instance_valid(target_combat_component):
		push_error("DamageEffect: 无效的目标战斗组件引用")
		return {
			"success": false,
			"reason": "Invalid target combat component reference!"
		}

	var results = {}
	# 检查目标是否存活
	if not target_combat_component.is_alive:
		return {
			"success": false,
			"reason": "target_is_dead"
		}
		
	# 计算伤害
	var damage_result := _calculate_damage(source, target)
	var damage = damage_result["damage"]
	
	# 根据元素克制关系选择不同效果
	_request_element_effect(damage_result, target, context.battle_manager, {"amount": damage, "element": element})
	
	# 应用伤害
	var is_melee : bool = context.skill_data.is_melee if context.skill_data else false
	var actual_damage = await target_combat_component.take_damage(damage, source, element, is_melee)
	
	# 记录结果
	results["damage"] = actual_damage
	
	# 显示伤害信息
	var message = _get_damage_info(target, damage, damage_result["is_effective"], damage_result["is_ineffective"])
	print_rich(message)
	
	# 检查死亡状态
	if target.current_hp <= 0:
		print("%s 被击败!" % target.character_name)
	
	return results

## 根据元素克制关系请求不同的视觉效果
func _request_element_effect(damage_result: Dictionary, target: Node, battle_manager: BattleManager, _hit_params: Dictionary) -> void:
	if damage_result.get("is_effective", false):
		# 克制效果
		#_request_visual_effect(&"effective_hit", target, hit_params)
		# 使用自定义颜色
		_request_visual_effect(&"damage_number", target, battle_manager, {"damage": damage_result["damage"], "color": Color(1.0, 0.7, 0.0), "prefix": "克制! "})
	elif damage_result.get("is_ineffective", false):
		# 抵抗效果
		#_request_visual_effect(&"ineffective_hit", target, hit_params)
		_request_visual_effect(&"damage_number", target, battle_manager, {"damage": damage_result["damage"], "color": Color(0.5, 0.5, 0.5), "prefix": "抵抗 "})
	#else:
		## 普通效果
		#_request_visual_effect(&"damage", target, hit_params)

## 获取伤害信息
func _get_damage_info(target: Node, damage: int, is_effective: bool, is_ineffective: bool) -> String:
	var message = ""
	if is_effective:
		message += "[color=yellow]【克制！】[/color]"
	elif is_ineffective:
		message += "[color=teal]【抵抗！】[/color]"
	
	var character_name = target.get_character_name() if target.has_method("get_character_name") else "未知"
	message += "[color=red]%s 受到 %d 点伤害[/color]" % [character_name, damage]
	return message

## 计算伤害
func _calculate_damage(caster: Node, target: Node) -> Dictionary:
	if not is_instance_valid(caster):
		push_error("DamageEffect: 无效的源节点引用")
		return {
			"success": false,
			"reason": "Invalid source node reference!"
		}
	if not is_instance_valid(target):
		push_error("DamageEffect: 无效的目标节点引用")
		return {
			"success": false,
			"reason": "Invalid target node reference!"
		}

	var caster_skill_component : SkillComponentInterface = caster.get_skill_component() if caster.has_method("get_skill_component") else null
	if not is_instance_valid(caster_skill_component):
		push_error("DamageEffect: 无效的源技能组件引用")
		return {
			"success": false,
			"reason": "Invalid source skill component reference!"
		}
	
	var target_skill_component : SkillComponentInterface = target.get_skill_component() if target.has_method("get_skill_component") else null
	if not is_instance_valid(target_skill_component):
		push_error("DamageEffect: 无效的目标技能组件引用")
		return {
			"success": false,
			"reason": "Invalid target skill component reference!"
		}

	var target_combat_component : CharacterCombatComponent = target.get_combat_component() if target.has_method("get_combat_component") else null
	if not is_instance_valid(target_combat_component):
		push_error("DamageEffect: 无效的目标战斗组件引用")
		return {
			"success": false,
			"reason": "Invalid target combat component reference!"
		}

	var caster_attack_power = caster_skill_component.get_attribute_current_value("AttackPower")
	var caster_defense_power = caster_skill_component.get_attribute_current_value("DefensePower")
	var target_defense_power = target_skill_component.get_attribute_current_value("DefensePower")

	# 基础伤害计算
	var base_damage = damage_amount + (caster_attack_power * damage_power_scale) + (caster_defense_power * defense_power_scale)
	
	# 考虑目标防御
	var damage_after_defense = max(base_damage * MIN_DAMAGE_PERCENT, base_damage - target_defense_power)
	
	# 元素相克系统
	var element_result = _calculate_element_modifier(element, target)
	var element_modifier = element_result["multiplier"]
	
	# 加入随机浮动因素
	var random_factor = 1.0
	if apply_damage_random:
		random_factor = randf_range(1.0 - damage_random_range, 1.0 + damage_random_range)
	
	# 计算最终伤害
	var final_damage = damage_after_defense * element_modifier * random_factor
	
	# 确保伤害至少为1
	final_damage = max(1, round(final_damage))
	
	# 返回详细的伤害结果信息
	return {
		"damage": int(final_damage),
		"base_damage": base_damage,
		"is_effective": element_result["is_effective"],
		"is_ineffective": element_result["is_ineffective"],
		"element_multiplier": element_modifier,
		"skill_element": element,
		"target_element": target_combat_component.element
	}

## 计算元素系数
func _calculate_element_modifier(attack_element: int, target: Node) -> Dictionary:
	var combat_component : CharacterCombatComponent = target.get_combat_component() if target.has_method("get_combat_component") else null
	if not is_instance_valid(combat_component):
		push_error("DamageEffect: 无效的目标战斗组件引用")
		return {
			"success": false,
			"reason": "Invalid target combat component reference!"
		}
	
	# 获取目标元素
	var defense_element = combat_component.element
	
	# 使用ElementTypes计算克制效果
	var multiplier = ElementTypes.get_effectiveness(attack_element, defense_element)
	
	return {
		"multiplier": multiplier,
		"is_effective": multiplier > ElementTypes.NEUTRAL_MULTIPLIER,
		"is_ineffective": multiplier < ElementTypes.NEUTRAL_MULTIPLIER
	}
