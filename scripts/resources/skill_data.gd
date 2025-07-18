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

#region --- 导出的属性 ---
@export var skill_id: StringName = &"new_skill" 				## 内部ID，用StringName效率略高
@export var skill_name: String = "新技能"       				## UI显示名称
@export_multiline var description: String = "技能描述..." 		## UI显示描述

@export_group("消耗与目标")
@export var mp_cost: int = 5									## 魔法消耗
@export var target_type: TargetType = TargetType.ENEMY_SINGLE	## 目标类型

@export_group("效果")
@export var effects : Array[SkillEffect] = []				## 主动技能施放时的直接效果
@export_enum("any_action", "any_skill", "magic_skill", "ranged_skill", "melee_skill", "basic_attack", "physical_attack")
var action_categories: Array[String] = ["any_action"] 			## 所属行动类别

@export_group("视觉与音效 (可选)")
@export var icon: Texture2D = null # 技能图标
@export var cast_animation: StringName = "" # 施法动画名 (如果角色动画器中有)

@export var can_target_dead : bool = false # 是否可以对死亡目标施放

# 未来可扩展其他视觉和音效选项
# @export var vfx_scene: PackedScene # 技能特效场景
# @export var sfx: AudioStream # 技能音效
#endregion

## 检查是否能施放技能
func can_cast(caster_current_mp: float) -> bool:
	return caster_current_mp >= mp_cost

## 获得技能完整描述
func get_full_description() -> String:
	var desc = ""
	desc += "类型: 主动技能\n"
	desc += "消耗: " + str(mp_cost) + " MP\n"
	desc += "目标: " + _get_target_type_name() + "\n"

	desc += "\n效果:\n"
	var effects_to_describe: Array[SkillEffect] = effects
	for effect in effects_to_describe: # 处理 ACTIVE 和 PASSIVE 的主要效果
		if is_instance_valid(effect): # 确保 effect 实例有效
			desc += "- " + effect.get_description() + "\n"
		else:
			desc += "- [color=red](无效效果数据)[/color]\n"
	desc += "[color=gray]" + description + "[/color]\n\n"
	return desc.strip_edges()

## 是否需要选择目标
func needs_target() -> bool:
	return target_type in [TargetType.ENEMY_SINGLE, TargetType.ALLY_SINGLE, TargetType.ALLY_SINGLE_INC_SELF]

## 敌人目标
func is_enemy_target() -> bool:
	return target_type in [TargetType.ENEMY_SINGLE, TargetType.ENEMY_ALL]

## 包含自身
func is_including_self() -> bool:
	return target_type in [TargetType.ALLY_SINGLE_INC_SELF, TargetType.ALLY_ALL_INC_SELF]

## 获取目标类型名称
func _get_target_type_name() -> String:
	match target_type:
		TargetType.SELF:
			return "自身"
		TargetType.ENEMY_SINGLE:
			return "单个敌人"
		TargetType.ENEMY_ALL:
			return "所有敌人"
		TargetType.ALLY_SINGLE:
			return "单个友方(不含自己)"
		TargetType.ALLY_ALL:
			return "所有友方(不含自己)"
		TargetType.ALLY_SINGLE_INC_SELF:
			return "单个友方(含自己)"
		TargetType.ALLY_ALL_INC_SELF:
			return "所有友方(含自己)"
		_:
			return "未知目标"
