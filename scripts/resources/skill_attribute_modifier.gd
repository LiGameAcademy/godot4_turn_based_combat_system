# scripts/core/attributes/skill_attribute_modifier.gd
extends Resource # 或者 RefCounted，取决于你希望如何管理和序列化它
class_name SkillAttributeModifier

enum ModifierOperation {
	ADD_ABSOLUTE,             ## 直接加/减一个固定值 (例如: +10 攻击力)
	MULTIPLY_PERCENTAGE_BASE, ## 基于属性的基础值计算百分比 (例如: +20% 基础生命)
	MULTIPLY_PERCENTAGE_TOTAL,## 基于当前累计值计算百分比 (例如: 最终伤害 * 1.5)
	OVERRIDE                  ## 直接覆盖属性的最终值 (例如: 速度强制设为0)
}

## 修改的幅度 (例如: 10, -5, 0.2, 1.5)
@export var magnitude: float = 0.0
## 修改的操作类型
@export var operation: ModifierOperation = ModifierOperation.ADD_ABSOLUTE
## (可选) 此Modifier的来源标识 (例如Buff的ID, 装备的UUID等)
## 用于调试或由外部系统决定是否移除特定来源的Modifier
@export var source_id: String = "" 

func _init(
		p_magnitude: float = 0.0, 
		p_operation: ModifierOperation = ModifierOperation.ADD_ABSOLUTE, 
		p_source_id: String = "") -> void:
	magnitude = p_magnitude
	operation = p_operation
	source_id = p_source_id
