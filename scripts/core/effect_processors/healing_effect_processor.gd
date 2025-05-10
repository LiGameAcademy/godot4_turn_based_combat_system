extends EffectProcessor
class_name HealingEffectProcessor

## 获取处理器ID
func get_processor_id() -> String:
	return "heal"

## 处理治疗效果
func process_effect(effect_data: Dictionary, caster: Character, targets: Array) -> Dictionary:
	var results = {}
	
	# 播放施法动画
	request_visual_effect("heal_cast", caster)
	
	# 等待短暂时间
	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame
		await Engine.get_main_loop().create_timer(0.3).timeout
	
	for target in targets:
		if target.current_hp <= 0:  # 不能治疗已死亡的角色
			print("%s 已倒下，无法接受治疗。" % target.character_name)
			continue
		
		# 计算治疗量
		var healing = calculate_healing(caster, target, effect_data)
		
		# 播放治疗效果动画
		request_visual_effect("heal", target)
		
		# 应用治疗
		var actual_healed = target.heal(healing)
		
		# 显示治疗数字
		spawn_damage_number(target.global_position, actual_healed, Color.GREEN)
		
		# 发出角色状态变化信号
		if battle_manager and battle_manager.has_signal("character_stats_changed"):
			battle_manager.character_stats_changed.emit(target)
		
		# 记录结果
		if not results.has(target):
			results[target] = {}
		results[target]["heal"] = actual_healed
		
		print_rich("[color=green]%s 恢复了 %d 点生命值！[/color]" % [target.character_name, actual_healed])
	
	return results

## 计算治疗量
func calculate_healing(caster: Character, target: Character, effect_data: Dictionary) -> int:
	# 获取基础治疗量
	var power = effect_data.get("power", 10)
	
	# 治疗量通常更依赖施法者的魔法攻击力
	var base_healing = power + (caster.magic_attack * 1.0)
	
	# 随机浮动 (±5%)
	var random_factor = randf_range(0.95, 1.05)
	var final_healing = base_healing * random_factor
	
	return max(1, round(final_healing))

## 获取效果描述
func get_effect_description(effect_data: Dictionary) -> String:
	var power = effect_data.get("power", 10)
	return "恢复 %d 点生命值" % power 