@abstract
extends Resource
class_name SkillCondition

## 检查条件是否满足，必须被子类重写。
## context: 一个包含source、target等信息的上下文字典
@abstract func is_met(_context: Dictionary) -> bool
## 获取条件的文本描述。必须被子类重写。
@abstract func get_description() -> String