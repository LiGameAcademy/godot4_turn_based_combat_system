# scripts/core/skill_system.gd
extends Node
class_name SkillSystem

# 信号
signal skill_executed(caster, targets, skill_data, results)
signal visual_effect_requested(effect_type, target, params)

# 类型定义
enum VisualEffectType {CAST, HIT, HEAL, STATUS, EFFECTIVE_HIT, INEFFECTIVE_HIT, DAMAGE_NUMBER}

# 引用和资源
var battle_manager = null
var visual_effects = null
var effect_processors = {}

func _init(battle_mgr = null, visual_fx = null):
	battle_manager = battle_mgr
	visual_effects = visual_fx
	
	# 初始化处理器
	_init_effect_processors()
	
	visual_effect_requested.connect(_on_visual_effect_requested)

# 在初始化方法中注册新的效果处理器
func _init_effect_processors():
	# 注册处理器
	register_effect_processor(DamageEffectProcessor.new(battle_manager, visual_effects))
	register_effect_processor(HealingEffectProcessor.new(battle_manager, visual_effects))
	register_effect_processor(StatusEffectProcessor.new(battle_manager, visual_effects))
	register_effect_processor(ControlEffectProcessor.new(battle_manager, visual_effects))

# 处理视觉效果请求
func _on_visual_effect_requested(effect_type: String, target, params: Dictionary = {}):
	if not visual_effects or not is_instance_valid(target):
		return
		
	# 分发到适当的视觉效果方法
	match effect_type:
		"cast":
			visual_effects.play_cast_effect(target, params)
		"hit":
			visual_effects.play_hit_effect(target, params)
		"effective_hit":
			visual_effects.play_effective_hit_effect(target, params)
		"ineffective_hit":
			visual_effects.play_ineffective_hit_effect(target, params)
		"heal":
			visual_effects.play_heal_effect(target, params)
		"heal_cast":
			visual_effects.play_heal_cast_effect(target, params)
		"status":
			visual_effects.play_status_effect(target, params)
		"status_applied":
			visual_effects.play_status_effect_applied(target, params)
		"status_resist":
			visual_effects.play_status_resist(target, params)
		"control_applied":
			visual_effects.play_control_applied(target, params)
		"control_resist":
			visual_effects.play_control_resist(target, params)
		"damage_number":
			# 处理伤害数字显示，获取所需参数
			var damage = params.get("damage", 0)
			var color = params.get("color", Color.RED)
			var prefix = params.get("prefix", "")
			
			# 如果目标是角色，使用其位置；否则，尝试直接使用传入的位置
			var position = target.global_position if target is Node2D else params.get("position", Vector2.ZERO)
			
			visual_effects.spawn_damage_number(position, damage, color, prefix)
		_:
			push_warning("未知的视觉效果类型: " + effect_type)

# 执行技能
func execute_skill(caster: Character, targets: Array[Character], skill_data: SkillData) -> Dictionary:
	print(caster.character_name + " 使用技能：" + skill_data.skill_name)
	
	var results = {}
	
	# 检查MP并消耗
	if !check_and_consume_mp(caster, skill_data):
		print("错误：MP不足，无法释放技能！")
		return results
	
	# 通知角色状态更新 (MP消耗)
	if battle_manager and battle_manager.has_signal("character_stats_changed"):
		battle_manager.character_stats_changed.emit(caster)
	
	# 获取技能所有效果
	var effects : Array[SkillEffect] = skill_data.get_effects()
	
	# 逐个处理每个效果
	for effect in effects:
		var processor_id = get_processor_id_for_effect(effect)
		if effect_processors.has(processor_id):
			var processor = effect_processors[processor_id]
			var effect_results = await processor.process_effect(effect, caster, targets)
				
			# 合并结果
			for target in effect_results:
				if not results.has(target):
					results[target] = {}
				for result_type in effect_results[target]:
					results[target][result_type] = effect_results[target][result_type]
		else:
			push_error("未找到效果处理器: %s" % processor_id)
	
	# 处理状态效果 - 如果技能有指定状态效果ID
	if skill_data.status_effect_id != "" and !targets.is_empty():
		apply_status_effect(caster, targets, skill_data)
	
	# 发出技能执行完成信号
	skill_executed.emit(caster, targets, skill_data, results)
	return results

# 新增：应用状态效果
func apply_status_effect(caster: Character, targets: Array[Character], skill_data: SkillData) -> void:
	# 如果没有状态效果ID，直接返回
	if skill_data.status_effect_id.is_empty():
		return
	
	# 尝试加载状态效果资源
	var effect_resource_path = "res://godot4_turn_based_combat_system/resources/status_effects/" + skill_data.status_effect_id + ".tres"
	var effect_data = load(effect_resource_path)
	
	if not effect_data or not effect_data is StatusEffectData:
		push_warning("无法加载状态效果数据: " + effect_resource_path)
		return
	
	# 对每个目标尝试应用状态效果
	for target in targets:
		# 检查是否满足应用状态效果的条件
		var chance = skill_data.status_effect_chance  # 从技能数据中获取成功率
		if chance <= 0:
			chance = 100  # 默认100%成功
		
		# 随机概率判定
		var roll = randf() * 100
		if roll <= chance:
			# 应用状态效果
			var effect = target.add_status_effect(effect_data, caster)
			
			if effect:
				print(target.character_name + " 受到了 " + effect_data.effect_name + " 状态效果！")
				
				# 播放状态效果应用的视觉特效
				if visual_effects:
					visual_effects.play_status_effect_applied(target, effect_data)
		else:
			print(target.character_name + " 抵抗了 " + effect_data.effect_name + " 状态效果！")

