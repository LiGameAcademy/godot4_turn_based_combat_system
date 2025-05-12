extends EffectProcessor
class_name DamageEffectProcessor

## 获取处理器ID
func get_processor_id() -> String:
	return "damage"

## 处理伤害效果
func process_effect(effect: SkillEffect, caster: Character, targets: Array) -> Dictionary:
	var results = {}
	
	# 播放施法动画
	request_visual_effect("cast", caster, {"element": effect.element})
	
	# 等待短暂时间
	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame
	
	for target in targets:
		if target.current_hp <= 0:
			continue
			
		# 计算伤害
		var damage_result = calculate_damage(caster, target, effect)
		var damage = damage_result["damage"]
		
		# 播放命中动画，根据克制关系选择不同效果
		var hit_params = {"element": effect.element}
		
		if damage_result["is_effective"]:
			# 克制效果
			request_visual_effect("effective_hit", target, hit_params)
			# 使用自定义颜色和前缀
			request_visual_effect("damage_number", target, {"damage": damage, "color": Color(1.0, 0.7, 0.0), "prefix": "克制! "})
		elif damage_result["is_ineffective"]:
			# 抵抗效果
			request_visual_effect("ineffective_hit", target, hit_params)
			request_visual_effect("damage_number", target, {"damage": damage, "color": Color(0.5, 0.5, 0.5), "prefix": "抵抗 "})
		else:
			# 普通效果
			request_visual_effect("hit", target, hit_params)
			request_visual_effect("damage_number", target, {"damage": damage, "color": Color.RED})
		
		# 应用伤害
		var actual_damage = target.take_damage(damage)
		
		# 角色状态变化信号
		if battle_manager and battle_manager.has_signal("character_stats_changed"):
			battle_manager.character_stats_changed.emit(target)
		
		# 记录结果
		if not results.has(target):
			results[target] = {}
		results[target]["damage"] = actual_damage
		
		# 显示伤害信息
		var message = ""
		if damage_result["is_effective"]:
			message += "[color=yellow]【克制！】[/color]"
		elif damage_result["is_ineffective"]:
			message += "[color=teal]【抵抗！】[/color]"
		
		message += "[color=red]%s 受到 %d 点伤害[/color]" % [target.character_name, actual_damage]
		print_rich(message)
		
		# 检查死亡状态
		if target.current_hp <= 0:
			print("%s 被击败!" % target.character_name)
	
	return results

## 计算伤害
func calculate_damage(caster: Character, target: Character, effect: SkillEffect) -> Dictionary:
	# 获取基础伤害
	var power = effect.power
	var element = effect.element
	
	# 基础伤害计算
	var base_damage = power + (caster.magic_attack * 0.8)
	
	# 考虑目标防御
	var damage_after_defense = base_damage - (target.magic_defense * 0.5)
	
	# 元素相克系统
	var element_result = calculate_element_modifier(element, target)
	var element_modifier = element_result["multiplier"]
	
	# 加入随机浮动因素 (±10%)
	var random_factor = randf_range(0.9, 1.1)
	
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
func calculate_element_modifier(attack_element: int, target: Character) -> Dictionary:
	# 获取目标元素
	var defense_element = target.element
	
	# 使用ElementTypes计算克制效果
	var multiplier = ElementTypes.get_effectiveness(attack_element, defense_element)
	
	return {
		"multiplier": multiplier,
		"is_effective": multiplier > ElementTypes.NEUTRAL_MULTIPLIER,
		"is_ineffective": multiplier < ElementTypes.NEUTRAL_MULTIPLIER
	}

## 获取效果描述
func get_effect_description(effect: SkillEffect) -> String:
	var power = effect.power
	var element_name = ""
	
	if effect.element > 0:
		element_name = ElementTypes.get_element_name(effect.element)
		return "造成 %d 点%s属性伤害" % [power, element_name]
	else:
		return "造成 %d 点伤害" % power
