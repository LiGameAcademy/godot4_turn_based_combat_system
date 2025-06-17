extends Node
class_name BattleManager

const DAMAGE_NUMBER_SCENE : PackedScene = preload("res://scenes/ui/damage_number.tscn")

@onready var state_manager: BattleStateManager = $BattleStateManager

# 战斗参与者
var player_characters: Array[Character] = []
var enemy_characters: Array[Character] = []

# 回合顺序管理
var turn_queue: Array = []
var current_turn_character: Character = null
var is_player_turn : bool = false :
	get:
		return state_manager.current_state == BattleStateManager.BattleState.PLAYER_TURN
var effect_processors = {}		## 效果处理器

# 信号
signal turn_changed(character)
signal battle_ended(is_victory)
signal battle_info_logged(text)
signal skill_executed(caster : Character, targets : Array[Character], skill_data : SkillData, results : Dictionary)
signal effect_applied(effect_type : String, source : Character, target : Character, result : Dictionary)

func _ready():
	_init_effect_processors()
	state_manager.initialize(BattleStateManager.BattleState.IDLE)
	state_manager.state_changed.connect(_on_state_changed)

## 开始战斗
func start_battle() -> void:
	_log_battle_info("[color=yellow][b]===== 战斗开始! =====[/b][/color]")
	
	if player_characters.is_empty() or enemy_characters.is_empty():
		push_error("无法开始战斗：缺少玩家或敌人!")
		return
	state_manager.change_state(BattleStateManager.BattleState.START)

# 玩家选择行动
func player_select_action(action_type: String, target = null, skill_data: SkillData = null, targets : Array[Character] = []) -> void:
	print("玩家选择行动: ", action_type)
	
	# 执行选择的行动
	match action_type:
		"attack":
			if target and target is Character:
				_execute_attack(current_turn_character, target)
			else:
				# 默认选择第一个敌人作为目标
				var default_target = null
				for enemy in enemy_characters:
					if enemy.current_hp > 0:
						default_target = enemy
						break
						
				if default_target:
					_execute_attack(current_turn_character, default_target)
				else:
					print("错误：没有可用的目标")
					return
		"defend":
			_execute_defend(current_turn_character)
		"skill":
			var skill_targets : Array[Character] = targets
			if skill_targets.is_empty():
				skill_targets.append(target)
			_execute_skill(current_turn_character, skill_targets, skill_data)
		_:
			print("未知行动类型: ", action_type)
			return
	# 检查战斗是否结束
	if check_battle_end_condition():
		return # 战斗已结束
	state_manager.change_state(BattleStateManager.BattleState.TURN_END)

# 执行敌人AI
func execute_enemy_ai() -> void:
	# 简单的AI逻辑：总是攻击第一个存活的玩家角色
	var target = null
	for player in player_characters:
		if player.current_hp > 0:
			target = player
			break
			
	if target:
		_log_battle_info("[color=orange][b]{0}[/b][/color] 选择攻击 [color=blue][b]{1}[/b][/color]".format([current_turn_character.character_name, target.character_name]))
		_execute_attack(current_turn_character, target)
	else:
		_log_battle_info("[color=red][错误][/color] 敌人找不到可攻击的目标")
		
	# 检查战斗是否结束
	if check_battle_end_condition():
		return # 战斗已结束
	
	state_manager.change_state(BattleStateManager.BattleState.TURN_END)

# 检查战斗结束条件
func check_battle_end_condition() -> bool:
	# 检查玩家是否全部阵亡
	var all_players_defeated = true
	for player in player_characters:
		if player.current_hp > 0:
			all_players_defeated = false
			break
			
	# 检查敌人是否全部阵亡
	var all_enemies_defeated = true
	for enemy in enemy_characters:
		if enemy.current_hp > 0:
			all_enemies_defeated = false
			break
			
	# 判断战斗结果
	if all_players_defeated:
		# 玩家全部阵亡，战斗失败
		state_manager.change_state(BattleStateManager.BattleState.DEFEAT)
		return true
	if all_enemies_defeated:
		# 敌人全部阵亡，战斗胜利
		state_manager.change_state(BattleStateManager.BattleState.VICTORY)
		return true
	return false

