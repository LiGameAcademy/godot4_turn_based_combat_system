extends Node
class_name BattleManager

## 战斗管理器
## 负责管理战斗的流程和状态

## 状态管理器
@onready var state_manager: BattleStateManager = $BattleStateManager

# 战斗参与者
var player_characters: Array[Character] = []			## 玩家角色列表
var enemy_characters: Array[Character] = []				## 敌人角色列表

# 回合顺序管理
var turn_queue: Array = []								## 回合队列
var current_turn_character: Character = null			## 当前行动者
var is_player_turn : bool = false :						## 是否是玩家回合
	get:
		return state_manager.current_state == BattleStateManager.BattleState.PLAYER_TURN
var effect_processors = {}								## 效果处理器

## 信号
signal turn_changed(character)							## 当前行动者改变时触发
signal battle_ended(is_victory)							## 战斗结束时触发
signal battle_info_logged(text)							## 战斗日志记录时触发

func _ready() -> void:
	state_manager.state_changed.connect(_on_state_changed)
	SkillSystem.battle_manager = self
	state_manager.initialize(BattleStateManager.BattleState.IDLE)

## 开始战斗
func start_battle() -> void:
	_log_battle_info("[color=yellow][b]===== 战斗开始! =====[/b][/color]")
	
	if player_characters.is_empty() or enemy_characters.is_empty():
		push_error("无法开始战斗：缺少玩家或敌人!")
		return
	state_manager.change_state(BattleStateManager.BattleState.START)

## 玩家选择行动 - 由BattleScene调用
## [param action_type] 行动类型
## [param target] 目标角色
## [param params] 行动参数
func player_select_action(
		action_type: CharacterCombatComponent.ActionType, 
		target: Character = null, 
		params: Dictionary = {}
		) -> void:
	if not state_manager.is_in_state(BattleStateManager.BattleState.PLAYER_TURN):
		print_rich("[color=red]当前不是玩家回合，无法选择行动![/color]")
		return
		
	print_rich("[color=cyan]玩家选择行动: %s[/color]" % action_type)
	
	params.merge({"skill_context": SkillExecutionContext.new(self)}, true)
	current_turn_character.execute_action(action_type, target, params)

	# 检查战斗是否结束
	if check_battle_end_condition():
		return # 战斗已结束
	state_manager.change_state(BattleStateManager.BattleState.TURN_END)

## 执行敌人AI
func execute_enemy_ai() -> void:
	# 简单的AI逻辑：总是攻击第一个存活的玩家角色
	var target = null
	for player in player_characters:
		if player.current_hp > 0:
			target = player
			break
	if target:
		_log_battle_info("[color=orange][b]{0}[/b][/color] 选择攻击 [color=blue][b]{1}[/b][/color]".format([current_turn_character.character_name, target.character_name]))
		current_turn_character.execute_action(CharacterCombatComponent.ActionType.ATTACK, target, {
			"skill_context": SkillExecutionContext.new(self)
		})
	else:
		_log_battle_info("[color=red][错误][/color] 敌人找不到可攻击的目标")
		
	# 检查战斗是否结束
	if check_battle_end_condition():
		return # 战斗已结束
	
	state_manager.change_state(BattleStateManager.BattleState.TURN_END)

## 检查战斗结束条件
## [return] 战斗是否结束
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

## 添加玩家角色
## [param character] 角色
func add_player_character(character: Character) -> void:
	if not player_characters.has(character):
		player_characters.append(character)
		_log_battle_info("[color=blue][玩家注册][/color] 添加角色: [color=cyan][b]{0}[/b][/color]".format([character.character_name]))

## 添加敌人角色
## [param character] 角色
func add_enemy_character(character: Character) -> void:
	if not enemy_characters.has(character):
		enemy_characters.append(character)
		_log_battle_info("[color=red][敌人注册][/color] 添加角色: [color=orange][b]{0}[/b][/color]".format([character.character_name]))

## 移除角色
## [param character] 角色
func remove_character(character: Character) -> void:
	if player_characters.has(character):
		player_characters.erase(character)
	if enemy_characters.has(character):
		enemy_characters.erase(character)
	if turn_queue.has(character):
		turn_queue.erase(character)
		
	_log_battle_info("[color=gray][b]{0}[/b] 已从战斗中移除[/color]".format([character.character_name]))
	check_battle_end_condition()

