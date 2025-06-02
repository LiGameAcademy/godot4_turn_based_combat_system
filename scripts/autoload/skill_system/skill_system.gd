extends Node

## 技能系统
## 作为自动加载的单例，负责技能执行的核心逻辑
## 不直接依赖战斗系统组件，而是通过上下文获取必要的信息

# 效果处理器
var _effect_processors: Dictionary[StringName, EffectProcessor] = {}
## 当前选中的技能 (如果需要由 SkillSystem 管理选择状态)
var current_selected_skill : SkillData = null

# 信号
signal skill_execution_started(caster: Character, skill: SkillData, targets: Array[Character])
signal skill_execution_completed(caster: Character, skill: SkillData, targets: Array[Character], results: Dictionary) # results 可以包含伤害、治疗、状态等信息
signal skill_failed(caster: Character, skill: SkillData, reason: String) # 例如 MP不足, 目标无效等
signal effect_applied(effect_type, source, target, result)
#signal effect_processed(effect_type, source, target, result) # 效果处理完成后发出，包含完整的结果信息

# 游戏事件信号 - 用于触发状态效果
signal game_event_occurred(event_type: StringName, context: Dictionary)

# 视觉效果请求信号
signal visual_effect_requested(effect_type: StringName, target: Node, params: Dictionary)

## 技能执行上下文
## 包含执行技能所需的所有依赖和上下文信息
class SkillExecutionContext:
	var character_registry: BattleCharacterRegistryManager
	var visual_effects_handler: BattleVisualEffects
	
	func _init(
			p_registry: BattleCharacterRegistryManager, 
			p_vfx_handler: BattleVisualEffects) -> void:
		character_registry = p_registry
		visual_effects_handler = p_vfx_handler

func _ready() -> void:
	_init_effect_processors()
	print("SkillSystem initialized as autoload singleton.")

#region --- 公共API ---

## 注册效果处理器
## [param processor] 要注册的效果处理器
## [return] 是否成功注册
func register_effect_processor(processor: EffectProcessor) -> void:
	if processor and processor.has_method("get_processor_id") and processor.has_method("process_effect"):
		var processor_id = processor.get_processor_id()
		_effect_processors[processor_id] = processor
		print("SkillSystem: Registered effect processor for type: %s" % processor_id)
	else:
		push_error("SkillSystem: Failed to register invalid effect processor.")

## 触发游戏事件
## [param event_type] 事件类型，如 "on_damage_taken", "on_turn_start", "on_attack" 等
## [param context] 事件上下文，包含事件相关的所有信息
func trigger_game_event(event_type: StringName, context: Dictionary) -> void:
	# 发出游戏事件信号
	game_event_occurred.emit(event_type, context)
	
	# 打印事件日志（调试用）
	print_rich("[color=purple]游戏事件触发: %s[/color]" % event_type)
	# 事件处理完成后清空上下文
	await get_tree().process_frame

## 应用效果集
## [param source_character] 效果来源角色
## [param target_character] 目标角色
## [param effects] 效果数组
## [param skill_data] 可选的技能数据
## [param context] 执行上下文，包含额外信息
## [return] 效果应用结果
func apply_effects(
		source_character: Character, 
		target_character: Character, 
		effects: Array[SkillEffectData], 
		skill_data: SkillData = null, 
		context: Dictionary = {}) -> Dictionary:
	var results = {}
	
	if not is_instance_valid(source_character) or not is_instance_valid(target_character):
		return {"success": false, "error": "无效的角色引用"}
	
	for effect in effects:
		var effect_result = await _apply_single_effect(source_character, target_character, effect, skill_data, context)
		results[effect.get_instance_id()] = effect_result
	
	return {"success": true, "effect_results": results}

