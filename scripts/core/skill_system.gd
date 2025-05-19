extends Node
class_name SkillSystem

# 系统引用
var battle_manager : BattleManager = null
var visual_effects : BattleVisualEffects= null

var effect_processors = {}		## 效果处理器

# 信号
signal skill_executed(caster, targets, skill, results)
signal visual_effect_requested(effect_type, target, params)
signal effect_applied(effect_type, source, target, result)
signal status_applied(status, source, target)
#signal status_removed(status, target)

func _init(battle_mgr = null, visual_fx = null):
	battle_manager = battle_mgr
	visual_effects = visual_fx

	# 初始化处理器
	_init_effect_processors()

	# 连接视觉效果请求信号
	visual_effect_requested.connect(_on_visual_effect_requested)

	print("SkillSystem初始化完成")
	
# 执行技能
func execute_skill(caster: Character, skill: SkillData, custom_targets: Array = []) -> Dictionary:
	# 检查参数
	if !is_instance_valid(caster) or !skill:
		push_error("SkillSystem: 无效的施法者或技能")
		return {}
	
	# 检查MP消耗
	if !skill.can_cast(caster):
		push_error("SkillSystem: MP不足，无法施放技能")
		return {"error": "mp_not_enough"}
	
	# 扣除MP
	caster.use_mp(skill.mp_cost)
	
	# 获取目标
	var targets = custom_targets if !custom_targets.is_empty() else get_targets_for_skill(caster, skill)
	
	if targets.is_empty():
		push_warning("SkillSystem: 没有有效目标")
		return {"error": "no_valid_targets"}
	
	# 播放施法动画
	if skill.cast_animation != "":
		_request_animation(caster, skill.cast_animation)
	
	# 请求施法视觉效果
	visual_effect_requested.emit("cast", caster, {"element": skill.element})
	
	# 等待短暂时间（供动画播放）
	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame

	# 处理直接效果
	var effect_results = {}
	if !skill.direct_effects.is_empty():
		effect_results = await apply_effects(skill.direct_effects, caster, targets)

	# 合并结果
	var final_results = {}
	for target in targets:
		final_results[target] = {}
		
		if effect_results.has(target):
			for key in effect_results[target]:
				final_results[target][key] = effect_results[target][key]
	
	# 发送技能执行信号
	skill_executed.emit(caster, targets, skill, final_results)
	
	return final_results

# 应用单个效果
func apply_effect(effect: SkillEffectData, source: Character, target: Character) -> Dictionary:
	# 检查参数有效性
	if !is_instance_valid(source) or !is_instance_valid(target):
		push_error("SkillSystem: 无效的角色引用")
		return {}
	
	if !effect:
		push_error("SkillSystem: 无效的效果引用")
		return {}
	
	# 获取对应的处理器
	var processor_id = get_processor_id_for_effect(effect)
	var processor = effect_processors.get(processor_id)
	
	if processor and processor.can_process_effect(effect):
		# 使用处理器处理效果
		var result = await processor.process_effect(effect, source, target)
		
		# 发出信号
		effect_applied.emit(effect.effect_type, source, target, result)
		
		return result
	else:
		push_error("SkillSystem: 无效的效果处理器")
		return {}

# 应用多个效果
func apply_effects(effects: Array, source: Character, targets: Array) -> Dictionary:
	var all_results = {}

	for target in targets:
		if !is_instance_valid(target) or target.current_hp <= 0:
			continue
		
		all_results[target] = {}
		
		for effect in effects:
			var result = await apply_effect(effect, source, target)
			for key in result:
				all_results[target][key] = result[key]
	
	return all_results

# 获取技能的目标
func get_targets_for_skill(caster: Character, skill: SkillData) -> Array:
	if !battle_manager:
		push_error("SkillSystem: 未设置战斗管理器")
		return []
	
	var targets = []
	var target_type = skill.target_type
	
	match target_type:
		SkillData.TargetType.SELF:
			targets = [caster]
		
		SkillData.TargetType.SINGLE_ENEMY:
			# 获取一个有效的敌方目标
			targets = _get_valid_enemy_targets(caster)
			if !targets.is_empty():
				targets = [targets[0]]  # 只取第一个敌人
		
		SkillData.TargetType.SINGLE_ALLY:
			# 获取一个有效的友方目标（不包括自己）
			targets = _get_valid_ally_targets(caster, false)
			if !targets.is_empty():
				targets = [targets[0]]  # 只取第一个友方
		
		SkillData.TargetType.ALL_ENEMIES:
			# 获取所有有效的敌方目标
			targets = _get_valid_enemy_targets(caster)
		
		SkillData.TargetType.ALL_ALLIES:
			# 获取所有有效的友方目标（不包括自己）
			targets = _get_valid_ally_targets(caster, false)
		
		SkillData.TargetType.ALL_ALLIES_EXCEPT_SELF:
			# 获取除自己外的所有友方目标
			targets = _get_valid_ally_targets(caster, false)
		
		SkillData.TargetType.ALL:
			# 获取所有角色
			targets = _get_valid_enemy_targets(caster) + _get_valid_ally_targets(caster, true)
	
	return targets

