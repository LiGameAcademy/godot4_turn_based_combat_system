extends EffectProcessor
class_name DamageEffectProcessor

## 获取处理器ID
func get_processor_id() -> StringName:
	return &"damage"

## 检查是否可以处理指定效果类型
func can_process_effect(effect_data: SkillEffectData) -> bool:
	return effect_data.effect_type == effect_data.EffectType.DAMAGE

## 处理伤害效果
func process_effect(effect_data: SkillEffectData, execution_context: Dictionary) -> Dictionary:
	var source_character: Character = execution_context.get("source_character")
	var target_character: Character = execution_context.get("primary_target")

	var results = {}
	
	# 检查源或目标是否存在
	if not source_character or not target_character:
		push_warning("DamageEffectProcessor: Source or target character is null.")
		return {"success": false, "message": "Source or target missing."}

	# 等待短暂时间 (如果需要，可以保留或移除)
	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame
	
	# 检查目标是否存活
	if target_character.current_hp <= 0:
		return {"success": true, "message": "Target already defeated."}
		
	# 1. 计算初始伤害详情
	var initial_damage_details: Dictionary = _calculate_initial_damage_details(source_character, target_character, effect_data)
	
	# 2. 创建 DamageInfo 实例
	# Note: Current _calculate_initial_damage_details doesn't provide is_crit or tags, so passing defaults.
	var damage_info := DamageInfo.new(
		source_character,
		target_character,
		initial_damage_details.get("calculated_damage_value", 0.0),
		initial_damage_details.get("damage_element", ElementTypes.NONE),
		initial_damage_details.get("is_crit", false), # Placeholder
		initial_damage_details.get("tags", [])       # Placeholder
	)
	# Store any other relevant calculation details if needed, e.g., for visuals not directly on DamageInfo
	execution_context["_visual_is_effective"] = initial_damage_details.get("is_effective", false)
	execution_context["_visual_is_ineffective"] = initial_damage_details.get("is_ineffective", false)
	
	# 3. 将 DamageInfo 添加到执行上下文
	execution_context["damage_info"] = damage_info
	
	# 4. 发出事件，允许其他系统修改伤害 (例如状态效果、被动技能)
	# IMPORTANT: SkillSystem.GAME_EVENT.ABOUT_TO_APPLY_DAMAGE needs to be defined in SkillSystem.gd
	if SkillSystem and SkillSystem.GAME_EVENT.has("ABOUT_TO_APPLY_DAMAGE"):
		SkillSystem.emit_signal(SkillSystem.GAME_EVENT.ABOUT_TO_APPLY_DAMAGE, execution_context)
	else:
		push_warning("DamageEffectProcessor: SkillSystem.GAME_EVENT.ABOUT_TO_APPLY_DAMAGE is not defined!")

	# 5. 从上下文中获取可能已修改的 DamageInfo
	var final_damage_info: DamageInfo = execution_context.get("damage_info")
	if not final_damage_info:
		push_error("DamageEffectProcessor: DamageInfo missing from execution_context after event emission.")
		return {"success": false, "message": "DamageInfo lost."}

	# 6. 最终确定伤害值 (例如，确保非负，应用伤害上限/下限等)
	final_damage_info.finalize_damage() # Prevents further modifications
	var damage_to_apply = final_damage_info.get_final_damage()
	
	# 根据元素克制关系选择不同效果 (使用 final_damage_info 和 initial_damage_details for visuals)
	_request_element_effect(final_damage_info, target_character, execution_context.get("_visual_is_effective", false), execution_context.get("_visual_is_ineffective", false))
	
	# 7. 应用伤害
	var actual_damage_taken = target_character.take_damage(damage_to_apply)
	
	# 记录结果
	results["actual_damage_taken"] = actual_damage_taken
	results["damage_info"] = final_damage_info # For logging or other systems
	results["success"] = true
	
	# 显示伤害信息
	var message = _get_damage_display_info(target_character, final_damage_info, execution_context.get("_visual_is_effective", false), execution_context.get("_visual_is_ineffective", false))
	print_rich(message)
	
	# 检查死亡状态
	if target_character.current_hp <= 0:
		print("%s 被击败!" % target_character.character_name)
		results["target_defeated"] = true
	else:
		results["target_defeated"] = false
	
	return results

## 根据元素克制关系请求不同的视觉效果
func _request_element_effect(damage_info: DamageInfo, target: Character, is_effective: bool, is_ineffective: bool) -> void:
	var hit_params = {"amount": damage_info.get_final_damage(), "element": damage_info.damage_element}
	if is_effective:
		# 克制效果
		_request_visual_effect(&"effective_hit", target, hit_params)
		# 使用自定义颜色
		_request_visual_effect(&"damage_number", target, {"damage": damage_info.get_final_damage(), "color": Color(1.0, 0.7, 0.0), "prefix": "克制! "})
	elif is_ineffective:
		# 抵抗效果
		_request_visual_effect(&"ineffective_hit", target, hit_params)
		_request_visual_effect(&"damage_number", target, {"damage": damage_info.get_final_damage(), "color": Color(0.5, 0.5, 0.5), "prefix": "抵抗 "})
	else:
		# 普通效果
		_request_visual_effect(&"damage", target, hit_params)

## 获取伤害显示信息
func _get_damage_display_info(target: Character, damage_info: DamageInfo, is_effective: bool, is_ineffective: bool) -> String:
	var message = ""
	if is_effective:
		message += "[color=yellow]【克制！】[/color]"
	elif is_ineffective:
		message += "[color=teal]【抵抗！】[/color]"
	
	message += "[color=red]%s 受到 %d 点伤害[/color]" % [target.character_name, damage_info.get_final_damage()]
	return message

## 计算初始伤害详情 (供 DamageInfo 构建及初步视觉判断)
func _calculate_initial_damage_details(caster: Character, target: Character, effect_data: SkillEffectData) -> Dictionary:
	# 获取基础伤害
	var power = effect_data.damage_amount
	var element = effect_data.element
	
	# 基础伤害计算 (caster stats based)
	var base_damage_scaled = power + (caster.magic_attack * 0.8) # Example scaling
	
	# 考虑目标防御
	var damage_after_defense = base_damage_scaled - (target.magic_defense * 0.5) # Example defense calc
	
	# 元素相克系统
	var element_result = _calculate_element_modifier(element, target)
	var element_modifier = element_result["multiplier"]
	
	# 加入随机浮动因素 (±10%)
	var random_factor = randf_range(0.9, 1.1)
	
	# 计算最终伤害值 (用于 DamageInfo 的初始 modified_damage_amount)
	var final_calculated_value = damage_after_defense * element_modifier * random_factor
	
	# 确保伤害至少为1 (或者0，取决于游戏设计)
	final_calculated_value = max(1.0, round(final_calculated_value))
	
	# 返回详细的伤害结果信息
	return {
		"calculated_damage_value": float(final_calculated_value), # This will be passed to DamageInfo constructor
		"damage_element": element,
		"is_effective": element_result["is_effective"],
		"is_ineffective": element_result["is_ineffective"],
		# "is_crit": false, # Future: add crit calculation here
		# "tags": [],     # Future: add tags from skill/caster here
		# Informational, not directly for DamageInfo constructor but could be logged or used by other systems
		"base_damage_scaled_pre_defense": base_damage_scaled,
		"element_multiplier": element_modifier,
		"target_element_for_calc": target.element 
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
