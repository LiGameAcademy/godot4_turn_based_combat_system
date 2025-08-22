extends Node

## 技能系统
## 作为自动加载的单例，负责技能执行的核心逻辑
## 不直接依赖战斗系统组件，而是通过上下文获取必要的信息

var battle_manager : BattleManager = null

# 信号
signal skill_execution_started(caster: Character, skill: SkillData, targets: Array[Character])							## 技能执行开始信号	
signal skill_execution_completed(caster: Character, skill: SkillData, targets: Array[Character], results: Dictionary) 	## 技能执行完成信号 results 可以包含伤害、治疗、状态等信息
signal skill_failed(caster: Character, skill: SkillData, reason: String) 												## 技能失败信号 例如 MP不足, 目标无效等

func _ready() -> void:
	print("SkillSystem initialized as autoload singleton.")

## 尝试执行一个技能
## [param caster] 施法者
## [param skill_data] 要使用的技能数据
## [param selected_targets] 玩家或AI选择的目标
## [return] 是否成功执行技能
func attempt_execute_skill(skill_data: SkillData, caster: Character, selected_targets: Array[Character], context : SkillExecutionContext) -> Dictionary:
	if not is_instance_valid(caster) or not skill_data:
		push_error("Invalid caster or skill_data for skill execution.")
		skill_failed.emit(caster, skill_data, "invalid_caster_or_skill")
		return {}

	# 获取技能实际目标
	var actual_targets = _determine_execution_targets(caster, skill_data, selected_targets, context)

	# 1. 验证施法条件 (MP, 冷却, 目标等)
	var validation_result = _validate_skill_usability(skill_data, caster, actual_targets, context)
	if not validation_result.is_usable:
		print_rich("[color=orange]Skill '%s' failed validation: %s[/color]" % [skill_data.skill_name, validation_result.reason])
		skill_failed.emit(caster, skill_data, validation_result.reason)
		if context.battle_manager and context.battle_manager.has_method("show_status_text"):
			context.battle_manager.show_status_text(caster, validation_result.reason, true)
		return {"error": validation_result.reason}

	print_rich("[color=lightblue]%s attempts to use skill: %s on %s[/color]" % [caster.character_name, skill_data.skill_name, selected_targets])
	skill_execution_started.emit(caster, skill_data, selected_targets)

	context.skill_data = skill_data

	# 2. 消耗资源 (MP, 物品等)
	_consume_skill_resources(caster, skill_data)

	# 3. 异步执行技能效果处理
	var final_result : Dictionary = {}
	if skill_data.is_melee:
		final_result = await _process_melee_skill(skill_data, caster, actual_targets, context)
	else:
		final_result = await _process_ranged_skill(skill_data, caster, actual_targets, context)

	# 发出技能执行完成信号
	skill_execution_completed.emit(caster, skill_data, actual_targets, final_result)
	print_rich("[color=lightgreen]%s's skill '%s' execution completed.[/color]" % [caster.character_name, skill_data.skill_name])
	return final_result

## 尝试处理状态效果
func attempt_process_status_effects(effects : Array[SkillEffect], caster: Character, target: Character, context : SkillExecutionContext) -> Dictionary:
	var result = {"success": true, "reason": ""}
	for effect in effects:
		if not await effect.process_effect(caster, target, context):
			result.success = false
			result.reason = "Failed to apply effect: %s" % effect
			return result
	return result

