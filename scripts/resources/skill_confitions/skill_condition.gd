extends Resource
class_name SkillCondition

## 检查条件是否满足，必须被子类重写。
## context: 一个包含source、target等信息的上下文字典
func is_met(context: Dictionary) -> bool:
	push_error("SkillCondition.is_met() 方法必须被子类重写！")
	return true

## 获取条件的文本描述。必须被子类重写。
func get_description() -> String:
	return "未知条件"
