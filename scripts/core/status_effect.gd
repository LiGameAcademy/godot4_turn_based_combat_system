class_name StatusEffect
extends RefCounted

var data: StatusEffectData              # 状态效果的数据模板
var source: Character = null            # 效果来源角色 (可用于某些特殊计算)
var remaining_duration: int = 0         # 剩余持续回合数
var stack_count: int = 1                # 当前堆叠层数

func _init(effect_data: StatusEffectData, effect_source: Character = null, initial_stacks: int = 1):
	self.data = effect_data
	self.source = effect_source
	self.remaining_duration = effect_data.duration
	self.stack_count = min(initial_stacks, effect_data.max_stacks)

# 计算修改值 (用于Buff/Debuff)
func calculate_stat_modification(base_value: float) -> float:
	var modifier = 0.0
	
	# 应用固定值修改
	modifier += data.value_flat * stack_count
	
	# 应用百分比修改
	modifier += base_value * (data.value_percent * stack_count)
	
	# 根据效果类型决定是增加还是减少
	if data.effect_type == StatusEffectData.EffectType.DEBUFF:
		modifier = -modifier
		
	return modifier

# 获取每回合伤害/治疗值 (用于DoT/HoT)
func get_dot_hot_value() -> int:
	return data.dot_hot_value * stack_count

# 更新状态效果的持续时间
func update_duration() -> bool:
	remaining_duration -= 1
	return remaining_duration <= 0  # 返回是否已经结束

# 处理效果叠加
func stack_effect(new_effect: StatusEffect) -> void:
	if !data.can_stack or stack_count >= data.max_stacks:
		# 如果不能叠加或已达最大层数，根据叠加行为处理
		match data.stack_behavior:
			"replace":
				# 完全替换为新效果
				remaining_duration = new_effect.remaining_duration
				# stack_count保持不变
			"extend_duration":
				# 延长持续时间
				remaining_duration = max(remaining_duration, new_effect.remaining_duration)
			"increase_intensity":
				# 不做任何事，因为已经达到最大堆叠
				pass
	else:
		# 可以叠加且未达最大层数
		stack_count = min(stack_count + new_effect.stack_count, data.max_stacks)
		
		# 根据叠加行为可能还需要调整持续时间
		if data.stack_behavior == "extend_duration" or data.stack_behavior == "replace":
			remaining_duration = max(remaining_duration, new_effect.remaining_duration)

# 检查是否允许角色行动
func allows_action() -> bool:
	if data.effect_type == StatusEffectData.EffectType.CONTROL:
		return data.can_act
	return true  # 非控制效果不影响行动 
