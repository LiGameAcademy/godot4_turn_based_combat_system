extends SkillCondition
class_name ProbabilityCondition

## 触发这个条件的概率，0.0代表0%，1.0代表100%
@export_range(0.0, 1.0) var chance: float = 0.5

## 检查条件是否满足
## 每次调用时，都会进行一次随机判定
func is_met(_context: Dictionary) -> bool:
    return randf() < chance

## 获取条件的文本描述
func get_description() -> String:
    return "%d%%几率" % [int(chance * 100)]