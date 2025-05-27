extends Resource
class_name SkillEffectData

# 效果类型枚举
enum EffectType {
	DAMAGE,            		## 伤害
	HEAL,              		## 治疗
	STATUS,           		## 控制
	DISPEL,            		## 驱散
	MODIFY_DAMAGE_EVENT,  	## 伤害事件修改
	SPECIAL            		## 特殊效果
}

## 伤害修改类型枚举 (用于 MODIFY_DAMAGE_EVENT)
enum DamageModificationType {
	NONE,                           ## 无修改
	MODIFICATION_FLAT,              ## 固定值修改 (正数为增伤, 负数为减伤)
	MODIFICATION_PERCENT,           ## 百分比修改 (正数为增伤, 负数为减伤, e.g., 0.1 for +10%, -0.1 for -10%)
	ABSORPTION_FLAT,                ## 固定值吸收 (伤害转化为对自己的治疗, value应为正)
	ABSORPTION_PERCENT,             ## 百分比吸收 (伤害转化为对自己的治疗, value应为正, e.g., 0.1 for 10%)
	CONVERT_DAMAGE_TYPE,            ## 转换伤害类型 (使用 mod_dmg_new_damage_type)
	SET_DAMAGE_FLAT,                ## 直接设置最终伤害值 (覆盖之前所有计算)
	REFLECT_DAMAGE_PERCENT          ## 反弹伤害百分比 (例如 value=0.2 表示反弹20%的原始伤害给攻击者, value应为正)
}

# 基本属性
@export var effect_type: EffectType = EffectType.DAMAGE
## 元素属性
@export_enum("none", "fire", "water", "earth", "light")
var element: int = 0 # ElementTypes.Element.NONE 
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

## 应用效果参数
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

## 伤害事件修改参数 (仅当 effect_type == MODIFY_DAMAGE_EVENT 时有效)
@export_group("伤害事件修改参数", "mod_dmg_")
@export var mod_dmg_event_type: DamageModificationType = DamageModificationType.NONE
## 当修改类型为固定值时，表示增加/减少的具体数值；当为百分比时，0.1表示10%
@export var mod_dmg_value: float = 10.0
## 新的伤害类型 (用于 CONVERT_DAMAGE_TYPE)
@export_enum("none", "fire", "water", "earth", "light")
var mod_dmg_new_damage_type: int = 0 # ElementTypes.Element.NONE 
## 反弹目标是否为伤害来源 (用于 REFLECT_DAMAGE_PERCENT)
@export var mod_dmg_reflect_target_is_source: bool = true 

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
		EffectType.MODIFY_DAMAGE_EVENT:
			return _get_modify_damage_event_description()
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

## 获取伤害事件修改效果描述
func _get_modify_damage_event_description() -> String:
	var desc = "伤害事件修改: "
	match mod_dmg_event_type:
		DamageModificationType.NONE:
			desc += "无效果"
		DamageModificationType.MODIFICATION_FLAT:
			if mod_dmg_value >= 0:
				desc += "固定增伤 %s 点" % str(mod_dmg_value)
			else:
				desc += "固定减伤 %s 点" % str(abs(mod_dmg_value))
		DamageModificationType.MODIFICATION_PERCENT:
			if mod_dmg_value >= 0:
				desc += "百分比增伤 %s%%" % str(mod_dmg_value * 100)
			else:
				desc += "百分比减伤 %s%%" % str(abs(mod_dmg_value) * 100)
		DamageModificationType.ABSORPTION_FLAT:
			desc += "固定吸收伤害 %s 点并转化为治疗" % str(mod_dmg_value)
		DamageModificationType.ABSORPTION_PERCENT:
			desc += "百分比吸收伤害 %s%% 并转化为治疗" % str(mod_dmg_value * 100)
		DamageModificationType.CONVERT_DAMAGE_TYPE:
			# TODO: Get element name from mod_dmg_new_damage_type
			desc += "转换伤害类型为 %s" % "[元素名称]" # Placeholder
		DamageModificationType.SET_DAMAGE_FLAT:
			desc += "直接设置伤害值为 %s" % str(mod_dmg_value)
		DamageModificationType.REFLECT_DAMAGE_PERCENT:
			desc += "反弹 %s%% 伤害" % str(mod_dmg_value * 100)
		_:
			desc += "未知修改类型"
	return desc

## 获取特殊效果描述
func _get_special_description() -> String:
	var special_type_value = special_type
	
	match special_type_value:
		"revive": return "复活目标"
		"teleport": return "传送目标"
		"summon": return "召唤生物"
		_: return "特殊效果: " + special_type_value 
