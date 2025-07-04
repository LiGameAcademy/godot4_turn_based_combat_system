extends Resource
class_name SkillStatusData

## 状态数据资源，用于定义状态效果的模板配置和运行时实例。
## 通过 SkillStatusData，我们可以为不同的状态效果设置不同的属性和行为。
## 这些配置将被用于在战斗中创建和管理状态效果实例。

## 堆叠行为
enum StackBehavior { 
	NO_STACK,                               ## 不可叠加
	REFRESH_DURATION,                       ## 刷新持续时间
	ADD_DURATION,                           ## 增加持续时间
	ADD_STACKS_REFRESH_DURATION,            ## 增加叠加层数并刷新持续时间
	ADD_STACKS_INDEPENDENT_DURATION         ## 增加叠加层数并独立持续时间 (简化实现时可能等同于刷新)
}

## 持续时间类型
enum DurationType {
	TURNS,                                  ## 回合数
	INFINITE,                               ## 无限 (直到被驱散或战斗结束)
	COMBAT_LONG                             ## 持续到战斗结束 (通常不可驱散)
} 

## 状态类型，用于视觉或某些逻辑判断
enum StatusType { 
	BUFF,                                   ## 增益
	DEBUFF,                                 ## 减益
	NEUTRAL                                 ## 中性
}

# --- 模板配置属性 (@export) ---
@export var status_id: StringName = &""         								## 唯一ID
@export var status_name: String = "状态效果"    								## 显示名称
@export_multiline var description: String = ""  								## 详细描述
@export var icon: Texture2D                     								## UI图标

@export var status_type: StatusType = StatusType.NEUTRAL						## 状态类型
@export var duration: int = 3                   								## 默认持续回合数 (对TURNS类型有效)
@export var duration_type: DurationType = DurationType.TURNS					## 持续时间类型
@export var max_stacks: int = 1                 								## 最大叠加层数
@export var stack_behavior: StackBehavior = StackBehavior.REFRESH_DURATION	## 叠加行为

# 核心影响机制 (数组内为 SkillEffectData 或 SkillAttributeModifier 模板资源)
@export var attribute_modifiers : Array[SkillAttributeModifier] = []			## 属性修改器
@export var initial_effects: Array[SkillEffectData] = []						## 初始效果
@export var ongoing_effects: Array[SkillEffectData] = []						## 持续效果
@export var end_effects: Array[SkillEffectData] = []							## 结束效果

# 状态间交互
@export var overrides_states: Array[StringName] = []							## 此状态应用时会移除的目标状态ID列表
@export var resisted_by_states: Array[StringName] = []							## 如果目标拥有这些状态之一，则此状态无法应用

# 触发条件
@export_group("触发条件", "trigger_")
## 此状态可以响应的游戏事件类型
## 例如: [&"on_damage_taken", &"on_turn_start", &"on_attack"]
@export var trigger_on_events: Array[StringName] = []
## 触发时执行的效果
@export var trigger_effects: Array[SkillEffectData] = []
## 回合触发次数
@export var trigger_turns: int = 1
## 触发总数
@export var trigger_count: int = 1

# 行动限制
@export_group("行动限制")
## 角色拥有此状态时，无法执行哪些类别的行动。
## 数组元素为StringName，对应 SkillData.action_categories 中的类别。
## 例如: [&"any_action"] (眩晕), [&"magic_skill"] (沉默)
@export_enum("any_action", "any_skill", "magic_skill", "ranged_skill", "melee_skill", "basic_attack", "attack", "defend", "item")
var restricted_action_categories: Array[String] = []

# --- 运行时变量 (在 duplicate(true) 后由 character.gd 设置和管理) ---
var source_character: Character   													## 施加此状态的角色
var target_character: Character   													## 拥有此状态的角色 (方便状态效果内部逻辑访问目标)
var remaining_duration: int       												## 剩余持续时间
var stacks: int = 1          													## 当前叠加层数
var is_permanent: bool :
	get :
		return duration_type == DurationType.INFINITE or duration_type == DurationType.COMBAT_LONG

## 本回合触发次数
var current_turn_trigger_count: int = 0
## 触发总数
var current_total_trigger_count: int = 0

#region --- 方法 ---
func _init() -> void:
	source_character = null
	target_character = null
	remaining_duration = duration 
	stacks = 1

## 获取状态的完整描述
func get_full_description() -> String:
	var desc = "%s: %s\n" % [status_name, description]
	if duration_type == DurationType.TURNS:
		desc += "基础持续 %d 回合. " % duration
	elif duration_type == DurationType.INFINITE:
		desc += "持续无限 (或直到被驱散). "
	elif duration_type == DurationType.COMBAT_LONG:
		desc += "持续至战斗结束. "
		
	if max_stacks > 1:
		desc += "最多叠加 %d 层. " % max_stacks
	if not initial_effects.is_empty(): desc += "应用时触发效果.\n"
	if not ongoing_effects.is_empty(): desc += "每回合触发效果.\n"
	if not end_effects.is_empty(): desc += "结束时触发效果.\n"

	return desc.strip_edges()

## 检查此状态是否可以被抵抗
func is_countered_by(other_status_id: StringName) -> bool:
	return resisted_by_states.has(other_status_id)

## 检查此状态是否可以覆盖其他状态
func overrides_other_status(other_status_id: StringName) -> bool:
	return overrides_states.has(other_status_id)

## 检查此状态是否可以被指定事件触发
func can_trigger_on_event(event_type: StringName) -> bool:
	if trigger_on_events.is_empty():
		return false
	if current_turn_trigger_count >= trigger_turns:
		return false
	if current_total_trigger_count >= trigger_count:
		return false
	return trigger_on_events.has(event_type)

## 获取触发效果
func get_trigger_effects() -> Array[SkillEffectData]:
	return trigger_effects
#endregion
