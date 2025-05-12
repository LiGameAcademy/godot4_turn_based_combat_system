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
var effect_processors : Dictionary[SkillEffect.EffectType, EffectProcessor] = {
	SkillEffect.EffectType.DAMAGE: DamageEffectProcessor.new(battle_manager, visual_effects),
	SkillEffect.EffectType.HEAL: HealingEffectProcessor.new(battle_manager, visual_effects)
}

# 要加载的处理器路径
const PROCESSORS = {
	"damage": "res://scripts/core/effect_processors/damage_effect_processor.gd",
	"heal": "res://scripts/core/effect_processors/healing_effect_processor.gd"
}

func _init(battle_mgr = null, visual_fx = null):
	battle_manager = battle_mgr
	visual_effects = visual_fx
	
	# 连接自身的信号用于处理视觉效果请求
	visual_effect_requested.connect(_on_visual_effect_requested)

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
		# 添加技能元素属性到效果参数
		effect.element = skill_data.element
		
		if effect.effect_type in effect_processors:
			print("处理效果: " + str(effect.effect_type))
			var processor = effect_processors[effect.effect_type]
			var effect_results = await processor.process_effect(effect, caster, targets)
				
			# 合并结果
			for target in effect_results:
				if not results.has(target):
					results[target] = {}
				for result_type in effect_results[target]:
					results[target][result_type] = effect_results[target][result_type]
		else:
			push_warning("未找到效果处理器: " + str(effect.effect_type))
	
	# 发出技能执行完成信号
	skill_executed.emit(caster, targets, skill_data, results)
	return results

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
