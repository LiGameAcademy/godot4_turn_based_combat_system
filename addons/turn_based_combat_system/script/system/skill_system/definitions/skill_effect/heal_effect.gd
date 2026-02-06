extends SkillEffect
class_name HealEffect

# 治疗效果参数
@export_group("治疗效果参数", "heal_")
@export var heal_amount: int = 10       		## 基础治疗值
@export var heal_power_scale: float = 0.5  		## 魔法攻击力加成系数

## 获取效果描述
func _get_base_description() -> String:
	var amount = heal_amount
	return "恢复 %d 点生命值" % [amount]

## 处理治疗效果
func _process_effect(source: Node, target: Node, _context : SkillExecutionContext) -> Dictionary:
	var results = {}
	if not is_instance_valid(source):
		push_error("HealEffect: 无效的源节点引用")
		return {
			"success": false,
			"reason": "Invalid source node reference!"
		}
	if not is_instance_valid(target):
		push_error("HealEffect: 无效的目标节点引用")
		return {
			"success": false,
			"reason": "Invalid target node reference!"
		}

	var target_combat_component : CharacterCombatComponent = target.get_combat_component() if target.has_method("get_combat_component") else null
	if not is_instance_valid(target_combat_component):
		push_error("HealEffect: 无效的目标战斗组件引用")
		return {
			"success": false,
			"reason": "Invalid target combat component reference!"
		}

	# 播放施法动画
	_request_visual_effect("heal_cast", source, _context.battle_manager, {})
	
	# 计算治疗量
	var amount = _calculate_healing(source, target)
	
	# 播放治疗效果
	_request_visual_effect("heal", target, _context.battle_manager, {})
	
	# 生成治疗数字
	_request_visual_effect("damage_number", target, _context.battle_manager, {
		"damage": amount,
		"color": Color(0.3, 1.0, 0.3),
		"prefix": "+"
	})
	
	# 应用治疗
	target_combat_component.heal(amount, source)
	
	# 记录结果
	results["heal_amount"] = amount
	
	# 显示治疗信息
	print_rich("[color=green]%s 恢复了 %d 点生命值[/color]" % [target.character_name, amount])
	
	return results

## 计算治疗量
func _calculate_healing(caster: Node, _target: Node) -> int:
	var caster_skill_component : SkillComponentInterface = caster.get_skill_component() if caster.has_method("get_skill_component") else null
	if not is_instance_valid(caster_skill_component):
		push_error("HealEffect: 无效的源技能组件引用")
		return 0
	
	var caster_attack_power = caster_skill_component.get_attribute_current_value("AttackPower")

	# 基于魔法攻击力计算治疗量
	var base_healing = heal_amount + (caster_attack_power * heal_power_scale)
	
	# 加入随机浮动因素 (±15%)
	var random_factor = randf_range(0.85, 1.15)
	
	# 计算最终治疗量
	var final_healing = base_healing * random_factor
	
	# 确保至少治疗1点
	return max(1, round(final_healing))
