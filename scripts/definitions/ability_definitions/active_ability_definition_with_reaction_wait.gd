extends ActiveAbilityDefinition
class_name ActiveAbilityDefinitionWithReactionWait

## 在应用效果之后、后摇之前等待目标空闲（受击动画、反击等技能执行）
## 用于普攻、单体技能等需要“等对方反应完再回位”的配置场景

@export var wait_target_idle_max_time : float = 1.0
@export var wait_target_idle_wait_for_animation : bool = true
@export var wait_target_idle_wait_for_ability : bool = true

func _build_default_behavior_tree(include_cooldown: bool = true, include_cost: bool = true) -> GAS_BTNode:
	var sequence = GAS_BTSequence.new()
	var nodes: Array[GAS_BTNode] = []

	# 1. 播放动画 (异步，不等待)
	if not animation_name.is_empty():
		var anim_node = AbilityNodePlayAnimation.new()
		anim_node.animation_name = animation_name
		anim_node.animation_speed = animation_speed
		anim_node.node_id = "play_animation"
		nodes.append(anim_node)

	# 2. 前摇等待
	if pre_cast_delay > 0.0:
		var wait = GAS_BTWait.new()
		wait.duration = pre_cast_delay
		wait.node_id = "pre_cast_delay"
		nodes.append(wait)

	# 3. 提交冷却 (前摇结束后进CD)
	if include_cooldown and cooldown_duration > 0.0:
		var commit_cd = AbilityNodeCommitCooldown.new()
		commit_cd.node_id = "commit_cooldown"
		nodes.append(commit_cd)

	# 4. 应用消耗
	if include_cost and not costs.is_empty():
		var commit_cost = AbilityNodeCommitCost.new()
		commit_cost.node_id = "commit_cost"
		nodes.append(commit_cost)
	
	# 5. 查找目标
	if is_instance_valid(targeting_strategy):
		var target_search_node = AbilityNodeTargetSearch.new()
		target_search_node.strategy = targeting_strategy
		target_search_node.node_id = "target_search"
		nodes.append(target_search_node)

	# 6. 应用效果
	var effect_node := _build_effect_nodes()
	if is_instance_valid(effect_node):
		nodes.append(effect_node)

    # 6.5. 等待目标空闲
	var wait_idle_node = AbilityNodeWaitTargetIdle.new()
	wait_idle_node.node_id = "wait_target_idle"
	wait_idle_node.max_wait_time = wait_target_idle_max_time
	wait_idle_node.wait_for_animation = wait_target_idle_wait_for_animation
	wait_idle_node.wait_for_ability = wait_target_idle_wait_for_ability
	wait_idle_node.target_key = target_key
	nodes.append(wait_idle_node)

	# 7. 后摇等待
	if post_cast_delay > 0.0:
		var wait = GAS_BTWait.new()
		wait.duration = post_cast_delay
		wait.node_id = "post_cast_delay"
		nodes.append(wait)

	# 赋值子节点
	sequence.children = nodes
	sequence.node_id = "ability_sequence"
	return sequence
