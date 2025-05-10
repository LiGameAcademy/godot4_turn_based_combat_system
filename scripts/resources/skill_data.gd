extends Resource
class_name SkillData

## --- 核心要素枚举 ---
## 效果类型
enum EffectType {
	DAMAGE,       ## 造成伤害
	HEAL,         ## 恢复HP
	APPLY_STATUS, ## 施加状态 (Buff/Debuff)
	CONTROL,      ## 控制效果 (如眩晕)
	SPECIAL       ## 特殊，可能需要自定义逻辑
}

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

@export_group("消耗与效果")
@export var mp_cost: int = 5
@export var effect_type: EffectType = EffectType.DAMAGE
@export var target_type: TargetType = TargetType.ENEMY_SINGLE
@export var power: int = 10 # 技能威力 (用于伤害/治疗计算)

@export_group("视觉与音效 (可选)")
@export var icon: Texture2D = null # 技能图标
# 未来可扩展其他视觉和音效选项
# @export var animation_name: StringName # 施法动画名 (如果角色动画器中有)
# @export var vfx_scene: PackedScene # 技能特效场景
# @export var sfx: AudioStream # 技能音效

## 检查是否能施放技能
func can_cast(caster_current_mp: int) -> bool:
	return caster_current_mp >= mp_cost
