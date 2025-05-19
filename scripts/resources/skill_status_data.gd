extends Resource
class_name SkillStatusData

## 堆叠行为
enum StackBehavior { 
	NO_STACK, 																	## 不可叠加
	REFRESH_DURATION, 															## 刷新持续时间
	ADD_DURATION, 																## 增加持续时间
	ADD_STACKS_REFRESH_DURATION, 												## 增加叠加层数并刷新持续时间
	ADD_STACKS_INDEPENDENT_DURATION 											## 增加叠加层数并独立持续时间
}

## 持续时间类型
enum DurationType {
	TURNS, 																		## 回合数
	INFINITE, 																	## 无限
	COMBAT_LONG 																## 持续到战斗结束
} 

## 状态类型，用于视觉或某些逻辑判断
enum StatusType { 
	BUFF, 																		## 增益
	DEBUFF, 																	## 减益
	NEUTRAL 																	## 中性
}

# 基本属性
@export var status_id: StringName 												## 唯一ID
@export var status_name: String = "状态效果" 									## 状态名称
@export var description: String = "" 											## 状态描述
@export var icon: Texture2D 													## 状态图标

# 状态设置
@export var status_type: StatusType = StatusType.NEUTRAL 						## 状态类型
@export var duration: int = 3 													## 持续回合数
@export var duration_type: DurationType = DurationType.TURNS 					## 持续时间类型
@export var max_stacks: int = 1 												## 最大叠加层数
@export var stack_behavior: StackBehavior = StackBehavior.REFRESH_DURATION 		## 叠加行为

@export var attribute_modifiers: Array[SkillAttributeModifier] = [] 			## 应用到角色属性的修改器
@export var initial_effects: Array[SkillEffectData] = [] 						## 应用状态时立即触发的效果
@export var ongoing_effects: Array[SkillEffectData] = [] 						## 每回合开始或结束时触发的效果
@export var end_effects: Array[SkillEffectData] = [] 							## 状态结束或被驱散时触发的效果

# 状态间关系
@export var overrides_states: Array[StringName] = []  # 此状态可以覆盖的其他状态
@export var resisted_by_states: Array[StringName] = []  # 会抵抗此状态的其他状态

var source_char: Character
var left_duration: int
var stacks: int

# 获取状态的完整描述
func get_full_description() -> String:
	var desc = description + "\n"
	
	# 添加初始效果描述
	if !initial_effects.is_empty():
		desc += "\n应用时:\n"
		for effect in initial_effects:
			desc += "- " + effect.get_description() + "\n"
	
	# 添加持续效果描述
	if !ongoing_effects.is_empty():
		desc += "\n每回合:\n"
		for effect in ongoing_effects:
			desc += "- " + effect.get_description() + "\n"
	
	# 添加结束效果描述
	if !end_effects.is_empty():
		desc += "\n结束时:\n"
		for effect in end_effects:
			desc += "- " + effect.get_description() + "\n"
	
	# 添加持续时间信息
	desc += "\n持续 " + str(duration) + " 回合"
	
	# 添加堆叠信息
	if stack_behavior != StackBehavior.NO_STACK:
		desc += " (可叠加，最多" + str(max_stacks) + "层)"
	
	return desc

# 检查是否反制指定状态
func counters_status(s_id: StringName) -> bool:
	return overrides_states.has(s_id)

# 检查是否被指定状态反制
func is_countered_by(s_id: StringName) -> bool:
	return resisted_by_states.has(s_id) 

func get_attribute_modifiers() -> Array[SkillAttributeModifier]:
	return attribute_modifiers

func get_initial_effects() -> Array[SkillEffectData]:
	return initial_effects

func get_ongoing_effects() -> Array[SkillEffectData]:
	return ongoing_effects

func get_end_effects() -> Array[SkillEffectData]:
	return end_effects