## 尝试执行一个技能
## [param context] 技能执行上下文
## [param caster] 施法者
## [param skill_data] 要使用的技能数据
## [param selected_targets] 玩家或AI选择的目标
## [return] 是否成功执行技能
func attempt_execute_skill(context: SkillExecutionContext, caster: Character, skill_data: SkillData, selected_targets: Array[Character]) -> bool:
	if not is_instance_valid(caster) or not skill_data:
		push_error("Invalid caster or skill_data for skill execution.")
		skill_failed.emit(caster, skill_data, "invalid_caster_or_skill")
		return false

	# 1. 验证施法条件 (MP, 冷却, 目标等)
	var validation_result = _validate_skill_usability(context, caster, skill_data, selected_targets)
	if not validation_result.is_usable:
		print_rich("[color=orange]Skill '%s' failed validation: %s[/color]" % [skill_data.skill_name, validation_result.reason])
		skill_failed.emit(caster, skill_data, validation_result.reason)
		if context.visual_effects_handler and context.visual_effects_handler.has_method("show_status_text"):
			context.visual_effects_handler.show_status_text(caster, validation_result.reason, true)
		return false

	print_rich("[color=lightblue]%s attempts to use skill: %s on %s[/color]" % [caster.character_name, skill_data.skill_name, selected_targets])
	skill_execution_started.emit(caster, skill_data, selected_targets)

	# 2. 消耗资源 (MP, 物品等)
	_consume_skill_resources(caster, skill_data)

	# 3. 异步执行技能效果处理
	call_deferred("_process_skill_effects_async", context, caster, skill_data, selected_targets)
	
	return true

## 获取有效的友方目标
## [param context] 技能执行上下文
## [param caster] 施法者
## [param include_self] 是否包含施法者自己
## [return] 可以作为目标的友方角色列表
func get_valid_ally_targets(
		context: SkillExecutionContext, 
		caster: Character, 
		include_self: bool) -> Array[Character]:
	var allies = context.character_registry.get_allied_team_for_character(caster, include_self)
	var valid_targets: Array[Character] = []
	for ally in allies:
		if ally.is_alive:
			valid_targets.append(ally)
	return valid_targets

## 获取有效的敌方目标
## [param context] 技能执行上下文
## [param caster] 施法者
## [return] 可以作为目标的敌方角色列表
func get_valid_enemy_targets(
		context: SkillExecutionContext, 
		caster: Character) -> Array[Character]:
	var enemies = context.character_registry.get_opposing_team_for_character(caster)
	var valid_targets: Array[Character] = []
	for enemy in enemies:
		if enemy.is_alive:
			valid_targets.append(enemy)
	return valid_targets

## 处理状态的持续效果
## [param context] 技能执行上下文
## [param status] 状态数据
## [param character] 拥有状态的角色
## [return] 效果处理结果
func process_status_ongoing_effects(status: SkillStatusData, character: Character) -> Dictionary:
	return await _process_status_effects(status.ongoing_effects, status, character)

## 处理状态的结束效果
## [param context] 技能执行上下文
## [param status] 状态数据
## [param character] 拥有状态的角色
## [return] 效果处理结果
func process_status_end_effects(status: SkillStatusData, character: Character) -> Dictionary:
	return await _process_status_effects(status.end_effects, status, character)

## 请求视觉效果
## [param effect_type] 效果类型
## [param target] 目标节点
## [param params] 参数字典
func request_visual_effect(effect_type: StringName, target: Node, params: Dictionary = {}) -> void:
	# 发送视觉效果请求信号
	visual_effect_requested.emit(effect_type, target, params)

#endregion --- 公共API ---

#region --- 私有方法 ---
# 在初始化方法中注册新的效果处理器
func _init_effect_processors() -> void:
	# 注册处理器
	register_effect_processor(DamageEffectProcessor.new())
	register_effect_processor(HealingEffectProcessor.new())
	register_effect_processor(ApplyStatusProcessor.new())
	register_effect_processor(DispelStatusProcessor.new())
	register_effect_processor(ModifyDamageEffectProcessor.new())

## 根据效果类型获取处理器ID
func _get_effect_processor_for_type(effect: SkillEffectData) -> EffectProcessor:
	match effect.effect_type:
		SkillEffectData.EffectType.DAMAGE:
			return _effect_processors.get("damage")
		SkillEffectData.EffectType.HEAL:
			return _effect_processors.get("heal")
		SkillEffectData.EffectType.STATUS:
			return _effect_processors.get("status")
		SkillEffectData.EffectType.DISPEL:
			return _effect_processors.get("dispel")
		SkillEffectData.EffectType.MODIFY_DAMAGE:
			return _effect_processors.get("modify_damage")
		SkillEffectData.EffectType.SPECIAL:
			return _effect_processors.get("special")
		_:
			return null

