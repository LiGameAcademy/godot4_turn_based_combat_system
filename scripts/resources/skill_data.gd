extends Resource
class_name SkillData

## --- 核心要素枚举 ---

## 目标类型
enum TargetType {
	SELF,             		## 自己
	SINGLE_ENEMY,     		## 单个敌人
	SINGLE_ALLY,      		## 单个友方
	ALL_ENEMIES,      		## 所有敌人
	ALL_ALLIES,       		## 所有友方
	ALL_ALLIES_EXCEPT_SELF, ## 除自己外的所有友方
	ALL               		## 所有角色
}

## --- 导出的属性 ---
@export var skill_id: StringName = &""              # 技能唯一标识符
@export var skill_name: String = "技能名称"          # 技能名称
@export_multiline var description: String = "技能描述"         # 技能描述

@export_group("消耗与目标")
@export var mp_cost: int = 10                      # 魔法消耗
@export var target_type: TargetType = TargetType.SINGLE_ENEMY  # 目标类型

@export_group("元素属性")
@export var element: int = 0                        # 元素类型 (使用ElementTypes中的值)

@export_group("效果设置")
@export var direct_effects: Array[SkillEffectData] = [] ## 直接效果
@export var statuses: Array[SkillStatusData] = [] ## 可能附加的状态
@export var status_chances: Array[float] = []      ## 对应状态的应用几率(0-1)

@export_group("视觉与音效 (可选)")
@export var icon: Texture2D = null # 技能图标
@export var cast_animation: String = ""             # 施法动画名称
@export var hit_animation: String = ""              # 命中动画名称
# 未来可扩展其他视觉和音效选项
# @export var vfx_scene: PackedScene # 技能特效场景
# @export var cast_sfx: AudioStream # 施法音效
# @export var hit_sfx: AudioStream # 命中音效

@export_group("状态效果 (可选)")
@export var status_effect_id: String = ""   ## 状态效果ID，对应资源文件名
@export_range(0, 100) var status_effect_chance: int = 100  # 状态效果应用几率

## 检查是否能施放技能
func can_cast(character: Character) -> bool:
	return character.current_mp >= mp_cost

## 获取技能完整描述
func get_full_description() -> String:
	var desc = description + "\n\n"
	
	# 添加消耗信息
	desc += "消耗: " + str(mp_cost) + " MP\n"
	
	# 添加目标信息
	desc += "目标: " + get_target_type_name() + "\n\n"
	
	# 添加元素信息，如果有的话
	if element > 0:
		if "ElementTypes" in Engine.get_singleton_list():
			desc += "元素: " + ElementTypes.get_element_name(element) + "\n\n"
	
	# 添加直接效果
	if !direct_effects.is_empty():
		desc += "效果:\n"
		for effect in direct_effects:
			desc += "- " + effect.get_description() + "\n"
	
	# 添加状态效果
	if !statuses.is_empty():
		desc += "\n可能附加的状态:\n"
		for i in range(statuses.size()):
			var status = statuses[i]
			var chance = status_chances[i] if i < status_chances.size() else 1.0
			var chance_text = "" if chance >= 1.0 else " (%d%%几率)" % int(chance * 100)
			desc += "- " + status.effect_name + chance_text + "\n"
	
	return desc

## 获取目标类型名称
func get_target_type_name() -> String:
	match target_type:
		TargetType.SELF:
			return "自身"
		TargetType.SINGLE_ENEMY:
			return "单个敌人"
		TargetType.SINGLE_ALLY:
			return "单个友方"
		TargetType.ALL_ENEMIES:
			return "所有敌人"
		TargetType.ALL_ALLIES:
			return "所有友方"
		TargetType.ALL_ALLIES_EXCEPT_SELF:
			return "除自身外的所有友方"
		TargetType.ALL:
			return "所有角色"
		_:
			return "未知目标"
