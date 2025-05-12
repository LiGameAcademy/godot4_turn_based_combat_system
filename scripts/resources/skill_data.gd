extends Resource
class_name SkillData

## --- 核心要素枚举 ---

## 目标类型
enum TargetType {
	NONE,                   ## 无需目标 (例如自身buff)
	ENEMY_SINGLE,           ## 敌方单体
	ENEMY_ALL,              ## 敌方全体
	ALLY_SINGLE,            ## 我方单体 (不含自己)
	ALLY_ALL,               ## 我方全体 (不含自己)
	SELF,                   ## 施法者自己
	ALLY_SINGLE_INC_SELF,   ## 我方单体 (含自己)
	ALLY_ALL_INC_SELF       ## 我方全体 (含自己)
}

## --- 导出的属性 ---
@export var skill_id: StringName = &"new_skill" # 内部ID，用StringName效率略高
@export var skill_name: String = "新技能"       # UI显示名称
@export_multiline var description: String = "技能描述..." # UI显示描述

@export_group("消耗与目标")
@export var mp_cost: int = 5
@export var target_type: TargetType = TargetType.ENEMY_SINGLE

@export_group("元素属性")
@export var element: int = 0 # ElementTypes.Element.NONE - 使用整型而不是枚举，提高兼容性

@export_group("效果设置")
@export var effects: Array[SkillEffect] = []

@export_group("视觉与音效 (可选)")
@export var icon: Texture2D = null # 技能图标
@export var cast_animation: String = "" # 施法动画名
@export var hit_animation: String = "" # 命中动画名
# 未来可扩展其他视觉和音效选项
# @export var vfx_scene: PackedScene # 技能特效场景
# @export var cast_sfx: AudioStream # 施法音效
# @export var hit_sfx: AudioStream # 命中音效

@export_group("状态效果 (可选)")
@export var status_effect_id: String = ""   # 状态效果ID，对应资源文件名
@export_range(0, 100) var status_effect_chance: int = 100  # 状态效果应用几率

## 检查是否能施放技能
func can_cast(caster_current_mp: int) -> bool:
	return caster_current_mp >= mp_cost

## 获取技能效果数组 (确保向后兼容)
func get_effects() -> Array[SkillEffect]:
	return effects