## 私有方法：验证技能可用性
func _validate_skill_usability(context: SkillExecutionContext, caster: Character, skill: SkillData, targets: Array[Character]) -> Dictionary:
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
			if targets.is_empty() or not context.character_registry.get_allied_team_for_character(caster, false).has(targets[0]): # false for exclude self
				result.is_usable = false
				result.reason = "Invalid ally target (must be other ally)"
				return result
		SkillData.TargetType.ALLY_SINGLE_INC_SELF: # New case for ally including self
			if targets.is_empty() or not context.character_registry.get_allied_team_for_character(caster, true).has(targets[0]):
				result.is_usable = false
				result.reason = "Invalid ally target (can be self)"
				return result
		SkillData.TargetType.ENEMY_SINGLE: # Renamed from SINGLE_ENEMY
			if targets.is_empty() or not context.character_registry.get_opposing_team_for_character(caster).has(targets[0]):
				result.is_usable = false
				result.reason = "Invalid enemy target"
				return result
		SkillData.TargetType.ALLY_ALL: # Renamed from ALL_ALLIES, assumes excludes self
			actual_targets_for_validation = get_valid_ally_targets(context, caster, false) # false for exclude self
		SkillData.TargetType.ALLY_ALL_INC_SELF: # New case for all allies including self
			actual_targets_for_validation = get_valid_ally_targets(context, caster, true) # true for include self
		SkillData.TargetType.ENEMY_ALL: # Renamed from ALL_ENEMIES
			actual_targets_for_validation = get_valid_enemy_targets(context, caster)
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

	if not _validate_skill_targets(caster, skill, actual_targets_for_validation):
		result.is_usable = false
		result.reason = "Invalid target(s) for skill scope"
		return result
		
	# # 检查施法者是否处于无法施法的状态 (例如：沉默、眩晕)
	# if caster.has_status(&"Silenced") or caster.has_status(&"Stunned"): # 假设有这些状态ID
	# 	result.is_usable = false
	# 	result.reason = "Cannot cast (Silenced/Stunned)"
	# 	return result

	return result

## 私有方法：验证技能目标 (after initial target list is determined)
func _validate_skill_targets(_caster: Character, skill: SkillData, targets: Array[Character]) -> bool:
	if skill.target_type == SkillData.TargetType.NONE:
		return true
	
	if targets.is_empty() and skill.target_type != SkillData.TargetType.NONE:
		# This case should ideally be caught by the more specific target type checks in _validate_skill_usability
		# but as a fallback:
		if skill.target_type != SkillData.TargetType.ALLY_ALL and \
		   skill.target_type != SkillData.TargetType.ALLY_ALL_INC_SELF and \
		   skill.target_type != SkillData.TargetType.ENEMY_ALL:
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
func _consume_skill_resources(caster: Character, skill: SkillData) -> void:
	if skill.mp_cost > 0:
		caster.use_mp(skill.mp_cost, skill) # Character类应有 use_mp 方法
	
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
func _process_skill_effects_async(context: SkillExecutionContext, caster: Character, skill_data: SkillData, initial_selected_targets: Array[Character]) -> void:
	# 确保在操作前，所有参与者仍然有效
	if not is_instance_valid(caster) or not skill_data:
		push_error("SkillSystem: Invalid caster or skill_data in _process_skill_effects_async.")
		return

	# 确定实际目标，考虑技能的目标类型
	var actual_execution_targets = _determine_execution_targets(context, caster, skill_data, initial_selected_targets)
	
	if actual_execution_targets.is_empty() and skill_data.target_type != SkillData.TargetType.NONE:
		push_warning("SkillSystem: No valid targets for skill '%s' at execution time." % skill_data.skill_name)
		skill_failed.emit(caster, skill_data, "no_valid_targets_at_execution")
		return

	# 播放施法动画/效果
	if context.visual_effects_handler and context.visual_effects_handler.has_method("play_casting_animation"):
		await context.visual_effects_handler.play_casting_animation(caster, skill_data)
	else:
		# 如果没有视觉效果处理器，添加一个短暂延迟以模拟施法时间
		await get_tree().create_timer(0.5).timeout

	# 处理每个效果
	var overall_results = {}
	
	# 对每个目标应用所有效果
	for target in actual_execution_targets:
		if not is_instance_valid(target):
			continue # 跳过无效目标
			
		overall_results[target] = {}
		
		# 处理技能的每个效果
		for effect in skill_data.effects:
			# 确定该效果的实际目标 (可能与技能主目标不同)
			var effect_targets = _determine_targets_for_effect(context, caster, skill_data, effect, [target])
			
			for effect_target in effect_targets:
				if not is_instance_valid(effect_target):
					continue
					
				# 应用单个效果
				var effect_result = await _apply_single_effect(caster, effect_target, effect, skill_data, {"skill_execution_context": context})
				
				# 合并结果
				for key in effect_result:
					overall_results[target][key] = effect_result[key]
				
				# 触发视觉效果
				_trigger_visual_effect(context, effect, caster, effect_target, effect_result)
				
				# 添加短暂延迟，使效果看起来更自然
				await get_tree().create_timer(0.1).timeout

	# 发出技能执行完成信号
	skill_execution_completed.emit(caster, skill_data, actual_execution_targets, overall_results)
	print_rich("[color=lightgreen]%s's skill '%s' execution completed.[/color]" % [caster.character_name, skill_data.skill_name])