## 获取有效的敌方目标列表（过滤掉已倒下的角色）
## [param caster] 施法者
## [return] 有效的敌方目标列表
func get_valid_enemy_targets(caster : Character = null) -> Array[Character]:
	if caster == null:
		caster = current_turn_character
	var valid_targets: Array[Character] = []
	
	var enemies = enemy_characters if caster not in enemy_characters else player_characters
	for enemy in enemies:
		if enemy.is_alive and enemy != caster:
			valid_targets.append(enemy)
	
	return valid_targets

## 获取有效的友方目标列表
## [param include_self] 是否包括施法者自己
## [param caster] 施法者
## [return] 有效的友方目标列表
func get_valid_ally_targets(include_self: bool = false, caster : Character = null) -> Array[Character]:
	if caster == null:
		caster = current_turn_character
	var valid_targets: Array[Character] = []
	
	var allies = player_characters if caster in player_characters else enemy_characters
	for ally in allies:
		if ally.is_alive && (include_self || ally != caster):
			valid_targets.append(ally)
	
	return valid_targets

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
## [param text] 日志文本
func _log_battle_info(text: String) -> void:
	print_rich(text)
	battle_info_logged.emit(text)

#region 视觉反馈
## 状态效果应用视觉反馈
## [param target] 目标角色
## [param params] 参数
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

## 播放施法动画
## [param caster] 施法者
func _play_cast_animation(caster: Character) -> void:
	var tween = create_tween()
	# 角色短暂发光效果
	tween.tween_property(caster, "modulate", Color(1.5, 1.5, 1.5), 0.2)
	tween.tween_property(caster, "modulate", Color(1, 1, 1), 0.2)
	
	# 这里可以播放施法音效
	# AudioManager.play_sfx("spell_cast")

## 播放施法动画
## [param caster] 施法者
func _play_heal_cast_animation(caster: Character) -> void:
	_play_cast_animation(caster)

## 播放命中动画
## [param target] 目标角色
func _play_damage_effect(target: Character, _parames: Dictionary = {}) -> void:
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

## 播放施法效果
## [param target] 目标角色
## [param params] 参数
func _play_cast_effect(_target: Character, _params: Dictionary = {}) -> void:
	pass

## 播放治疗施法效果
## [param target] 目标角色
## [param params] 参数
func _play_heal_cast_effect(_target: Character, _params: Dictionary = {}) -> void:
	pass

## 治疗效果视觉反馈
## [param target] 目标角色
## [param params] 参数
func _play_heal_effect(target: Character, _params : Dictionary = {}) -> void:
	var tween = create_tween()
	
	# 目标变绿效果（表示恢复）
	tween.tween_property(target, "modulate", Color(0.7, 1.5, 0.7), 0.2)
	
	# 上升的小动画，暗示"提升"
	var original_pos = target.position
	tween.tween_property(target, "position", original_pos - Vector2(0, 5), 0.2)
	tween.tween_property(target, "position", original_pos, 0.1)
	
	# 恢复正常颜色
	tween.tween_property(target, "modulate", Color(1, 1, 1), 0.2)

## 受击效果视觉反馈
## [param target] 目标角色
## [param params] 参数
func _play_hit_effect(_target: Character, _params: Dictionary = {}) -> void:
	pass

## 状态效果应用成功视觉反馈
## [param target] 目标角色
## [param params] 参数
func _play_status_applied_success_effect(_target: Character, _params: Dictionary = {}) -> void:
	pass

## 受击数字效果
## [param target] 目标角色
## [param params] 参数
func _play_damage_number_effect(_target: Character, _params: Dictionary = {}) -> void:
	var damage : float = _params.get("damage", 0)
	var color : Color = _params.get("color", Color.RED)
	var prefix : String = _params.get("prefix", "")
	_target.spawn_damage_number(damage, color, prefix)

#endregion

#region 信号处理

## 角色死亡信号处理函数
## [param character] 角色
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
## [param _previous_state] 上一个状态
## [param new_state] 新状态
func _on_state_changed(
		_previous_state: BattleStateManager.BattleState, 
		new_state: BattleStateManager.BattleState) -> void:
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
			current_turn_character.on_turn_start(self)

			# 检查角色能否行动
			if not current_turn_character.can_action:
				_log_battle_info("[color=red][错误][/color] 角色无法行动, 跳过回合")
				state_manager.change_state(BattleStateManager.BattleState.TURN_END)
				return

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
			current_turn_character.on_turn_end(self)
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
