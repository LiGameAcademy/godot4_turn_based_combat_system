extends SkillEffect
class_name HealEffect

# 治疗效果参数
@export_group("治疗效果参数", "heal_")
@export var heal_amount: int = 10       		## 基础治疗值
@export var heal_power_scale: float = 0.5  		## 魔法攻击力加成系数

## 获取效果描述
func get_description() -> String:
	var amount = heal_amount
	return "恢复 %d 点生命值" % [amount]

## 处理治疗效果
func process_effect(source: Character, target: Character, _context : SkillExecutionContext) -> Dictionary:
	var results = {}
	
	# 播放施法动画
	_request_visual_effect("heal_cast", source, {})
	
	# 等待短暂时间
	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame
	
	# 计算治疗量
	var amount = _calculate_healing(source, target)
	
	# 播放治疗效果
	_request_visual_effect("heal", target, {})
	
	# 生成治疗数字
	_request_visual_effect("damage_number", target, {
		"damage": amount,
		"color": Color(0.3, 1.0, 0.3),
		"prefix": "+"
	})
	
	# 应用治疗
	target.heal(amount)
	
	# 记录结果
	results["heal_amount"] = amount
	
	# 显示治疗信息
	print_rich("[color=green]%s 恢复了 %d 点生命值[/color]" % [target.character_name, amount])
	
	return results

## 计算治疗量
func _calculate_healing(caster: Character, _target: Character) -> int:
	# 基于魔法攻击力计算治疗量
	var base_healing = heal_amount + (caster.magic_attack * heal_power_scale)
	
	# 加入随机浮动因素 (±15%)
	var random_factor = randf_range(0.85, 1.15)
	
	# 计算最终治疗量
	var final_healing = base_healing * random_factor
	
	# 确保至少治疗1点
	return max(1, round(final_healing))
