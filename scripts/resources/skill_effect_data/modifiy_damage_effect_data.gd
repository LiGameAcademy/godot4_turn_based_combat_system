extends SkillEffectData
class_name ModifyDamageEffectData

## 修改伤害参数
@export_group("修改伤害参数", "damage_mod_")
@export var damage_mod_percent: float = 0.5  		## 伤害修改百分比（0.5表示减少一半）
@export var damage_mod_flat: float = 0.0     		## 伤害修改固定值（在百分比之后再加减）
@export var damage_mod_min: float = 1.0      		## 修改后的最小伤害值
@export var damage_mod_max: float = 9999.0   		## 修改后的最大伤害值

## 获取修改伤害描述
func get_description() -> String:
	var percent = damage_mod_percent
	var flat = damage_mod_flat
	var _min = damage_mod_min
	var _max = damage_mod_max
	return "修改伤害: %s * %s + %s (范围: %s - %s)" % [percent, flat, _min, _max]

## 处理修改伤害效果
## 这个处理器不直接应用伤害，而是修改传入的伤害信息对象
func process_effect(_source: Character, _target: Character, context : SkillExecutionContext) -> Dictionary:
	var results = {}
	
	# 检查伤害信息
	if not context.damage_info:
		print_rich("[color=red]ModifyDamageEffectProcessor: 上下文中缺少伤害信息对象[/color]")
		return {"success": false, "error": "上下文中缺少伤害信息对象"}
	
	# 获取伤害信息对象
	var damage_info : DamageInfo = context.damage_info
	
	# 检查伤害是否可以被修改
	if not damage_info.can_be_modified:
		return {"success": false, "error": "伤害不可修改"}
	
	var original_damage = damage_info.final_damage

	# 应用百分比修改
	if damage_mod_percent != 0:
		damage_info.modify_damage("percent", damage_mod_percent, damage_mod_min, damage_mod_max)
	
	# 应用固定值修改
	if damage_mod_flat !=0:
		damage_info.modify_damage("flat", damage_mod_flat, damage_mod_min, damage_mod_max)
	
	# 返回结果
	results["success"] = true
	results["original_damage"] = original_damage
	results["modified_damage"] = damage_info.final_damage
	
	return results
