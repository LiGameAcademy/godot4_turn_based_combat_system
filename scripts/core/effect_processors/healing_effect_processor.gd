extends EffectProcessor
class_name HealingEffectProcessor

## 获取处理器ID
func get_processor_id() -> StringName:
	return "heal"

## 判断是否可以处理该效果
func can_process(effect: SkillEffectData) -> bool:
	return effect.effect_type == effect.SkillEffectType.HEAL

## 处理治疗效果
func process_effect(effect: SkillEffectData, source: Character, target: Character) -> Dictionary:
	var results = {}
	
	# 播放施法动画
	_request_visual_effect("heal_cast", source, {})
	
	# 等待短暂时间
	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame
	
	# 计算治疗量
	var heal_amount = _calculate_healing(source, target, effect)
	
	# 播放治疗效果
	_request_visual_effect("heal", target, {})
	
	# 生成治疗数字
	_request_visual_effect("damage_number", target, {
		"damage": heal_amount,
		"color": Color(0.3, 1.0, 0.3),
		"prefix": "+"
	})
	
	# 应用治疗
	target.heal(heal_amount)
	
	# 角色状态变化信号
	var battle_mgr = _get_battle_manager()
	if battle_mgr and battle_mgr.has_signal("character_stats_changed"):
		battle_mgr.character_stats_changed.emit(target)
	
	# 记录结果
	results["heal_amount"] = heal_amount
	
	# 显示治疗信息
	print_rich("[color=green]%s 恢复了 %d 点生命值[/color]" % [target.character_name, heal_amount])
	
	return results

## 计算治疗量
func _calculate_healing(caster: Character, _target: Character, effect: SkillEffectData) -> int:
	# 获取基础治疗量
	var power = effect.power
	
	# 基于魔法攻击力计算治疗量
	var base_healing = power + (caster.magic_attack * 0.7)
	
	# 加入随机浮动因素 (±15%)
	var random_factor = randf_range(0.85, 1.15)
	
	# 计算最终治疗量
	var final_healing = base_healing * random_factor
	
	# 确保至少治疗1点
	return max(1, round(final_healing))
