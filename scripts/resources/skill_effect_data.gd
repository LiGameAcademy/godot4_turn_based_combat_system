extends Resource
class_name SkillEffectData

## 效果类型枚举
enum EffectType {
	ATTRIBUTE_MODIFY,  # 属性修改
	DAMAGE,            # 伤害
	HEAL,              # 治疗
	CONTROL,           # 控制
	DISPEL,            # 驱散
	SPECIAL            # 特殊效果
}

## 基本属性
@export var effect_type: EffectType = EffectType.ATTRIBUTE_MODIFY
@export var visual_effect: String = ""  # 视觉效果标识符
@export var sound_effect: String = ""   # 音效标识符

## 伤害效果参数
@export_group("伤害效果参数", "damage_")
@export var damage_amount: int = 10     # 基础伤害值
@export var damage_element: int = 0     # 元素类型
@export var damage_power_scale: float = 1.0  # 攻击力加成系数
@export var damage_is_dot: bool = false  # 是否为持续伤害效果

## 治疗效果参数
@export_group("治疗效果参数", "heal_")
@export var heal_amount: int = 10       # 基础治疗值
@export var heal_power_scale: float = 0.5  # 魔法攻击力加成系数
@export var heal_is_hot: bool = false   # 是否为持续治疗效果

## 属性修改参数
@export_group("属性修改参数", "attr_")
@export var attr_target: String = "attack"  # 目标属性
@export var attr_value: float = 0       # 修改值
@export var attr_is_percent: bool = false  # 是否为百分比修改
@export var attr_duration: int = 0      # 持续回合

## 控制效果参数
@export_group("控制效果参数", "control_")
@export var control_type: String = "stun"  # 控制类型
@export var control_duration: int = 1    # 持续回合

## 驱散效果参数
@export_group("驱散效果参数", "dispel_")
@export var dispel_types: Array[String] = []  # 驱散的状态类型
@export var dispel_count: int = 1       # 驱散数量
@export var dispel_is_positive: bool = false  # 是否驱散正面效果

## 特殊效果参数
@export_group("特殊效果参数", "special_")
@export var special_type: String = "none"  # 特殊效果类型
@export var special_params: Dictionary = {}  # 特殊效果参数

## 旧版兼容参数
@export_group("兼容参数")
@export var power: int = 10  # 基础威力
@export var element: int = 0 # 元素属性
@export var status_id: String = ""  # 状态ID
@export var status_duration: int = 3  # 持续回合
@export var status_chance: float = 1.0  # 触发几率 (0.0-1.0)

## 获取效果描述
func get_description() -> String:
	match effect_type:
		EffectType.ATTRIBUTE_MODIFY:
			return _get_attribute_modify_description()
		EffectType.DAMAGE:
			return _get_damage_description()
		EffectType.HEAL:
			return _get_heal_description()
		EffectType.CONTROL:
			return _get_control_description()
		EffectType.DISPEL:
			return _get_dispel_description()
		EffectType.SPECIAL:
			return _get_special_description()
		_:
			return "未知效果"

## 应用效果的接口方法
func apply(source: Character, target: Character) -> Dictionary:
	var result = {}
	
	match effect_type:
		EffectType.ATTRIBUTE_MODIFY:
			result = _apply_attribute_modify(source, target)
		EffectType.DAMAGE:
			result = _apply_damage(source, target)
		EffectType.HEAL:
			result = _apply_heal(source, target)
		EffectType.CONTROL:
			result = _apply_control(source, target)
		EffectType.DISPEL:
			result = _apply_dispel(source, target)
		EffectType.SPECIAL:
			result = _apply_special(source, target)
	
	if visual_effect != "":
		_trigger_visual_effect(target)
	
	if sound_effect != "":
		_trigger_sound_effect(target)
	
	return result

## 属性修改效果
func _apply_attribute_modify(_source: Character, _target: Character) -> Dictionary:
	# 这里使用明确的属性而不是params字典
	var attr = attr_target
	var value = attr_value
	var is_percent = attr_is_percent
	var duration = attr_duration
	
	# 这里仅返回结果，实际修改由Status或直接调用Character方法
	return {
		"type": "attribute_modify",
		"attribute": attr,
		"value": value,
		"is_percent": is_percent,
		"duration": duration
	}

