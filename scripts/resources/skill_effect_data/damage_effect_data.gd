extends SkillEffectData
class_name DamageEffectData

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
func get_description() -> String:
	var amount = damage_amount
	return "造成 %d 点伤害" % [amount]

## 处理伤害效果
func process_effect(source: Character, target: Character, _context : SkillExecutionContext) -> Dictionary:
	var results = {}
	
	# 等待短暂时间
	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame
	
	# 检查目标是否存活
	if target.current_hp <= 0:
		return {}
		
	# 计算伤害
	var damage_result := _calculate_damage(source, target)
	var damage = damage_result["damage"]
	
	# 根据元素克制关系选择不同效果
	_request_element_effect(damage_result, target, {"amount": damage, "element": element})
	
	# 应用伤害
	var actual_damage = target.take_damage(damage)
	
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
func _request_element_effect(damage_result: Dictionary, target: Character, hit_params: Dictionary) -> void:
	if damage_result.get("is_effective", false):
		# 克制效果
		_request_visual_effect(&"effective_hit", target, hit_params)
		# 使用自定义颜色
		_request_visual_effect(&"damage_number", target, {"damage": damage_result["damage"], "color": Color(1.0, 0.7, 0.0), "prefix": "克制! "})
	elif damage_result.get("is_ineffective", false):
		# 抵抗效果
		_request_visual_effect(&"ineffective_hit", target, hit_params)
		_request_visual_effect(&"damage_number", target, {"damage": damage_result["damage"], "color": Color(0.5, 0.5, 0.5), "prefix": "抵抗 "})
	else:
		# 普通效果
		_request_visual_effect(&"damage", target, hit_params)

## 获取伤害信息
func _get_damage_info(target: Character, damage: int, is_effective: bool, is_ineffective: bool) -> String:
	var message = ""
	if is_effective:
		message += "[color=yellow]【克制！】[/color]"
	elif is_ineffective:
		message += "[color=teal]【抵抗！】[/color]"
	
	message += "[color=red]%s 受到 %d 点伤害[/color]" % [target.character_name, damage]
	return message

## 计算伤害
func _calculate_damage(caster: Character, target: Character) -> Dictionary:
	# 获取基础伤害
	var power = damage_amount
	
	# 基础伤害计算
	var base_damage = power + (caster.attack_power * damage_power_scale) + (caster.defense_power * defense_power_scale)
	
	# 考虑目标防御
	var damage_after_defense = max(base_damage * MIN_DAMAGE_PERCENT, base_damage - target.defense_power)
	
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
		"base_damage": damage_after_defense,
		"is_effective": element_result["is_effective"],
		"is_ineffective": element_result["is_ineffective"],
		"element_multiplier": element_modifier,
		"skill_element": element,
		"target_element": target.element
	}

## 计算元素系数
func _calculate_element_modifier(attack_element: int, target: Character) -> Dictionary:
	# 获取目标元素
	var defense_element = target.element
	
	# 使用ElementTypes计算克制效果
	var multiplier = ElementTypes.get_effectiveness(attack_element, defense_element)
	
	return {
		"multiplier": multiplier,
		"is_effective": multiplier > ElementTypes.NEUTRAL_MULTIPLIER,
		"is_ineffective": multiplier < ElementTypes.NEUTRAL_MULTIPLIER
	}