## 触发游戏事件
## [param event_source] 事件的触发者
## [param event_type] 事件类型，如 "on_damage_taken", "on_turn_start", "on_attack" 等
## [param context] 事件上下文，包含事件相关的所有信息
func trigger_game_event(event_source: Character, event_type: StringName, context: EventContext) -> void:
	# 打印事件日志（调试用）
	print_rich("[color=purple]游戏事件触发: %s[/color]" % event_type)
	
	# 触发事件
	var skill_component : CharacterSkillComponent = event_source.get_skill_component()
	if not skill_component:
		push_error("无法找到技能组件！")
		return
	
	var triggerable_statuses = skill_component.get_triggerable_status(event_type)
	if triggerable_statuses.is_empty():
		return
	
	for status in triggerable_statuses:
		var trigger_effects = status.get_trigger_effects()
		if trigger_effects.is_empty():
			continue
		var skill_context : SkillExecutionContext = SkillExecutionContext.new(battle_manager)
		if context is DamageEventContext:
			skill_context.damage_info = context.damage_info
		await _process_skill_effects_async(trigger_effects, status.source_character, [event_source], skill_context)
		skill_component.update_status_trigger_counts(status)

## 异步处理技能效果的核心逻辑 (使用 call_deferred 调用)
## [param effects] 技能效果列表
## [param caster] 施法者
## [param targets] 目标列表
## [param context] 技能执行上下文
## [return] 处理结果的字典
func _process_skill_effects_async(effects: Array[SkillEffect], caster: Character, targets: Array[Character], context: SkillExecutionContext) -> Dictionary:
	# 确保在操作前，所有参与者仍然有效
	if not is_instance_valid(caster):
		push_error("SkillSystem: Invalid caster or skill_data in _process_skill_effects_async.")
		return {
			"success": false,
			"reason": "Invalid caster or skill_data"
		}

	var overall_results := {}
	for effect in effects:
		for target in targets:
			if not is_instance_valid(target):
				continue
			overall_results[target] = await effect.process_effect(caster, target, context)

	return overall_results

## 执行近战技能
func _process_melee_skill(skill_data: SkillData, caster: Character, targets: Array[Character], context: SkillExecutionContext) -> Dictionary:
	if not skill_data.is_melee:
		return {
			"success": false,
			"reason": "Skill is not melee"
		}

	var overall_results = {}
	for target in targets:
		if not is_instance_valid(target):
			continue
		
		await caster.move_to_target(target)
		if skill_data.cast_animation.is_empty():
			push_warning("SkillSystem: No cast animation for melee skill '%s'" % skill_data.skill_name)
		else:
			caster.play_animation(skill_data.cast_animation)
		if skill_data.pre_cast_delay > 0:
			await get_tree().create_timer(skill_data.pre_cast_delay).timeout
		overall_results[target] = await _process_skill_effects_async(skill_data.effects, caster, [target], context)
		if skill_data.post_cast_delay > 0:
			await get_tree().create_timer(skill_data.post_cast_delay).timeout
			
	return overall_results

## 执行远程技能
func _process_ranged_skill(skill_data: SkillData, caster: Character, targets: Array[Character], context: SkillExecutionContext) -> Dictionary:
	if skill_data.is_melee:
		return {
			"success": false,
			"reason": "Skill is melee"
		}
		
	var overall_results = {}

	await caster.move_to_cast_marker()
	if skill_data.cast_animation.is_empty():
		push_warning("SkillSystem: No cast animation for melee skill '%s'" % skill_data.skill_name)
	else:
		caster.play_animation(skill_data.cast_animation)

	if skill_data.pre_cast_delay > 0:
		await get_tree().create_timer(skill_data.pre_cast_delay).timeout
	overall_results = await _process_skill_effects_async(skill_data.effects, caster, targets, context)
	if skill_data.post_cast_delay > 0:
		await get_tree().create_timer(skill_data.post_cast_delay).timeout
	return overall_results

## 私有方法：验证技能可用性
func _validate_skill_usability(skill: SkillData, caster: Character, targets: Array[Character], _context: SkillExecutionContext) -> Dictionary:
	var result = {"is_usable": true, "reason": ""}

	# 检查MP消耗
	if caster.current_mp < skill.mp_cost:
		result.is_usable = false
		result.reason = "Not enough MP"
		return result

	if not _validate_skill_targets(skill, targets):
		result.is_usable = false
		result.reason = "Invalid target(s) for skill scope"
		return result
		
	return result