## 注册效果处理器
func register_effect_processor(processor: EffectProcessor):
	var processor_id = processor.get_processor_id()
	effect_processors[processor_id] = processor
	print("注册效果处理器: %s" % processor_id)

## 根据效果类型获取处理器ID
func get_processor_id_for_effect(effect: SkillEffectData) -> String:
	match effect.effect_type:
		SkillEffectData.EffectType.DAMAGE:
			return "damage"
		SkillEffectData.EffectType.HEAL:
			return "heal"
		SkillEffectData.EffectType.ATTRIBUTE_MODIFY:
			return "attribute"
		SkillEffectData.EffectType.STATUS:
			return "status"
		SkillEffectData.EffectType.DISPEL:
			return "dispel"
		SkillEffectData.EffectType.SPECIAL:
			return "special"
		_:
			return "unknown"

## 获取战斗管理器
func get_battle_manager():
	return battle_manager

## 获取有效的敌方单位
func get_valid_enemy_targets(caster: Character) -> Array:
	return _get_valid_enemy_targets(caster)

## 获取有效的友方单位
func get_valid_ally_targets(caster: Character, include_self: bool = true) -> Array:
	return _get_valid_ally_targets(caster, include_self)

## 私有方法: 触发视觉效果
func _trigger_visual_effect(effect: SkillEffectData, _source: Character, target: Character, result: Dictionary) -> void:
	if !visual_effects:
		return
	
	match effect.effect_type:
		SkillEffectData.EffectType.DAMAGE:
			if visual_effects.has_method("play_damage_effect"):
				visual_effects.play_damage_effect(target, {
					"amount": result.get("amount", 0),
					"element": result.get("element", 0)
				})
		
		SkillEffectData.EffectType.HEAL:
			if visual_effects.has_method("play_heal_effect"):
				visual_effects.play_heal_effect(target, {
					"amount": result.get("amount", 0)
				})
		
		SkillEffectData.EffectType.STATUS:
			if visual_effects.has_method("play_status_applied"):
				visual_effects.play_status_applied(target, {
					"status_id": result.get("status_id", 0)
				})
		
		SkillEffectData.EffectType.ATTRIBUTE_MODIFY:
			if visual_effects.has_method("play_attribute_modify_effect"):
				visual_effects.play_attribute_modify_effect(target, {
					"attribute": result.get("attribute", "none"),
					"value": result.get("value", 0),
					"is_percent": result.get("is_percent", false)
				})
	
	# 如果效果有自定义视觉效果
	if effect.visual_effect != "":
		if visual_effects.has_method("play_custom_effect"):
			visual_effects.play_custom_effect(target, {
				"effect_name": effect.visual_effect,
				"effect_params": effect.params
			})

# 在初始化方法中注册新的效果处理器
func _init_effect_processors():
	# 注册处理器
	register_effect_processor(DamageEffectProcessor.new(self, visual_effects))
	register_effect_processor(HealingEffectProcessor.new(self, visual_effects))
	register_effect_processor(StatusEffectProcessor.new(self, visual_effects))
	register_effect_processor(DispelEffectProcessor.new(self, visual_effects))

#region 辅助函数
## 获取有效的敌方目标
func _get_valid_enemy_targets(caster: Character) -> Array:
	if !battle_manager:
		return []
	
	var targets = []
	var enemy_list = []
	
	# 确定敌人列表
	if battle_manager.is_player_character(caster):
		enemy_list = battle_manager.enemy_characters
	else:
		enemy_list = battle_manager.player_characters
	
	# 过滤出存活的敌人
	for enemy in enemy_list:
		if enemy.is_alive:
			targets.append(enemy)
	
	return targets

## 获取有效的友方目标
func _get_valid_ally_targets(caster: Character, include_self: bool = true) -> Array:
	if !battle_manager:
		return []
	
	var targets = []
	var ally_list = []
	
	# 确定友方列表
	if battle_manager.is_player_character(caster):
		ally_list = battle_manager.player_characters
	else:
		ally_list = battle_manager.enemy_characters
	
	# 过滤出存活的友方
	for ally in ally_list:
		if ally.is_alive and (include_self or ally != caster):
			targets.append(ally)
	
	return targets

## 请求播放动画
## [param character] 角色
## [param animation_name] 动画名称
func _request_animation(character: Character, animation_name: String) -> void:
	if character.has_method("play_animation"):
		character.play_animation(animation_name)

## 处理视觉效果请求
func _on_visual_effect_requested(effect_type: String, target, params: Dictionary = {}):
	if not visual_effects or not is_instance_valid(target):
		return
		
	# 分发到适当的视觉效果方法
	if visual_effects.has_method("play_" + effect_type + "_effect"):
		var method = "play_" + effect_type + "_effect"
		visual_effects.call(method, target, params)
	else:
		push_warning("SkillSystem: 未找到视觉效果方法 play_" + effect_type + "_effect")
#endregion