# 添加和管理角色
func add_player_character(character: Character) -> void:
	if not player_characters.has(character):
		player_characters.append(character)
		_log_battle_info("[color=blue][玩家注册][/color] 添加角色: [color=cyan][b]{0}[/b][/color]".format([character.character_name]))

func add_enemy_character(character: Character) -> void:
	if not enemy_characters.has(character):
		enemy_characters.append(character)
		_log_battle_info("[color=red][敌人注册][/color] 添加角色: [color=orange][b]{0}[/b][/color]".format([character.character_name]))

func remove_character(character: Character) -> void:
	if player_characters.has(character):
		player_characters.erase(character)
	if enemy_characters.has(character):
		enemy_characters.erase(character)
	if turn_queue.has(character):
		turn_queue.erase(character)
		
	_log_battle_info("[color=gray][b]{0}[/b] 已从战斗中移除[/color]".format([character.character_name]))
	check_battle_end_condition()

## 生成伤害数字
func spawn_damage_number(position: Vector2, amount: int, color : Color) -> void:
	var damage_number = DAMAGE_NUMBER_SCENE.instantiate()
	get_parent().add_child(damage_number)
	damage_number.global_position = position + Vector2(0, -50)
	damage_number.show_number(str(amount), color)

# MP检查和消耗
func check_and_consume_mp(caster: Character, skill: SkillData) -> bool:
	if caster.current_mp < skill.mp_cost:
		print_rich("[color=red]魔力不足，法术施放失败！[/color]")
		return false
	
	caster.use_mp(skill.mp_cost)
	return true

# 获取有效的敌方目标列表（过滤掉已倒下的角色）
func get_valid_enemy_targets() -> Array[Character]:
	var valid_targets: Array[Character] = []
	
	for enemy in enemy_characters:
		if enemy.is_alive:
			valid_targets.append(enemy)
	
	return valid_targets

# 获取有效的友方目标列表
# include_self: 是否包括施法者自己
func get_valid_ally_targets(include_self: bool = false) -> Array[Character]:
	var valid_targets: Array[Character] = []
	
	for ally in player_characters:
		if ally.is_alive && (include_self || ally != current_turn_character):
			valid_targets.append(ally)
	
	return valid_targets

## 注册效果处理器
func register_effect_processor(processor: EffectProcessor):
	var processor_id = processor.get_processor_id()
	effect_processors[processor_id] = processor
	print("注册效果处理器: %s" % processor_id)

# 应用多个效果
func apply_effects(effects: Array, source: Character, targets: Array) -> Dictionary:
	var all_results = {}

	for target in targets:
		if !is_instance_valid(target) or target.current_hp <= 0:
			continue
		
		all_results[target] = {}
		
		for effect in effects:
			var result = await _apply_effect(effect, source, target)
			for key in result:
				all_results[target][key] = result[key]
	
	return all_results
#region 执行动作
# 执行攻击
func _execute_attack(attacker: Character, target: Character) -> void:
	_log_battle_info("[color=purple][战斗行动][/color] [color=orange][b]{0}[/b][/color] 攻击 [color=cyan][b]{1}[/b][/color]".format([attacker.character_name, target.character_name]))
	
	var damage : float = attacker.attack_power - target.defense_power

	var final_damage = target.take_damage(damage)

	# 显示伤害数字
	spawn_damage_number(target.global_position, final_damage, Color.RED)

	# 检查战斗是否结束
	check_battle_end_condition()
	
# 执行防御
func _execute_defend(character: Character) -> void:
	if character == null:
		return

	_log_battle_info("[color=purple][战斗行动][/color] [color=cyan][b]{0}[/b][/color] 选择[color=teal][防御][/color]，受到的伤害将减少".format([character.character_name]))
	# TODO: 实现防御逻辑，可能是添加临时buff或设置状态
	character.set_defending(true)

