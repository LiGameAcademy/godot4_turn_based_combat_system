extends SkillEffect
class_name SpecialEffect

## 特殊效果参数
@export_group("特殊效果参数", "special_")
@export var special_type: String = "none"  		## 特殊效果类型
@export var special_params: Dictionary = {}   	## 特殊效果参数

## 获取特殊效果描述
func get_description() -> String:
	var special_type_value = special_type
	
	match special_type_value:
		"revive": return "复活目标"
		"teleport": return "传送目标"
		"summon": return "召唤生物"
		_: return "特殊效果: " + special_type_value 
