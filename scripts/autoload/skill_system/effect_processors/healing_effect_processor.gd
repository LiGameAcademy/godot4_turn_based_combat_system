extends EffectProcessor
class_name HealingEffectProcessor

## 获取处理器ID
func get_processor_id() -> StringName:
	return &"heal"

## 判断是否可以处理该效果
func can_process_effect(effect_data: SkillEffectData) -> bool:
	return effect_data.effect_type == effect_data.EffectType.HEAL

## 处理治疗效果
func process_effect(effect_data: SkillEffectData, execution_context: Dictionary) -> Dictionary:
	var source_character: Character = execution_context.get("source_character")
	var target_character: Character = execution_context.get("primary_target")
	
	# 检查源或目标是否存在
	if not source_character or not target_character:
		push_warning("HealingEffectProcessor: Source or target character is null.")
		return {"success": false, "message": "Source or target missing."}
	var results = {}
	
	# 等待短暂时间
	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame
	
	# 计算治疗量
	var heal_amount = _calculate_healing(source_character, target_character, effect_data)
	
	# 播放治疗效果并生成治疗数字
	_request_visual_effect(&"heal", target_character, {"amount": heal_amount})
	
	# 应用治疗
	target_character.heal(heal_amount)
	
	# 记录结果
	results["heal_amount"] = heal_amount
	
	# 显示治疗信息
	print_rich("[color=green]%s 恢复了 %d 点生命值[/color]" % [target_character.character_name, heal_amount])
	
	return results

## 计算治疗量
func _calculate_healing(caster: Character, _target: Character, effect_data: SkillEffectData) -> int:
	# 基于魔法攻击力计算治疗量
	var base_healing = effect_data.heal_amount + (caster.magic_attack * effect_data.heal_power_scale)
	
	# 加入随机浮动因素 (±15%)
	var random_factor = randf_range(0.85, 1.15)
	
	# 计算最终治疗量
	var final_healing = base_healing * random_factor
	
	# 确保至少治疗1点
	return max(1, round(final_healing))