## 执行技能 - 由BattleScene调用
func _execute_skill(caster: Character, custom_targets: Array[Character], skill_data: SkillData) -> Dictionary:
	if not is_instance_valid(caster) or not skill_data:
		push_error("SkillSystem: 无效的施法者或技能")
		return {}
	
	# 检查MP消耗
	if not skill_data.can_cast(caster.current_mp):
		push_error("SkillSystem: MP不足，无法施放技能")
		return {"error": "mp_not_enough"}
	
	# 扣除MP
	if skill_data.mp_cost > 0:
		caster.use_mp(skill_data.mp_cost)
	
	# 获取目标
	var targets = custom_targets if !custom_targets.is_empty() else _get_targets_for_skill(skill_data)
	
	if targets.is_empty():
		push_warning("SkillSystem: 没有有效目标")
		return {"error": "no_valid_targets"}
	
	# 播放施法动画
	if skill_data.cast_animation != "":
		_play_cast_animation(caster)
	
	# 等待短暂时间（供动画播放）
	if Engine.get_main_loop():
		await Engine.get_main_loop().process_frame

	# 处理直接效果
	var effect_results = {}
	if not skill_data.effects.is_empty():
		effect_results = await apply_effects(skill_data.effects, caster, targets)

	# 合并结果
	var final_results = {}
	for target in targets:
		final_results[target] = {}
		
		if effect_results.has(target):
			for key in effect_results[target]:
				final_results[target][key] = effect_results[target][key]
	
	# 发送技能执行信号
	skill_executed.emit(caster, targets, skill_data, final_results)
	return final_results

# 应用单个效果
func _apply_effect(effect: SkillEffectData, source: Character, target: Character) -> Dictionary:
	# 检查参数有效性
	if !is_instance_valid(source) or !is_instance_valid(target):
		push_error("SkillSystem: 无效的角色引用")
		return {}
	
	if not effect:
		push_error("SkillSystem: 无效的效果引用")
		return {}
	
	# 获取对应的处理器
	var processor_id = _get_processor_id_for_effect(effect)
	var processor = effect_processors.get(processor_id)
	
	if processor and processor.can_process_effect(effect):
		# 使用处理器处理效果
		var result = await processor.process_effect(effect, source, target)
		
		# 发出信号
		effect_applied.emit(effect.effect_type, source, target, result)
		return result
	else:
		push_error("无效的效果处理器: ", processor_id)
		return {}

## 根据效果类型获取处理器ID
func _get_processor_id_for_effect(effect: SkillEffectData) -> String:
	match effect.effect_type:
		SkillEffectData.EffectType.DAMAGE:
			return "damage"
		SkillEffectData.EffectType.HEAL:
			return "heal"
		SkillEffectData.EffectType.STATUS:
			return "status"
		SkillEffectData.EffectType.DISPEL:
			return "dispel"
		SkillEffectData.EffectType.SPECIAL:
			return "special"
		_:
			return "unknown"

# 在初始化方法中注册新的效果处理器
func _init_effect_processors():
	# 注册处理器
	register_effect_processor(DamageEffectProcessor.new(self))
	register_effect_processor(HealingEffectProcessor.new(self))
	register_effect_processor(ApplyStatusProcessor.new(self))

func _get_targets_for_skill(skill: SkillData) -> Array[Character]:
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

func _calculate_skill_damage(caster: Character, target: Character, skill: SkillData) -> int:
	# 基础伤害计算
	var base_damage = skill.power + (caster.magic_attack * 0.8)
	
	# 考虑目标防御
	var damage_after_defense = base_damage - (target.magic_defense * 0.5)
	
	# 加入随机浮动因素 (±10%)
	var random_factor = randf_range(0.9, 1.1)
	var final_damage = damage_after_defense * random_factor
	
	# 确保伤害至少为1
	return max(1, round(final_damage))

func _calculate_skill_healing(caster: Character, _target: Character, skill: SkillData) -> int:
	# 治疗量通常更依赖施法者的魔法攻击力
	var base_healing = skill.power + (caster.magic_attack * 1.0)
	
	# 随机浮动 (±5%)
	var random_factor = randf_range(0.95, 1.05)
	var final_healing = base_healing * random_factor
	
	return max(1, round(final_healing))