## 伤害效果
func _apply_damage(source: Character, target: Character) -> Dictionary:
	# 使用专用属性
	var amount = damage_amount if damage_amount > 0 else power
	var element_type = damage_element if damage_element > 0 else element
	
	# 考虑攻击力加成
	var power_scale = damage_power_scale
	amount += int(source.magic_attack * power_scale)
	
	# 考虑元素相克
	if "ElementTypes" in Engine.get_singleton_list():
		var multiplier = ElementTypes.get_effectiveness(element_type, target.element)
		amount = int(amount * multiplier)
	
	# 应用伤害
	var actual_damage = target.take_damage(amount)
	
	return {
		"type": "damage",
		"amount": actual_damage,
		"element": element_type,
		"is_dot": damage_is_dot
	}

## 治疗效果
func _apply_heal(source: Character, target: Character) -> Dictionary:
	# 使用专用属性
	var amount = heal_amount if heal_amount > 0 else power
	
	# 考虑治疗力加成
	var power_scale = heal_power_scale
	amount += int(source.magic_attack * power_scale)
	
	# 应用治疗
	var actual_heal = target.heal(amount)
	
	return {
		"type": "heal",
		"amount": actual_heal,
		"is_hot": heal_is_hot
	}

## 控制效果
func _apply_control(_source: Character, target: Character) -> Dictionary:
	# 使用专用属性
	var control_type_value = control_type
	var duration = control_duration
	
	# 应用控制效果
	target.apply_control_effect(control_type_value, duration)
	
	return {
		"type": "control",
		"control_type": control_type_value,
		"duration": duration
	}

## 驱散效果
func _apply_dispel(_source: Character, _target: Character) -> Dictionary:
	# 使用专用属性
	var status_types = dispel_types
	var count = dispel_count
	var is_positive = dispel_is_positive
	
	# 这里仅返回结果，实际驱散由调用者处理
	return {
		"type": "dispel",
		"status_types": status_types,
		"count": count,
		"is_positive": is_positive
	}

## 特殊效果
func _apply_special(_source: Character, _target: Character) -> Dictionary:
	# 使用专用属性
	var special_type_value = special_type
	var params = special_params
	
	# 返回特殊效果信息供调用者处理
	return {
		"type": "special",
		"special_type": special_type_value,
		"special_params": params
	}

## 触发视觉效果
func _trigger_visual_effect(_target: Character) -> void:
	# 这部分会由EffectSystem处理
	pass

## 触发音效
func _trigger_sound_effect(_target: Character) -> void:
	# 这部分会由EffectSystem处理
	pass

## 获取属性修改效果描述
func _get_attribute_modify_description() -> String:
	var attr = attr_target
	var value = attr_value
	var is_percent = attr_is_percent
	
	var attr_name = ""
	match attr:
		"attack": attr_name = "攻击力"
		"defense": attr_name = "防御力"
		"magic_attack": attr_name = "魔法攻击"
		"magic_defense": attr_name = "魔法防御"
		"speed": attr_name = "速度"
		_: attr_name = attr
	
	if is_percent:
		var _sign = "+" if value > 0 else "-"
		return "%s%d%% %s" % [_sign, abs(value), attr_name]
	else:
		var _sign = "+" if value > 0 else "-"
		return "%s%d %s" % [_sign, abs(value), attr_name]

## 获取伤害效果描述
func _get_damage_description() -> String:
	var amount = damage_amount if damage_amount > 0 else power
	var element_type = damage_element if damage_element > 0 else element
	
	var element_name = ""
	element_name = ElementTypes.get_element_name(element_type)
	
	var dot_text = "持续" if damage_is_dot else ""
	
	if element_name != "":
		return "%s造成 %d 点%s伤害" % [dot_text, amount, element_name]
	else:
		return "%s造成 %d 点伤害" % [dot_text, amount]

## 获取治疗效果描述
func _get_heal_description() -> String:
	var amount = heal_amount if heal_amount > 0 else power
	var hot_text = "持续" if heal_is_hot else ""
	return "%s恢复 %d 点生命值" % [hot_text, amount]

## 获取控制效果描述
func _get_control_description() -> String:
	var control_type_value = control_type
	var duration = control_duration
	
	var type_name = ""
	match control_type_value:
		"stun": type_name = "眩晕"
		"silence": type_name = "沉默"
		"root": type_name = "定身"
		"sleep": type_name = "睡眠"
		_: type_name = control_type_value
	
	return "%s目标 %d 回合" % [type_name, duration]

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
