extends Resource
class_name SkillEffect

# 效果类型
enum EffectType {
	DAMAGE,   # 伤害效果
	HEAL,     # 治疗效果
	APPLY_STATUS, # 状态效果 (未实现)
	CONTROL,  # 控制效果 (未实现)
}

# 导出属性
@export var effect_type : EffectType = EffectType.DAMAGE
@export var power : int = 10  # 基础威力
@export var element : int = 0 # 元素属性

# 状态效果参数
@export var status_id : String = ""  # 状态ID
@export var status_duration : int = 3  # 持续回合
@export var status_chance : float = 1.0  # 触发几率 (0.0-1.0)

# 控制效果参数
@export var control_type : String = "stun" # 控制类型
@export var control_duration : int = 1  # 持续回合