#endregion

## 构建回合队列
func _build_turn_queue() -> void:
	# 清空当前队列
	turn_queue.clear()
	
	# 将所有存活的角色添加到队列中
	for character in player_characters:
		if character.current_hp > 0:
			turn_queue.append(character)
			
	for character in enemy_characters:
		if character.current_hp > 0:
			turn_queue.append(character)
	
	# 根据速度属性排序
	turn_queue.sort_custom(func(a, b): return a.speed > b.speed)
	
	_log_battle_info("[color=yellow][战斗系统][/color] 回合队列已建立: [color=green][b]{0}[/b][/color] 个角色".format([turn_queue.size()]))


## 战斗日志
func _log_battle_info(text: String) -> void:
	print_rich(text)
	battle_info_logged.emit(text)

#region 视觉反馈
# 状态效果应用视觉反馈
func _play_status_effect(target: Character, params: Dictionary = {}) -> void:
	#var status_type = params.get("status_type", "buff")
	var is_positive = params.get("is_positive", true)
	
	var effect_color = Color(0.7, 1, 0.7) if is_positive else Color(1, 0.7, 0.7)
	
	var tween = create_tween()
	tween.tween_property(target, "modulate", effect_color, 0.2)
	
	# 正面状态上升效果，负面状态下沉效果
	var original_pos = target.position
	var offset = Vector2(0, -4) if is_positive else Vector2(0, 4)
	tween.tween_property(target, "position", original_pos + offset, 0.1)
	tween.tween_property(target, "position", original_pos, 0.1)
	
	# 恢复正常颜色
	tween.tween_property(target, "modulate", Color(1, 1, 1), 0.2)
	
	# 如果有指定动画，则播放
	if target.has_method("play_animation") and "animation" in params:
		target.play_animation(params["animation"])

func _play_cast_animation(caster: Character) -> void:
	var tween = create_tween()
	# 角色短暂发光效果
	tween.tween_property(caster, "modulate", Color(1.5, 1.5, 1.5), 0.2)
	tween.tween_property(caster, "modulate", Color(1, 1, 1), 0.2)
	
	# 这里可以播放施法音效
	# AudioManager.play_sfx("spell_cast")

## 播放施法动画
func _play_heal_cast_animation(caster: Character) -> void:
	_play_cast_animation(caster)

## 播放命中动画
func _play_hit_animation(target: Character):
	var tween = create_tween()
	
	# 目标变红效果
	tween.tween_property(target, "modulate", Color(2, 0.5, 0.5), 0.1)
	
	# 抖动效果
	var original_pos = target.position
	tween.tween_property(target, "position", original_pos + Vector2(5, 0), 0.05)
	tween.tween_property(target, "position", original_pos - Vector2(5, 0), 0.05)
	tween.tween_property(target, "position", original_pos, 0.05)
	
	# 恢复正常颜色
	tween.tween_property(target, "modulate", Color(1, 1, 1), 0.1)
	
	# 这里可以播放命中音效
	# AudioManager.play_sfx("hit_impact")

func _play_cast_effect(_target: Character, _params: Dictionary = {}) -> void:
	pass

func _play_heal_cast_effect(_target: Character, _params: Dictionary = {}) -> void:
	pass

# 治疗效果视觉反馈
func _play_heal_effect(target: Character, _params : Dictionary = {}):
	var tween = create_tween()
	
	# 目标变绿效果（表示恢复）
	tween.tween_property(target, "modulate", Color(0.7, 1.5, 0.7), 0.2)
	
	# 上升的小动画，暗示"提升"
	var original_pos = target.position
	tween.tween_property(target, "position", original_pos - Vector2(0, 5), 0.2)
	tween.tween_property(target, "position", original_pos, 0.1)
	
	# 恢复正常颜色
	tween.tween_property(target, "modulate", Color(1, 1, 1), 0.2)