# 检查并消耗魔法值
func check_and_consume_mp(caster: Character, skill: SkillData) -> bool:
	if caster.current_mp < skill.mp_cost:
		print_rich("[color=red]魔力不足，法术施放失败！[/color]")
		return false
	
	caster.use_mp(skill.mp_cost)
	return true

# 生成技能描述
func generate_skill_description(skill_data: SkillData) -> String:
	var desc = skill_data.description
	
	# 自动生成描述 (如果未手动设置)
	if desc.begins_with("技能描述") or desc.strip_edges().is_empty():
		desc = skill_data.skill_name + ": "
		
		var effects : Array[SkillEffect] = skill_data.get_effects()
		var effect_descs = []
		
		for effect in effects:
			if effect.effect_type in effect_processors:
				var processor = effect_processors[effect.effect_type]
				effect_descs.append(processor.get_effect_description(effect))
		
		desc += ", ".join(effect_descs)
		
		# 添加魔法消耗
		desc += " (消耗MP: " + str(skill_data.mp_cost) + ")"
		
		# 添加元素类型
		if skill_data.element > 0:
			var element_name = ElementTypes.get_element_name(skill_data.element)
			desc += " [" + element_name + "属性]"
	
	return desc

# === 目标选择系统 ===

# 获取有效的敌方目标列表
func get_valid_enemy_targets() -> Array[Character]:
	if not battle_manager:
		return []
		
	var enemies : Array[Character] = []
	for enemy in battle_manager.enemy_characters:
		if enemy.is_alive():
			enemies.append(enemy)
			
	return enemies

# 获取有效的友方目标列表
func get_valid_ally_targets(include_current_turn_character: bool = false) -> Array[Character]:
	if not battle_manager:
		return []
		
	var allies : Array[Character] = []
	var current = battle_manager.current_turn_character
	
	for ally in battle_manager.player_characters:
		if ally.is_alive() and (include_current_turn_character or ally != current):
			allies.append(ally)
			
	return allies

# 根据技能获取目标
func get_targets_for_skill(skill: SkillData) -> Array[Character]:
	if not battle_manager or not battle_manager.current_turn_character:
		return []
		
	var current_turn_character = battle_manager.current_turn_character
	var targets: Array[Character] = []
	
	match skill.target_type:
		SkillData.TargetType.NONE:
			# 无目标技能
			pass
			
		SkillData.TargetType.SELF:
			# 自身为目标
			targets = [current_turn_character]
			
		SkillData.TargetType.ENEMY_SINGLE:
			# 选择单个敌人（在实际游戏中应由玩家交互选择）
			# 此处简化为自动选择第一个活着的敌人
			var valid_targets = get_valid_enemy_targets()
			if !valid_targets.is_empty():
				targets = [valid_targets[0]]
				
		SkillData.TargetType.ENEMY_ALL:
			# 所有活着的敌人
			targets = get_valid_enemy_targets()
			
		SkillData.TargetType.ALLY_SINGLE:
			# 选择单个友方（不包括自己）
			# 简化为自动选择第一个活着的友方
			var valid_targets = get_valid_ally_targets(false)
			if !valid_targets.is_empty():
				targets = [valid_targets[0]]
				
		SkillData.TargetType.ALLY_ALL:
			# 所有活着的友方（不包括自己）
			targets = get_valid_ally_targets(false)
			
		SkillData.TargetType.ALLY_SINGLE_INC_SELF:
			# 选择单个友方（包括自己）
			# 简化为选择自己
			targets = [current_turn_character]
			
		SkillData.TargetType.ALLY_ALL_INC_SELF:
			# 所有活着的友方（包括自己）
			targets = get_valid_ally_targets(true)
	
	return targets

## 注册效果处理器
func register_effect_processor(processor: EffectProcessor):
	var processor_id = processor.get_processor_id()
	effect_processors[processor_id] = processor
	print("注册效果处理器: %s" % processor_id)

## 根据效果类型获取处理器ID
func get_processor_id_for_effect(effect: SkillEffect) -> String:
	match effect.effect_type:
		SkillEffect.EffectType.DAMAGE:
			return "damage"
		SkillEffect.EffectType.HEAL:
			return "heal"
		SkillEffect.EffectType.APPLY_STATUS:
			return "apply_status"
		SkillEffect.EffectType.CONTROL:
			return "control"
		_:
			return "unknown"