## 应用单个效果
## [param caster] 施法者
## [param target] 目标角色
## [param effect] 效果数据
## [param skill] 技能数据
## [param context] 执行上下文，包含额外信息
## [return] 效果应用结果
func _apply_single_effect(caster: Character, target: Character, effect: SkillEffectData, skill: SkillData, context: Dictionary = {}) -> Dictionary:
	# 检查参数有效性
	if !is_instance_valid(caster) or !is_instance_valid(target):
		push_error("SkillSystem: 无效的角色引用")
		return {}
	
	if not effect:
		push_error("SkillSystem: 无效的效果引用")
		return {}
	
	# 准备执行上下文
	var execution_context = context.duplicate()
	# 添加标准字段
	if not execution_context.has("source_character"):
		execution_context["source_character"] = caster
	if not execution_context.has("primary_target"):
		execution_context["primary_target"] = target
	if skill and not execution_context.has("skill_data"):
		execution_context["skill_data"] = skill
	
	# 获取对应的处理器
	var processor = _get_effect_processor_for_type(effect)
	
	if processor and processor.can_process_effect(effect):
		# 使用处理器处理效果
		var result = await processor.process_effect(effect, caster, target, execution_context)
		
		# 发出信号
		effect_applied.emit(effect.effect_type, caster, target, result)
		return result
	else:
		push_error("SkillSystem: 无效的效果处理器")
		return {}

## 确定实际目标
## [param context] 技能执行上下文
## [param caster] 施法者
## [param skill] 要使用的技能数据
## [param selected_targets] 玩家或AI选择的目标
## [return] 实际目标数组
func _determine_execution_targets(context: SkillExecutionContext, caster: Character, skill: SkillData, selected_targets: Array[Character]) -> Array[Character]:
	var final_targets: Array[Character] = []
	match skill.target_type:
		SkillData.TargetType.NONE:
			pass # No targets
		SkillData.TargetType.SELF:
			if is_instance_valid(caster) and (caster.is_alive or skill.can_target_dead):
				final_targets.append(caster)
		SkillData.TargetType.ALLY_SINGLE: # Renamed from SINGLE_ALLY, assumes excludes self
			if not selected_targets.is_empty() and is_instance_valid(selected_targets[0]) and \
			   context.character_registry.get_allied_team_for_character(caster, false).has(selected_targets[0]) and \
			   (selected_targets[0].is_alive or skill.can_target_dead):
				final_targets.append(selected_targets[0])
		SkillData.TargetType.ALLY_SINGLE_INC_SELF: # New case for ally including self
			if not selected_targets.is_empty() and is_instance_valid(selected_targets[0]) and \
			   context.character_registry.get_allied_team_for_character(caster, true).has(selected_targets[0]) and \
			   (selected_targets[0].is_alive or skill.can_target_dead):
				final_targets.append(selected_targets[0])
		SkillData.TargetType.ENEMY_SINGLE: # Renamed from SINGLE_ENEMY
			if not selected_targets.is_empty() and is_instance_valid(selected_targets[0]) and (selected_targets[0].is_alive or skill.can_target_dead):
				final_targets.append(selected_targets[0])
		SkillData.TargetType.ALLY_ALL: # Renamed from ALL_ALLIES, assumes excludes self
			final_targets = get_valid_ally_targets(context, caster, false) # false for exclude self
		SkillData.TargetType.ALLY_ALL_INC_SELF: # New case for all allies including self
			final_targets = get_valid_ally_targets(context, caster, true) # true for include self
		SkillData.TargetType.ENEMY_ALL: # Renamed from ALL_ENEMIES
			final_targets = get_valid_enemy_targets(context, caster)
		# Cases for EVERYONE, RANDOM_ENEMY, RANDOM_ALLY removed as they are not in SkillData.TargetType enum
		# Their logic needs to be handled elsewhere if still required.
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
## [param skill] 技能数据
## [param effect] 效果数据
## [param initial_targets] 初始目标
## [return] 效果的实际目标
func _determine_targets_for_effect(context: SkillExecutionContext, caster: Character, _skill: SkillData, effect: SkillEffectData, initial_targets: Array[Character]) -> Array[Character]:
	# 默认使用技能的目标
	var effect_targets: Array[Character] = initial_targets.duplicate()
	
	# 如果效果有特殊的目标覆盖规则，可以在这里处理
	# 例如，某些效果可能会影响主目标周围的敌人，或者只影响施法者自己
	
	# 示例：如果效果有target_override属性，可以根据它来确定目标
	if effect.has_meta("target_override"):
		var override_type = effect.get_meta("target_override")
		match override_type:
			"self_only":
				effect_targets = [caster] if is_instance_valid(caster) else []
			"all_allies":
				effect_targets = get_valid_ally_targets(context, caster, true)
			"all_enemies":
				effect_targets = get_valid_enemy_targets(context, caster)
			"main_target_and_adjacent":
				# 这需要位置信息，这里只是示例
				if not initial_targets.is_empty():
					var main_target = initial_targets[0]
					effect_targets = [main_target]
					# 添加相邻目标的逻辑...
	
	return effect_targets

