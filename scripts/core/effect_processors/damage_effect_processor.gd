extends EffectProcessor
class_name DamageEffectProcessor

## 获取处理器ID
func get_processor_id() -> String:
	return "damage"

## 处理伤害效果
func process_effect(effect_data: Dictionary, caster: Character, targets: Array) -> Dictionary:
	var results = {}
	
	# 播放施法动画
	request_visual_effect("cast", caster, {"element": effect_data.get("element", 0)})
	
	# 等待短暂时间
	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame
	
	for target in targets:
		if target.current_hp <= 0:
			continue
			
		# 计算伤害
		var damage = calculate_damage(caster, target, effect_data)
		
		# 播放命中动画
		request_visual_effect("hit", target, {"element": effect_data.get("element", 0)})
		
		# 应用伤害
		var actual_damage = target.take_damage(damage)
		
		# 生成伤害数字
		spawn_damage_number(target.global_position, actual_damage, Color.RED)
		
		# 角色状态变化信号
		if battle_manager and battle_manager.has_signal("character_stats_changed"):
			battle_manager.character_stats_changed.emit(target)
		
		# 记录结果
		if not results.has(target):
			results[target] = {}
		results[target]["damage"] = actual_damage
		
		print_rich("[color=red]%s 受到 %d 点伤害[/color]" % [target.character_name, actual_damage])
	
	return results
	
## 计算伤害
func calculate_damage(caster: Character, target: Character, effect_data: Dictionary) -> int:
	# 获取基础伤害
	var power = effect_data.get("power", 10)
	var element = effect_data.get("element", 0)
	
	# 基础伤害计算
	var base_damage = power + (caster.magic_attack * 0.8)
	
	# 考虑目标防御
	var damage_after_defense = base_damage - (target.magic_defense * 0.5)
	
	# 元素相克系统 (预留给第7章)
	var element_modifier = calculate_element_modifier(element, target)
	
	# 加入随机浮动因素 (±10%)
	var random_factor = randf_range(0.9, 1.1)
	
	# 计算最终伤害
	var final_damage = damage_after_defense * element_modifier * random_factor
	
	# 确保伤害至少为1
	return max(1, round(final_damage))

## 计算元素系数 (预留给第7章实现)
func calculate_element_modifier(attack_element: int, target: Character) -> float:
	# 未来将根据攻击元素和目标元素计算相克系数
	# 暂时返回1.0 (无修正)
	return 1.0

## 获取效果描述
func get_effect_description(effect_data: Dictionary) -> String:
	var power = effect_data.get("power", 10)
	return "造成 %d 点伤害" % power
