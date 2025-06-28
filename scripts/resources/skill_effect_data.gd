extends Resource
class_name SkillEffectData

# 效果类型枚举
enum EffectType {
	DAMAGE,            		## 伤害
	HEAL,              		## 治疗
	STATUS,           		## 控制
	DISPEL,            		## 驱散
	SPECIAL            		## 特殊效果
}

# 基本属性
@export var effect_type: EffectType = EffectType.DAMAGE
@export var visual_effect: String = ""  		## 视觉效果标识符
@export var sound_effect: String = ""   		## 音效标识符

# 伤害效果参数
@export_group("伤害效果参数", "damage_")
@export var damage_amount: int = 10     		## 基础伤害值
@export var damage_power_scale: float = 1.0  	## 攻击力加成系数

# 治疗效果参数
@export_group("治疗效果参数", "heal_")
@export var heal_amount: int = 10       		## 基础治疗值
@export var heal_power_scale: float = 0.5  		## 魔法攻击力加成系数

## 应用状态效果参数
@export_group("应用效果参数", "status_")
@export var status_to_apply: SkillStatusData = null	  							## 状态模版
@export var status_application_chance: float = 1.0  							## 触发几率 (0.0-1.0)
@export var status_duration_override : int = -1									## 持续时间覆盖
@export var status_stacks_to_apply : int = 1									## 堆叠层数

# 驱散效果参数
@export_group("驱散效果参数", "dispel_")
@export var dispel_types: Array[String] = []  	## 驱散的状态类型
@export var dispel_count: int = 1       		## 驱散数量
@export var dispel_is_positive: bool = false  	## 是否驱散正面效果
@export var dispel_is_all: bool = false        	## 是否全部驱散

## 特殊效果参数
@export_group("特殊效果参数", "special_")
@export var special_type: String = "none"  		## 特殊效果类型
@export var special_params: Dictionary = {}   	## 特殊效果参数

## 获取效果描述
func get_description() -> String:
	match effect_type:
		EffectType.DAMAGE:
			return _get_damage_description()
		EffectType.HEAL:
			return _get_heal_description()
		EffectType.STATUS:
			return _get_status_description()
		EffectType.DISPEL:
			return _get_dispel_description()
		EffectType.SPECIAL:
			return _get_special_description()
		_:
			return "未知效果"

## 获取伤害效果描述
func _get_damage_description() -> String:
	var amount = damage_amount
	return "造成 %d 点伤害" % [amount]

## 获取治疗效果描述
func _get_heal_description() -> String:
	var amount = heal_amount
	return "恢复 %d 点生命值" % [amount]

## 获取状态效果描述
func _get_status_description() -> String:
	var duration = status_to_apply.duration
	if status_application_chance < 1.0:
		return "%s目标 %d 回合 (%.1f%%几率)" % [status_to_apply.status_name, duration, status_application_chance * 100]
	return "%s目标 %d 回合" % [status_to_apply.status_name, duration]

## 获取驱散效果描述
func _get_dispel_description() -> String:
	var count = dispel_count
	var is_positive = dispel_is_positive
	var type_name = "增益" if is_positive else "减益"
	return "驱散 %d 个%s效果" % [count, type_name]

## 获取特殊效果描述
func _get_special_description() -> String:
	var special_type_value = special_type
	
	match special_type_value:
		"revive": return "复活目标"
		"teleport": return "传送目标"
		"summon": return "召唤生物"
		_: return "特殊效果: " + special_type_value 
