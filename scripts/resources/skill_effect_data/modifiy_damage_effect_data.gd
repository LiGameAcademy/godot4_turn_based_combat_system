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
func process_effect(source: Character, _target: Character, context: Dictionary = {}) -> Dictionary:
	var results = {}
	
	# 检查传入的上下文中是否有伤害信息
	# 首先检查事件类型
	var event_type = context.get("event_type", "")
	if event_type != &"on_damage_taken" and not context.has("original_event_context"):
		print_rich("[color=orange]ModifyDamageEffectProcessor: 上下文中没有伤害事件信息[/color]")
		return {"success": false, "error": "上下文中没有伤害事件信息"}
	
	# 如果是状态触发的效果，使用原始事件上下文
	var damage_context = context
	if context.has("original_event_context"):
		damage_context = context["original_event_context"]
	
	# 检查伤害信息
	if not damage_context.has("damage_info"):
		print_rich("[color=red]ModifyDamageEffectProcessor: 上下文中缺少伤害信息对象[/color]")
		return {"success": false, "error": "上下文中缺少伤害信息对象"}
	
	# 获取伤害信息对象
	var damage_info = damage_context["damage_info"]
	
	# 检查伤害是否可以被修改
	if not damage_info.get("can_be_modified", true):
		return {"success": false, "error": "伤害不可修改"}
	
	# 记录修改前的伤害值
	var damage_before = damage_info["damage_value"]
	
	# 应用百分比修改
	var modified_damage = damage_before * damage_mod_percent
	
	# 应用固定值修改
	modified_damage += damage_mod_flat
	
	# 确保伤害在最小和最大值之间
	modified_damage = clamp(modified_damage, damage_mod_min, damage_mod_max)
	
	# 更新伤害信息对象
	damage_info["damage_value"] = modified_damage
	
	# 记录修改日志
	var modification = {
		"modifier": "防御状态",
		"type": "百分比修改",
		"before": damage_before,
		"after": modified_damage
	}
	
	# 添加到修改日志
	if damage_info.has("modifications"):
		damage_info["modifications"].append(modification)
	
	# 打印修改信息
	print_rich("[color=cyan]伤害修改: %.1f -> %.1f (修改器: %s, 百分比: %.2f)[/color]" % 
		[damage_before, modified_damage, source.character_name, damage_mod_percent])
	
	# 返回结果
	results["success"] = true
	results["original_damage"] = damage_before
	results["modified_damage"] = modified_damage
	
	return results