## 触发视觉效果
func _trigger_visual_effect(context: SkillExecutionContext, effect_data: SkillEffectData, _caster: Character, target: Character, result: Dictionary) -> void:
	if not context.visual_effects_handler:
		push_warning("SkillSystem: VisualEffects handler not set, cannot trigger visual effect.")
		return

	match effect_data.effect_type:
		SkillEffectData.EffectType.DAMAGE:
			if result.has("damage_dealt") and result.damage_dealt > 0:
				if context.visual_effects_handler.has_method("create_damage_number"):
					context.visual_effects_handler.create_damage_number(target, result.damage_dealt, false)
				if context.visual_effects_handler.has_method("play_hit_animation"):
					context.visual_effects_handler.play_hit_animation(target)
		SkillEffectData.EffectType.HEAL:
			if result.has("healing_done") and result.healing_done > 0:
				if context.visual_effects_handler.has_method("create_damage_number"):
					context.visual_effects_handler.create_damage_number(target, result.healing_done, true)
				if context.visual_effects_handler.has_method("play_heal_animation"):
					context.visual_effects_handler.play_heal_animation(target)
		SkillEffectData.EffectType.STATUS:
			if result.has("status_applied") and result.status_applied:
				if context.visual_effects_handler.has_method("show_status_text"):
					context.visual_effects_handler.show_status_text(target, result.status_id, true)
		SkillEffectData.EffectType.DISPEL:
			if result.has("status_removed") and result.status_removed:
				if context.visual_effects_handler.has_method("show_status_text"):
					context.visual_effects_handler.show_status_text(target, "Dispelled: " + result.status_id, true)
		SkillEffectData.EffectType.SPECIAL:
			if result.has("special_vfx_text"):
				if context.visual_effects_handler.has_method("show_status_text"):
					context.visual_effects_handler.show_status_text(target, result.special_vfx_text, true)

## 处理状态效果的辅助方法
## [param context] 技能执行上下文
## [param effect_list] 效果列表
## [param status] 状态数据
## [param character] 拥有状态的角色
## [return] 效果处理结果
func _process_status_effects(effect_list: Array, status: SkillStatusData, character: Character) -> Dictionary:
	if not is_instance_valid(character) or not status:
		return {"success": false, "error": "无效的角色或状态"}
	
	var results = {"success": true, "effects_processed": []}
	
	# 创建一个虚拟技能数据作为占位符
	var dummy_skill = SkillData.new()
	dummy_skill.skill_name = "Status_%s_Effect" % status.status_name
	
	# 处理每个效果
	for effect in effect_list:
		if not effect:
			continue
		
		# 使用源角色和目标角色处理效果
		var source = status.source_character if is_instance_valid(status.source_character) else character
		var effect_result = await _apply_single_effect(source, character, effect, dummy_skill)
		
		results.effects_processed.append({
			"effect_type": effect.effect_type,
			"result": effect_result
		})
	
	return results

#endregion --- 私有方法 ---