## 私有方法：验证技能目标
## [param skill] 要使用的技能数据
## [param targets] 目标列表
func _validate_skill_targets(skill: SkillData, targets: Array[Character]) -> bool:
	if skill.target_type == SkillData.TargetType.NONE:
		return true
	
	if targets.is_empty() and skill.target_type != SkillData.TargetType.NONE:
		push_warning("Skill '%s' requires targets, but none were resolved or provided." % skill.skill_name)
		return false

	for target_char in targets:
		if not is_instance_valid(target_char):
			push_warning("Skill '%s' has an invalid target instance." % skill.skill_name)
			return false # An invalid instance in the list is a problem
		if not target_char.is_alive and not skill.can_target_dead:
			push_warning("Skill '%s' cannot target dead characters, but '%s' is dead." % [skill.skill_name, target_char.character_name])
			return false
		# TODO: Add more validation: range, line of sight, specific immunities to this skill type etc.
	return true

## 私有方法：消耗技能资源
## [param caster] 施法者
## [param skill] 要使用的技能数据
func _consume_skill_resources(caster: Character, skill: SkillData) -> void:
	if skill.mp_cost > 0:
		caster.use_mp(skill.mp_cost) # Character类应有 use_mp 方法
	
	# 处理其他资源消耗，例如物品、怒气等
	# if skill.consumes_item:
	#    caster.inventory.remove_item(skill.item_consumed_id, 1)
	#
	# if skill.rage_cost > 0:
	#    caster.use_rage(skill.rage_cost)

## 确定实际目标
## [param caster] 施法者
## [param skill] 要使用的技能数据
## [param selected_targets] 玩家或AI选择的目标
## [return] 实际目标数组
func _determine_execution_targets(caster: Character, skill: SkillData, selected_targets: Array[Character], context : SkillExecutionContext) -> Array[Character]:
	var final_targets: Array[Character] = []
	if skill.needs_target():
		final_targets = selected_targets
	else:
		var all_allies = context.battle_manager.get_valid_ally_targets(false, caster)
		var all_allies_inc_self = context.battle_manager.get_valid_ally_targets(true, caster)
		var all_enemies = context.battle_manager.get_valid_enemy_targets(caster)
		match skill.target_type:
			SkillData.TargetType.SELF:
				if is_instance_valid(caster) and (caster.is_alive or skill.can_target_dead):
					final_targets.append(caster)
			SkillData.TargetType.ALLY_ALL:
				final_targets = all_allies
			SkillData.TargetType.ALLY_ALL_INC_SELF:
				final_targets = all_allies_inc_self
			SkillData.TargetType.ENEMY_ALL:
				final_targets = all_enemies
			SkillData.TargetType.ALLY_RANDOM:
				final_targets = _get_random_targets(all_allies, min(skill.target_count, all_allies.size()))
			SkillData.TargetType.ALLY_RANDOM_INC_SELF:
				final_targets = _get_random_targets(all_allies_inc_self, min(skill.target_count, all_allies_inc_self.size()))
			SkillData.TargetType.ENEMY_RANDOM:
				final_targets = _get_random_targets(all_enemies, min(skill.target_count, all_enemies.size()))
			_:
				push_warning("SkillSystem: Unhandled skill.target_type in _determine_execution_targets: %s" % skill.target_type)
				# Could implement a fallback here

	# 过滤掉无效目标
	var valid_targets: Array[Character] = []
	for target in final_targets:
		if is_instance_valid(target) and (target.is_alive or skill.can_target_dead):
			valid_targets.append(target)

	return valid_targets

## 获取随机目标
func _get_random_targets(targets: Array[Character], count: int) -> Array[Character]:
	var random_targets: Array[Character] = targets.duplicate(false)
	random_targets.shuffle()
	return random_targets.slice(0, count)
