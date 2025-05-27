# damage_info.gd
class_name DamageInfo extends RefCounted

## 造成伤害的角色
var source_character: Character
## 受到伤害的角色
var target_character: Character
## 基础伤害量 (经过初步计算，但未经过任何状态效果或触发效果修正的伤害)
var base_damage_amount: float = 0.0
## 修改后的伤害量 (经过各种效果修正后的最终伤害)
var modified_damage_amount: float = 0.0
## 伤害元素类型
var damage_element: int = ElementTypes.NONE
## 是否为暴击
var is_critical_hit: bool = false
## 此伤害是否可以被后续效果修改 (例如，某些“真实伤害”可能不允许修改)
var can_be_modified: bool = true
## 伤害标签，用于更细致的触发条件判断，例如："物理", "魔法", "反击", "持续伤害"
var tags: Array[StringName] = []

## 效果应用历史记录，用于调试或实现依赖修改历史的复杂逻辑
## 每一项可以是字典：{ "modifier_name": StringName, "change_amount": float, "original_value": float, "new_value": float, "type": StringName }
## 例如: type 可以是 "flat_reduction", "percentage_increase", "absorption" 等
var modification_log: Array[Dictionary] = []

func _init(p_source: Character, p_target: Character, p_base_damage: float, \
		p_element: int = ElementTypes.NONE, p_is_crit: bool = false, p_tags: Array[StringName] = []):
	source_character = p_source
	target_character = p_target
	base_damage_amount = p_base_damage
	modified_damage_amount = p_base_damage # 初始时，修改后伤害等于基础伤害
	damage_element = p_element
	is_critical_hit = p_is_crit
	tags = p_tags.duplicate() # 复制数组以避免外部修改


## 添加一条修改记录
func _add_modification_log(modifier_name: StringName, original_value: float, new_value: float, type: StringName):
	modification_log.append({
		"modifier_name": modifier_name,
		"change_amount": new_value - original_value,
		"original_value": original_value,
		"new_value": new_value,
		"type": type
	})

## 应用一个固定值的伤害调整 (正数为增加，负数为减少)
func apply_flat_modification(amount: float, modifier_name: StringName = &"FlatModification"):
	if not can_be_modified:
		return
	
	var original_value = modified_damage_amount
	modified_damage_amount += amount
	if modified_damage_amount < 0 and not tags.has(&"allow_negative_damage"): # 通常伤害不应为负，除非特殊标记
		modified_damage_amount = 0
	_add_modification_log(modifier_name, original_value, modified_damage_amount, &"flat_modification")

## 应用一个百分比的伤害调整 (例如 0.1 表示增加10%，-0.1 表示减少10%)
## percentage: 0.0 到 1.0 (或更高，如果允许超过100%的增伤)
## based_on_current: true 表示基于当前modified_damage_amount计算，false表示基于base_damage_amount计算
func apply_percentage_modification(percentage: float, modifier_name: StringName = &"PercentageModification", based_on_current: bool = true):
	if not can_be_modified:
		return
	
	var original_value = modified_damage_amount
	var damage_to_modify = base_damage_amount if not based_on_current else modified_damage_amount
	var change_amount = damage_to_modify * percentage
	
	modified_damage_amount += change_amount
	if modified_damage_amount < 0 and not tags.has(&"allow_negative_damage"):
		modified_damage_amount = 0
	_add_modification_log(modifier_name, original_value, modified_damage_amount, &"percentage_modification")

## 最终确定伤害值，例如确保非负
func finalize_damage():
	if modified_damage_amount < 0 and not tags.has(&"allow_negative_damage"):
		modified_damage_amount = 0
	# 这里可以添加其他最终处理步骤，例如伤害上限/下限等
	can_be_modified = false # 最终化后通常不允许再修改


## 获取最终伤害值
func get_final_damage() -> float:
	return modified_damage_amount

## 检查是否存在特定标签
func has_tag(tag_name: StringName) -> bool:
	return tags.has(tag_name)

## 添加标签
func add_tag(tag_name: StringName):
	if not tags.has(tag_name):
		tags.append(tag_name)

## 移除标签
func remove_tag(tag_name: StringName):
	tags.erase(tag_name)
