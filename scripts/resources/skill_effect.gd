extends Resource
class_name SkillEffect

# 效果类型选项
enum EffectType {
	DAMAGE,
	HEAL,
	APPLY_STATUS,
	CONTROL,
	SPECIAL
}

# 效果基本属性
@export var effect_type: EffectType = EffectType.DAMAGE
@export var power: int = 10
@export var element: SkillData.ElementType = SkillData.ElementType.NONE

# 状态效果相关属性（当效果类型为APPLY_STATUS时使用）
@export_group("状态效果参数", "status_")
@export var status_id: String = ""
@export var status_duration: int = 3
@export var status_chance: float = 1.0  # 0-1之间，表示应用几率

# 控制效果相关属性（当效果类型为CONTROL时使用）
@export_group("控制效果参数", "control_")
@export var control_type: String = "stun"  # stun, silence, etc.
@export var control_duration: int = 1

# 将效果转换为字典格式（用于效果处理器）
func to_dict() -> Dictionary:
	var result = {
		"type": EffectType.keys()[effect_type].to_lower(),
		"params": {
			"power": power,
			"element": element
		}
	}
	
	# 根据效果类型添加额外属性
	match effect_type:
		EffectType.APPLY_STATUS:
			result.params["status_id"] = status_id
			result.params["duration"] = status_duration
			result.params["chance"] = status_chance
		EffectType.CONTROL:
			result.params["control_type"] = control_type
			result.params["duration"] = control_duration
	
	return result
