extends SkillCondition
class_name TargetHealthCondition

@export_group("条件参数")
@export_range(0.0, 1.0) var below_percent: float = 1.1 	##最大值，默认值大于1，使其失效
@export_range(0.0, 1.0) var above_percent: float = -1 	##最小值， 默认值小于0，使其失效

func is_met(context: Dictionary) -> bool:
	var target: Character = context.get("target")
	if not is_instance_valid(target): 
		push_error("target health condition: target is not valid!")
		return false
	
	var max_hp := target.skill_component.get_attribute_current_value(&"MaxHealth")
	if max_hp == 0: 
		push_error("target health condition: target mx_hp is 0!")
		return false
	
	var current_hp_percent = target.skill_component.get_attribute_current_value(&"CurrentHealth") / max_hp
	
	# 检查“低于”条件
	if below_percent < 1.0 and current_hp_percent >= below_percent:
		return false # 不满足“低于”条件
		
	# 检查“高于”条件
	if above_percent > 0.0 and current_hp_percent <= above_percent:
		return false # 不满足“高于”条件
		
	return true # 所有条件都满足

## 实现 get_description 方法
func get_description() -> String:
	var descriptions: Array[String] = []
	if below_percent < 1.0:
		descriptions.append("目标生命值低于%d%%" % [below_percent * 100])
	if above_percent > 0.0:
		descriptions.append("目标生命值高于%d%%" % [above_percent * 100])
	
	# 用“且”来连接多个条件
	if descriptions.is_empty():
		return ""
	else:
		return "当%s时" % [" 且 ".join(descriptions)]
