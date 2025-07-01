extends RefCounted
class_name DamageInfo

var base_damage: float      ## 原始基础伤害
var final_damage: float     ## 将被持续计算和修改的最终伤害
var source: Character       ## 伤害来源
var target: Character       ## 伤害目标
var element: int            ## 伤害元素
var is_crit: bool = false   ## 是否暴击
var can_be_modified: bool = true ## 是否可以被修改

var modifications_log: Array[String] = [] ## 用于记录伤害被修改的过程

func _init(
        p_base_damage: float, 
        p_source: Character, 
        p_target: Character, 
        p_element: int,
        p_is_crit: bool = false,
        p_can_be_modified: bool = true
    ) -> void:
    base_damage = p_base_damage
    final_damage = p_base_damage
    source = p_source
    target = p_target
    element = p_element
    is_crit = p_is_crit
    can_be_modified = p_can_be_modified

## 修改伤害, 传入修改类型和修改值，支持百分比修改和直接修改，并且可以提供最大值和最小值钳制
func modify_damage(modify_type: String, modify_value: float, _min_value: float = 0.0, _max_value: float = 9999.0) -> void:
    match modify_type:
        "percent":
            final_damage = final_damage * (1 + modify_value)
        "flat":
            final_damage = final_damage + modify_value
    final_damage = clamp(final_damage, _min_value, _max_value)
    _log_modification(modify_type, modify_value, final_damage)

## 一个受控的、用于记录日志的修改接口
func _log_modification(
        modifier_name: String, 
        old_value: float, 
        new_value: float
    ) -> void:
    modifications_log.append("%s: %.1f -> %.1f" % [modifier_name, old_value, new_value])