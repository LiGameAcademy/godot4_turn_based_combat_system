extends Node

## 技能系统
## 作为自动加载的单例，负责技能执行的核心逻辑
## 不直接依赖战斗系统组件，而是通过上下文获取必要的信息

var battle_manager : BattleManager = null

# 信号
signal skill_execution_started(caster: Character, skill: SkillData, targets: Array[Character])							## 技能执行开始信号	
signal skill_execution_completed(caster: Character, skill: SkillData, targets: Array[Character], results: Dictionary) 	## 技能执行完成信号 results 可以包含伤害、治疗、状态等信息
signal skill_failed(caster: Character, skill: SkillData, reason: String) 												## 技能失败信号 例如 MP不足, 目标无效等
signal effect_applied(effect: SkillEffect, source: Character, target: Character, result: Dictionary)				## 效果应用信号

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

	# 1. 验证施法条件 (MP, 冷却, 目标等)
	var validation_result = _validate_skill_usability(skill_data, caster, selected_targets, context)
	if not validation_result.is_usable:
		print_rich("[color=orange]Skill '%s' failed validation: %s[/color]" % [skill_data.skill_name, validation_result.reason])
		skill_failed.emit(caster, skill_data, validation_result.reason)
		if context.battle_manager and context.battle_manager.has_method("show_status_text"):
			context.battle_manager.show_status_text(caster, validation_result.reason, true)
		return {"error": validation_result.reason}

	print_rich("[color=lightblue]%s attempts to use skill: %s on %s[/color]" % [caster.character_name, skill_data.skill_name, selected_targets])
	skill_execution_started.emit(caster, skill_data, selected_targets)

	# 2. 消耗资源 (MP, 物品等)
	_consume_skill_resources(caster, skill_data)

	if not skill_data.cast_animation.is_empty():
		await caster.play_animation(skill_data.cast_animation)

	# 3. 异步执行技能效果处理
	# call_deferred("_process_skill_effects_async", skill_data, caster, selected_targets, context)
	var result = await _process_skill_effects_async(skill_data, caster, selected_targets, context)
	
	return result

## 尝试处理状态效果
func attempt_process_status_effects(effects : Array[SkillEffect], caster: Character, target: Character, context : SkillExecutionContext) -> Dictionary:
	var result = {"success": true, "reason": ""}
	for effect in effects:
		if not await _apply_single_effect(caster, target, effect, context):
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
		var _effect_result := await _process_effects_async(trigger_effects, status.source_character, [event_source], skill_context)
		skill_component.update_status_trigger_counts(status)

