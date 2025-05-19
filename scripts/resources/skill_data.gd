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
	ALLY_ALL_INC_SELF,      ## 我方全体 (含自己)
	ALL                     ## 所有角色
}

## 技能类型
enum SkillArchetype {
	ACTIVE,      ## 主动技能
	PASSIVE,     ## 被动技能
	TOGGLEABLE   ## 开关技能
}

# --- 导出的属性 ---
@export var skill_id: StringName = &""              			# 技能唯一标识符
@export var skill_name: String = "技能名称"           			# 技能名称
@export_multiline var description: String = "技能描述"          		# 技能描述
@export var archetype: SkillArchetype = SkillArchetype.ACTIVE # 技能类型

@export_group("消耗与目标")
@export var mp_cost: int = 10                      				# 魔法消耗
@export var target_type: TargetType = TargetType.ENEMY_SINGLE  	# 目标类型

@export_group("元素属性")
@export var element: int = 0                        # 元素类型 (使用ElementTypes中的值)

## 根据原型，语义可能不同
## ACTIVE: 技能施放时的直接效果 (包含应用状态的SkillEffectData)
## PASSIVE (持续型): 学习/装备时应用的永久效果
## TOGGLEABLE: 可以是空的，主要依赖开关效果组
@export_group("主要效果列表", "effects_") 										
@export var direct_effects: Array[SkillEffectData] = []

@export_group("被动技能触发设置", "passive_trigger_") 							## 仅当 archetype == PASSIVE 时相关
@export var trigger_event: StringName = &"" 									## 如 "on_owner_damaged"
@export_range(0.0, 1.0) var trigger_chance: float = 1.0
@export var triggered_effects: Array[SkillEffectData] = [] 						## 被动触发时执行的效果
@export var passive_cooldown: float = 0.0 										## 被动触发后的冷却回合数

@export_group("开关技能设置", "toggle_") 										## 仅当 archetype == TOGGLEABLE 时相关
@export var upkeep_cost_mp_per_turn: int = 0 									## 持续消耗MP
@export var effects_on_activate: Array[SkillEffectData] = [] 					## 开启时执行的效果
@export var effects_on_deactivate: Array[SkillEffectData] = [] 					## 关闭时执行的效果
@export var is_active_by_default: bool = false 									## 是否默认开启

@export_group("视觉与音效 (可选)")
@export var icon: Texture2D = null # 技能图标
@export var cast_animation: String = ""             # 施法动画名称
@export var hit_animation: String = ""              # 命中动画名称
# 未来可扩展其他视觉和音效选项
# @export var vfx_scene: PackedScene # 技能特效场景
# @export var cast_sfx: AudioStream # 施法音效
# @export var hit_sfx: AudioStream # 命中音效

@export_enum("any_action", "any_skill", "magic_skill", "ranged_skill", "melee_skill", "basic_attack")
var action_categories: Array[String] = ["any_action"] 

## 检查是否能施放技能
func can_cast(character: Character) -> bool:
	return character.current_mp >= mp_cost

## 获取技能完整描述
func get_full_description() -> String:
	var desc = skill_name + "\n"
	desc += "[color=gray]" + description + "[/color]\n\n"

	match archetype:
		SkillArchetype.ACTIVE:
			desc += "类型: 主动技能\n"
			desc += "消耗: " + str(mp_cost) + " MP\n"
			desc += "目标: " + get_target_type_name() + "\n"
		SkillArchetype.PASSIVE:
			desc += "类型: 被动技能\n"
			if mp_cost > 0: # 有些被动学习时可能有一次性消耗
				desc += "学习消耗: " + str(mp_cost) + " MP\n"
			if trigger_event != &"":
				desc += "触发条件: 当 %s (%.0f%%几率)\n" % [trigger_event, trigger_chance * 100]
			if passive_cooldown > 0:
				desc += "触发冷却: %s 回合\n" % str(passive_cooldown)
		SkillArchetype.TOGGLEABLE:
			desc += "类型: 开关技能\n"
			if mp_cost > 0:
				desc += "激活消耗: " + str(mp_cost) + " MP\n"
			if upkeep_cost_mp_per_turn > 0:
				desc += "维持消耗: " + str(upkeep_cost_mp_per_turn) + " MP/回合\n"

	desc += "元素: " + ElementTypes.get_element_name(element) + "\n"

	desc += "\n效果:\n"
	var effects_to_describe: Array[SkillEffectData] = []
	match archetype:
		SkillArchetype.ACTIVE:
			effects_to_describe = direct_effects
		SkillArchetype.PASSIVE:
			if trigger_event != &"":
				effects_to_describe = triggered_effects
				desc += "(触发时)\n"
			else: # 持续型被动
				effects_to_describe = direct_effects
				desc += "(持续效果)\n" # 或学习时效果
		SkillArchetype.TOGGLEABLE:
			if !effects_on_activate.is_empty():
				desc += "(激活时)\n"
				for effect in effects_on_activate:
					desc += "- " + effect.get_description() + "\n"
			if !effects_on_deactivate.is_empty():
				desc += "(关闭时)\n"
				for effect in effects_on_deactivate:
					desc += "- " + effect.get_description() + "\n"
			# 如果有 "effects_while_active"，也应在此描述
			# 但通常开关技能通过 "effects_on_activate" 应用一个状态来实现持续效果

	for effect in effects_to_describe: # 处理 ACTIVE 和 PASSIVE 的主要效果
		if is_instance_valid(effect): # 确保 effect 实例有效
			desc += "- " + effect.get_description() + "\n"
		else:
			desc += "- [color=red](无效效果数据)[/color]\n"

	return desc.strip_edges()

## 获取目标类型名称
func get_target_type_name() -> String:
	match target_type:
		TargetType.SELF:
			return "自身"
		TargetType.ENEMY_SINGLE:
			return "单个敌人"
		TargetType.ENEMY_ALL:
			return "所有敌人"
		TargetType.ALLY_SINGLE:
			return "单个友方 (不含自己)"
		TargetType.ALLY_ALL:
			return "所有友方 (不含自己)"
		TargetType.ALLY_SINGLE_INC_SELF:
			return "单个友方 (含自己)"
		TargetType.ALLY_ALL_INC_SELF:
			return "所有友方 (含自己)"
		TargetType.ALL:
			return "所有角色"
		_:
			return "未知目标"