func _play_hit_effect(_target: Character, _params: Dictionary = {}) -> void:
	pass

func _play_damage_number_effect(target: Character, params: Dictionary = {}) -> void:
	spawn_damage_number(target.global_position, params.get("damage", 0), params.get("color", Color.RED))

func _play_status_applied_success_effect(_target: Character, _params: Dictionary = {}) -> void:
	pass

#endregion

#region 信号处理

# 角色死亡信号处理函数
func _on_character_died(character: Character) -> void:
	print_rich("[color=purple]" + character.character_name + " 已被击败![/color]")
	
	# 从相应列表中移除
	if player_characters.has(character):
		player_characters.erase(character)
	elif enemy_characters.has(character):
		enemy_characters.erase(character)
	
	# 从回合队列中移除
	if turn_queue.has(character):
		turn_queue.erase(character)
	
	# 如果当前行动者死亡，需要特殊处理
	if current_turn_character == character:
		print("当前行动者 " + character.character_name + " 已阵亡。")
	
	# 检查战斗是否结束
	check_battle_end_condition()	

## 状态改变处理函数
func _on_state_changed(_previous_state: BattleStateManager.BattleState, new_state: BattleStateManager.BattleState) -> void:
	# 所有状态下的动作逻辑都在这里
	match new_state:
		BattleStateManager.BattleState.START:
			state_manager.change_state(BattleStateManager.BattleState.ROUND_START)
		BattleStateManager.BattleState.ROUND_START:
			# 大回合开始，构建回合队列
			_log_battle_info("[color=yellow][战斗系统][/color] 新的回合开始")
			if check_battle_end_condition():
				# 战斗已结束，状态已在check_battle_end_condition中切换
				return
				
			_build_turn_queue()
			if turn_queue.is_empty():
				state_manager.change_state(BattleStateManager.BattleState.DEFEAT)
			else:
				state_manager.change_state(BattleStateManager.BattleState.TURN_START)
				
		BattleStateManager.BattleState.TURN_START:
			# 小回合开始，确定当前行动角色
			if turn_queue.is_empty():
				# 所有角色都行动完毕，回合结束
				state_manager.change_state(BattleStateManager.BattleState.ROUND_END)
				return
				
			current_turn_character = turn_queue.pop_front()
			_log_battle_info("[color=cyan][回合][/color] [color=orange][b]{0}[/b][/color] 的回合开始".format([current_turn_character.character_name]))
			current_turn_character.reset_turn_flags()
			# 根据角色类型决定下一个状态
			var next_state = BattleStateManager.BattleState.PLAYER_TURN if player_characters.has(current_turn_character) else BattleStateManager.BattleState.ENEMY_TURN
			state_manager.change_state(next_state)
			turn_changed.emit(current_turn_character) # 通知UI
			
		BattleStateManager.BattleState.PLAYER_TURN:
			pass
						
		BattleStateManager.BattleState.ENEMY_TURN:
			await get_tree().create_timer(1.0).timeout
			execute_enemy_ai()
			
		BattleStateManager.BattleState.TURN_END:
			# 小回合结束，检查战斗状态
			if check_battle_end_condition():
				# 战斗已结束，状态已在check_battle_end_condition中切换
				return
			current_turn_character.process_active_statuses(self)
			# 进入下一个角色的回合
			state_manager.change_state(BattleStateManager.BattleState.TURN_START)
			
		BattleStateManager.BattleState.ROUND_END:
			# 大回合结束，进入新的回合
			_log_battle_info("[color=yellow][战斗系统][/color] 回合结束")
			state_manager.change_state(BattleStateManager.BattleState.ROUND_START)
		BattleStateManager.BattleState.VICTORY:
			_log_battle_info("[color=green][b]===== 战斗胜利! =====[/b][/color]")
			battle_ended.emit(true)
		BattleStateManager.BattleState.DEFEAT:
			_log_battle_info("[color=red][b]===== 战斗失败... =====[/b][/color]")
			battle_ended.emit(false)
#endregion