## 私有方法：验证技能可用性
func _validate_skill_usability(skill: SkillData, caster: Character, targets: Array[Character], context: SkillExecutionContext) -> Dictionary:
	var result = {"is_usable": true, "reason": ""}

	# 检查MP消耗
	if caster.current_mp < skill.mp_cost:
		result.is_usable = false
		result.reason = "Not enough MP"
		return result
	
	# 检查技能冷却 (如果实现了冷却系统)
	# if skill.is_on_cooldown(caster):
	#    result.is_usable = false
	#    result.reason = "Skill on cooldown"
	#    return result

	# 检查目标选择是否有效
	# First, determine the actual list of targets based on skill's target type if not explicitly provided
	var actual_targets_for_validation : Array[Character] = targets
	match skill.target_type:
		SkillData.TargetType.NONE:
			actual_targets_for_validation = []
		SkillData.TargetType.SELF:
			actual_targets_for_validation = [caster]
		SkillData.TargetType.ALLY_SINGLE: # Renamed from SINGLE_ALLY, assumes excludes self
			if targets.is_empty() or not context.battle_manager.get_valid_ally_targets(false, caster).has(targets[0]): # false for exclude self
				result.is_usable = false
				result.reason = "Invalid ally target (must be other ally)"
				return result
		SkillData.TargetType.ALLY_SINGLE_INC_SELF: # New case for ally including self
			if targets.is_empty() or not context.battle_manager.get_valid_ally_targets(true, caster).has(targets[0]):
				result.is_usable = false
				result.reason = "Invalid ally target (can be self)"
				return result
		SkillData.TargetType.ENEMY_SINGLE: # Renamed from SINGLE_ENEMY
			if targets.is_empty() or not context.battle_manager.get_valid_enemy_targets(caster).has(targets[0]):
				result.is_usable = false
				result.reason = "Invalid enemy target"
				return result
		SkillData.TargetType.ALLY_ALL: # Renamed from ALL_ALLIES, assumes excludes self
			actual_targets_for_validation = context.battle_manager.get_valid_ally_targets(false, caster) # false for exclude self
		SkillData.TargetType.ALLY_ALL_INC_SELF: # New case for all allies including self
			actual_targets_for_validation = context.battle_manager.get_valid_ally_targets(true, caster) # true for include self
		SkillData.TargetType.ENEMY_ALL: # Renamed from ALL_ENEMIES
			actual_targets_for_validation = context.battle_manager.get_valid_enemy_targets(caster)
		# Cases for EVERYONE, RANDOM_ENEMY, RANDOM_ALLY removed as they are not in SkillData.TargetType enum
		# Their logic needs to be handled elsewhere if still required.
		_:
			push_warning("SkillSystem: Unhandled or non-standard skill.target_type in _validate_skill_usability: %s. Skill: %s" % [skill.target_type, skill.skill_name])
			# Defaulting to no targets or could set unusable
			actual_targets_for_validation = [] 
			# result.is_usable = false # Or consider it unusable
			# result.reason = "Unknown target type"
			# return result
			pass

	if not _validate_skill_targets(skill, actual_targets_for_validation):
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

## 异步处理技能效果的核心逻辑 (使用 call_deferred 调用)
## [param context] 技能执行上下文
## [param caster] 施法者
## [param skill_data] 要使用的技能数据
## [param initial_selected_targets] 玩家或AI选择的目标
func _process_skill_effects_async(skill_data: SkillData, caster: Character, initial_selected_targets: Array[Character], context: SkillExecutionContext) -> Dictionary:
	# 确保在操作前，所有参与者仍然有效
	if not is_instance_valid(caster) or not skill_data:
		push_error("SkillSystem: Invalid caster or skill_data in _process_skill_effects_async.")
		return {}

	# 确定实际目标，考虑技能的目标类型
	var actual_execution_targets = _determine_execution_targets(caster, skill_data, initial_selected_targets, context)
	
	if actual_execution_targets.is_empty() and skill_data.target_type != SkillData.TargetType.NONE:
		push_warning("SkillSystem: No valid targets for skill '%s' at execution time." % skill_data.skill_name)
		skill_failed.emit(caster, skill_data, "no_valid_targets_at_execution")
		return {}

	# 播放施法动画/效果
	if context.battle_manager and context.battle_manager.has_method("play_casting_animation"):
		await context.battle_manager.play_casting_animation(caster, skill_data)
	else:
		# 如果没有视觉效果处理器，添加一个短暂延迟以模拟施法时间
		await get_tree().create_timer(0.5).timeout

	# 处理每个效果
	var overall_results = await _process_effects_async(skill_data.effects, caster, actual_execution_targets, context)

	# 发出技能执行完成信号
	skill_execution_completed.emit(caster, skill_data, actual_execution_targets, overall_results)
	print_rich("[color=lightgreen]%s's skill '%s' execution completed.[/color]" % [caster.character_name, skill_data.skill_name])
	return overall_results

