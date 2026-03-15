extends AbilityNodeBase
class_name AbilityNodeWaitTargetIdle

## 应用效果之后等待目标“闲置”（受击动作播放完、反击等技能执行完）再继续
## 用于回合制中“等待对方反应结束再回到自己位置”的场景

## 最大等待时间，如果为-1则无限等待
@export var max_wait_time: float = 1.0
@export var wait_for_animation: bool = true
@export var wait_for_ability: bool = true
@export var is_idle_method_name : StringName = "is_idle"
@export var ability_component_name : StringName = "GameplayAbilityComponent"

func _enter(instance: GAS_BTInstance) -> void:
	_set_storage(instance, {
		"start_time": Time.get_ticks_msec() / 1000.0
	})

func _tick(instance: GAS_BTInstance, _delta: float) -> int:
	var target_list := _get_target_list(instance, false)
	if target_list.is_empty():
		push_error("AbilityNodeWaitTargetIdle: No target found")
		return Status.SUCCESS

	var is_busy := false

	for target in target_list:
		if not is_instance_valid(target) or not target is Node:
			continue
		
		var node_target : Node = target as Node
		if _is_target_busy(node_target):
			is_busy = true
			break
	
	if not is_busy:
		return Status.SUCCESS

	var storage : Dictionary = _get_storage(instance)
	var start_time : float = storage.get("start_time", 0.0)
	var current_time : float = Time.get_ticks_msec() / 1000.0
	if max_wait_time > 0.0 and current_time - start_time > max_wait_time:
		return Status.SUCCESS
		
	return Status.RUNNING

# 检查目标是否繁忙
func _is_target_busy(target: Node) -> bool:
	if wait_for_animation:
		if target.has_method(is_idle_method_name):
			var is_idle : bool = target.call(is_idle_method_name)
			if not is_idle:
				return true
	
	if wait_for_ability:
		var ability_component : GameplayAbilityComponent = GameplayAbilitySystem.get_component_by_interface(target, ability_component_name)
		if not is_instance_valid(ability_component):
			return false
		
		var current_cast_ability : GameplayAbilityInstance = ability_component.get_current_casting_ability()
		if not is_instance_valid(current_cast_ability) or not current_cast_ability.is_active:
			return false
		
	return false
