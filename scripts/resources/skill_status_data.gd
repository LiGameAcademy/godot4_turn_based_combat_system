extends Resource
class_name SkillStatusData

## 职责：定义一个或多个EffectData的集合以及它们的触发方式和生命周期。这是“如何持续地做”。

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

## 触发类型
enum TriggerType { 
	CONTINUOUS,                             ## 持续
	PERIODIC,                               ## 周期
	ON_APPLY,                               ## 应用时
	ON_REMOVE,                              ## 移除时
	ON_EVENT                                ## 事件
}

@export var status_id: StringName = &""         								## 唯一ID
@export var status_name: String = "状态效果"    								## 显示名称
@export_multiline 
var description: String = ""  								                    ## 详细描述
@export var icon: Texture2D                     								## UI图标
@export var trigger_type: TriggerType = TriggerType.CONTINUOUS				    ## 触发类型
@export var effects: Array[SkillEffect] = []									## 它所包含的效果

@export_group("堆叠与持续时间")
@export var status_type: StatusType = StatusType.NEUTRAL						## 状态类型
@export var duration: int = 3                   								## 默认持续回合数 (对TURNS类型有效)
@export var duration_type: DurationType = DurationType.TURNS					## 持续时间类型
@export var max_stacks: int = 1                 								## 最大叠加层数
@export var stack_behavior: StackBehavior = StackBehavior.REFRESH_DURATION	    ## 叠加行为

@export_group("状态间交互")
@export var overrides_states: Array[StringName] = []							## 此状态应用时会移除的目标状态ID列表
@export var resisted_by_states: Array[StringName] = []							## 如果目标拥有这些状态之一，则此状态无法应用

@export_group("触发条件")
## 此状态可以响应的游戏事件类型
## 例如: [&"on_damage_taken", &"on_turn_start", &"on_attack"]
@export var trigger_on_events: Array[StringName] = []
@export var trigger_turns: int = 1                                              ## 回合触发次数
@export var trigger_count: int = 1                                              ## 触发总数

var is_permanent: bool :														## 是否永久
	get :
		return duration_type == DurationType.INFINITE or duration_type == DurationType.COMBAT_LONG

## 获取状态的完整描述
func get_full_description() -> String:
	var desc = ""
	if duration_type == DurationType.TURNS:
		desc += "基础持续 %d 回合. " % duration
	elif duration_type == DurationType.INFINITE:
		desc += "持续无限 (或直到被驱散). "
	elif duration_type == DurationType.COMBAT_LONG:
		desc += "持续至战斗结束. "
		
	if max_stacks > 1:
		desc += "最多叠加 %d 层. " % max_stacks
	
	match trigger_type:
		TriggerType.CONTINUOUS: desc += "持续触发. "
		TriggerType.PERIODIC: desc += "周期触发. "
		TriggerType.ON_APPLY: desc += "应用时触发. "
		TriggerType.ON_REMOVE: desc += "移除时触发. "
		TriggerType.ON_EVENT: desc += "事件触发. "

	desc += "\n效果:\n"
	var effects_to_describe: Array[SkillEffect] = effects
	for effect in effects_to_describe: # 处理 ACTIVE 和 PASSIVE 的主要效果
		if is_instance_valid(effect): # 确保 effect 实例有效
			desc += "- " + effect.get_description() + "\n"
		else:
			desc += "- [color=red](无效效果数据)[/color]\n"
	desc += "[color=gray]" + description + "[/color]\n\n"

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
	return trigger_on_events.has(event_type)

func is_resisted_by(other_status_id: StringName) -> bool:
	return resisted_by_states.has(other_status_id)

func on_apply() -> void:
	# if trigger_type == TriggerType.ON_APPLY or trigger_type == TriggerType.CONTINUOUS:
	# 	for effect in effects:
	# 		effect.apply(source_character, target_character, remaining_duration)
	pass

func on_remove() -> void:
	# if trigger_type == TriggerType.ON_REMOVE:
	# 	for effect in effects:
	# 		effect.apply((source_character, target_character)
	# elif trigger_type == TriggerType.CONTINUOUS:
	# 	for effect in effects:
	# 		effect.remove((source_character, target_character))
	pass

func on_tick() -> void:
	# if trigger_type == TriggerType.PERIODIC:
	# 	for effect in effects:
	# 		effect.apply(source_character, target_character, remaining_duration)
	pass