## 异步处理技能效果
## [param effects] 要应用的效果列表
## [param caster] 施法者
## [param targets] 目标列表
## [param context] 技能执行上下文
## [return] 效果应用结果
func _process_effects_async(effects: Array[SkillEffect], caster: Character, targets: Array[Character], context: SkillExecutionContext) -> Dictionary:
	# 对每个目标应用所有效果
	var overall_results = {}
	for target in targets:
		if not is_instance_valid(target):
			continue # 跳过无效目标
			
		overall_results[target] = {}
		
		# 处理技能的每个效果
		for effect in effects:
			# 确定该效果的实际目标 (可能与技能主目标不同)
			var effect_targets = _determine_targets_for_effect(caster, effect, [target], context)
			
			for effect_target in effect_targets:
				if not is_instance_valid(effect_target):
					continue
					
				# 应用单个效果
				var effect_result = await _apply_single_effect(caster, effect_target, effect, context)
				
				# 合并结果
				for key in effect_result:
					overall_results[target][key] = effect_result[key]
				
				# 添加短暂延迟，使效果看起来更自然
				await get_tree().create_timer(0.1).timeout
	
	return overall_results

## 应用单个效果
## [param caster] 施法者
## [param target] 目标角色
## [param effect] 效果数据
## [param context] 技能执行上下文
## [return] 效果应用结果
func _apply_single_effect(caster: Character, target: Character, effect: SkillEffect, context: SkillExecutionContext) -> Dictionary:
	# 检查参数有效性
	if !is_instance_valid(caster) or !is_instance_valid(target):
		push_error("SkillSystem: 无效的角色引用")
		return {}
	
	if not effect:
		push_error("SkillSystem: 无效的效果引用")
		return {}
	
	# 处理效果
	var result = await effect.process_effect(caster, target, context)
		
	# 发出信号
	effect_applied.emit(effect, caster, target, result)
	return result

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
		match skill.target_type:
			SkillData.TargetType.SELF:
				if is_instance_valid(caster) and (caster.is_alive or skill.can_target_dead):
					final_targets.append(caster)
			SkillData.TargetType.ALLY_ALL:
				final_targets = context.battle_manager.get_valid_ally_targets(false, caster)
			SkillData.TargetType.ALLY_ALL_INC_SELF:
				final_targets = context.battle_manager.get_valid_ally_targets(true, caster)
			SkillData.TargetType.ENEMY_ALL:
				final_targets = context.battle_manager.get_valid_enemy_targets(caster)
			_:
				push_warning("SkillSystem: Unhandled skill.target_type in _determine_execution_targets: %s" % skill.target_type)
				# Could implement a fallback here

	# 过滤掉无效目标
	var valid_targets: Array[Character] = []
	for target in final_targets:
		if is_instance_valid(target) and (target.is_alive or skill.can_target_dead):
			valid_targets.append(target)

	return valid_targets

## 确定效果的目标
## [param context] 技能执行上下文
## [param caster] 施法者
## [param effect] 效果数据
## [param initial_targets] 初始目标
## [return] 效果的实际目标
func _determine_targets_for_effect(caster: Character, effect: SkillEffect, initial_targets: Array[Character], context : SkillExecutionContext) -> Array[Character]:
	# 默认使用技能的目标
	var effect_targets: Array[Character] = initial_targets.duplicate()
	
	# 如果效果有特殊的目标覆盖规则，可以在这里处理
	# 例如，某些效果可能会影响主目标周围的敌人，或者只影响施法者自己
	
	# 示例：如果效果有target_override属性，可以根据它来确定目标
	if effect.target_override != "none":
		var override_type = effect.target_override
		match override_type:
			"self_only":
				effect_targets = [caster] if is_instance_valid(caster) else []
			"all_allies":
				effect_targets = context.battle_manager.get_valid_ally_targets(true, caster)
			"all_enemies":
				effect_targets = context.battle_manager.get_valid_enemy_targets(caster)
			"main_target_and_adjacent":
				# 这需要位置信息，这里只是示例
				if not initial_targets.is_empty():
					var main_target = initial_targets[0]
					effect_targets = [main_target]
					# 添加相邻目标的逻辑...
	
	return effect_targets
