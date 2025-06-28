extends EffectProcessor
class_name DamageEffectProcessor

## 获取处理器ID
func get_processor_id() -> StringName:
	return "damage"

## 检查是否可以处理指定效果类型
func can_process_effect(effect: SkillEffectData) -> bool:
	return effect.effect_type == effect.EffectType.DAMAGE

## 处理伤害效果
func process_effect(effect: SkillEffectData, caster: Character, target: Character) -> Dictionary:
	var results = {}
	
	# 播放施法动画
	_request_visual_effect("cast", caster, {})
	
	# 等待短暂时间
	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame
	
	# 检查目标是否存活
	if target.current_hp <= 0:
		return {}
		
	# 计算伤害
	var damage_result = _calculate_damage(caster, target, effect)
	var damage = damage_result["damage"]
	
	# 播放命中动画，根据克制关系选择不同效果
	#var hit_params = {"element": effect.damage_element}
	var hit_params = {}
	# 普通效果
	_request_visual_effect("hit", target, hit_params)
	_request_visual_effect("damage_number", target, {"damage": damage, "color": Color.RED})
	
	# 应用伤害
	var actual_damage = target.take_damage(damage)
	
	# 记录结果
	results["damage"] = actual_damage
	
	# 显示伤害信息
	var message = ""
	message += "[color=red]%s 受到 %d 点伤害[/color]" % [target.character_name, actual_damage]
	print_rich(message)
	
	# 检查死亡状态
	if target.current_hp <= 0:
		print("%s 被击败!" % target.character_name)
	
	return results

## 计算伤害
func _calculate_damage(caster: Character, target: Character, effect: SkillEffectData) -> Dictionary:
	# 获取基础伤害
	var power = effect.damage_amount
	
	# 基础伤害计算
	var base_damage = power + (caster.magic_attack * 0.8)
	
	# 考虑目标防御
	var damage_after_defense = base_damage - (target.magic_defense * 0.5)
	
	# 加入随机浮动因素 (±10%)
	var random_factor = randf_range(0.9, 1.1)
	
	# 计算最终伤害
	var final_damage = damage_after_defense * random_factor
	
	# 确保伤害至少为1
	final_damage = max(1, round(final_damage))
	
	# 返回详细的伤害结果信息
	return {
		"damage": int(final_damage),
		"base_damage": damage_after_defense,
	}

## 计算技能伤害
#func _calculate_skill_damage(caster: Character, target: Character, skill: SkillData) -> int:
	## 基础伤害计算
	#var base_damage = skill.power
	#
	## 根据技能类型添加不同的属性加成
	#if skill.damage_type == "physical":
		#base_damage += caster.physical_attack * 1.5
	#else: # 魔法伤害
		#base_damage += caster.magic_attack * 1.5
	#
	## 考虑目标防御
	#var defense = skill.damage_type == "physical" ? target.physical_defense : target.magic_defense
	#var damage_reduction = defense / (defense + 100.0)
	#
	## 应用伤害减免
	#var reduced_damage = base_damage * (1.0 - damage_reduction)
	#
	## 随机浮动 (±10%)
	#var random_factor = randf_range(0.9, 1.1)
	#var final_damage = reduced_damage * random_factor
	#
	#return max(1, round(final_damage))
