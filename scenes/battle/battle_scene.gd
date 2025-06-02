extends Node2D
class_name BattleScene

## 战斗管理器和战斗UI引用
@onready var battle_manager: BattleManager = %BattleManager
@onready var battle_ui: BattleUI = $BattleUI
@onready var background: TextureRect = $Background
@onready var battle_music_player: AudioStreamPlayer = $BattleMusicPlayer
@onready var battle_transition: BattleTransition = $BattleTransition

## 当前战斗数据
var battle_data: BattleData = null

## 当前选中的技能，用于BattleScene内部状态管理
var current_selected_skill: SkillData = null

## 当前回合数
var current_turn_count: int = 0

## 是否已初始化
var _initialized: bool = false

func _ready() -> void:
	# 确保UI组件已正确引用
	if !battle_ui:
		push_error("BattleScene: BattleUI not found")
		return
	
	# 连接BattleUI信号
	_connect_battle_ui_signals()
	
	# 连接BattleManager信号
	_connect_battle_manager_signals()
	
	# 初始化战斗过渡效果
	_init_battle_transition()
	
	# 如果已经有战斗数据，则自动初始化
	if battle_data:
		initialize_battle(battle_data)
		
	for c in get_node("PlayerArea").get_children():
		c.queue_free()
	for c in get_node("EnemyArea").get_children():
		c.queue_free()

## 初始化战斗场景
func initialize_battle(data: BattleData) -> bool:
	# 验证战斗数据
	if not data or not data.is_valid():
		push_error("BattleScene: Invalid battle data")
		return false
	
	# 如果已经初始化，则先重置
	if _initialized:
		_reset_battle()
	
	# 保存战斗数据
	battle_data = data
	current_turn_count = 0
	
	# 设置战斗背景
	if background and battle_data.battle_background:
		background.texture = battle_data.battle_background
	
	# 设置战斗音乐
	if battle_music_player and battle_data.battle_music:
		battle_music_player.stream = battle_data.battle_music
		battle_music_player.play()
	
	# 初始化战斗管理器
	var success = _setup_battle_manager()
	if not success:
		return false
	
	# 连接所有角色的点击信号
	_connect_character_click_signals()
	
	# 更新UI
	battle_ui.update_battle_info(battle_data.battle_title)
	battle_ui.battle_log_panel.log_system(battle_data.battle_description)
	
	# 标记为已初始化
	_initialized = true
	
	# 播放战斗开始的淡出效果（屏幕变黑）
	#await play_battle_transition_fade_out()
	
	# 启动战斗
	battle_manager._start_battle()
	
	return true

## 重置战斗状态
func _reset_battle() -> void:
	# 重置战斗管理器
	battle_manager._reset()
	
	# 重置战斗UI
	battle_ui.reset()
	
	# 重置内部状态
	current_selected_skill = null
	current_turn_count = 0
	_initialized = false
	
	# 停止音乐
	if battle_music_player and battle_music_player.playing:
		battle_music_player.stop()

## 设置战斗管理器
func _setup_battle_manager() -> bool:
	# 初始化玩家角色
	var player_characters: Array[Character] = []
	if not battle_data.player_data_list.is_empty():
		# 使用战斗数据中的玩家角色
		for i in range(battle_data.player_data_list.size()):
			var char_data = battle_data.player_data_list[i]
			var cha_position = battle_data.player_positions[i] if i < battle_data.player_positions.size() else Vector2.ZERO
			var character = battle_manager.create_character(char_data, cha_position, true)
			player_characters.append(character)
	else:
		# 使用全局玩家队伍（这里可以连接到全局队伍管理器）
		# 示例代码，实际实现可能需要根据全局队伍管理器的API调整
		# player_characters = GlobalPartyManager.get_active_party()
		push_error("BattleScene: No player characters specified and global party not implemented")
		return false
	
	# 初始化敌人角色
	var enemy_characters: Array[Character] = []
	for i in range(battle_data.enemy_data_list.size()):
		var char_data = battle_data.enemy_data_list[i]
		var cha_position = battle_data.enemy_positions[i] if i < battle_data.enemy_positions.size() else Vector2.ZERO
		var character = battle_manager.create_character(char_data, cha_position, false)
		enemy_characters.append(character)
	
	# 设置最大回合数
	if battle_data.max_turn_count > 0:
		battle_manager.max_turn_count = battle_data.max_turn_count
	
	# 设置战斗管理器
	battle_manager.setup_battle(player_characters, enemy_characters)
	return true

## 连接战斗管理器信号
func _connect_battle_manager_signals() -> void:
	battle_manager.state_manager.state_changed.connect(_on_battle_state_changed)
	battle_manager.turn_changed.connect(_on_turn_changed)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.player_action_required.connect(_on_player_action_required)
	battle_manager.enemy_action_executed.connect(_on_enemy_action_executed)


## 连接BattleUI信号
func _connect_battle_ui_signals() -> void:
	# 连接行动菜单信号
	battle_ui.action_attack_pressed.connect(_on_action_menu_attack_pressed)
	battle_ui.action_defend_pressed.connect(_on_action_menu_defend_pressed)
	battle_ui.action_skill_pressed.connect(_on_skill_button_pressed)
	battle_ui.action_item_pressed.connect(_on_item_button_pressed)
	
	# 连接技能选择信号
	battle_ui.skill_selected.connect(_on_skill_selected)
	battle_ui.skill_selection_cancelled.connect(_on_skill_selection_cancelled)
	
	# 连接目标选择信号
	battle_ui.target_selected.connect(_on_target_selected)
	battle_ui.target_selection_cancelled.connect(_on_target_selection_cancelled)

# 处理BattleManager发出的信号
func _on_battle_state_changed(_old_state: BattleStateManager.BattleState, new_state: BattleStateManager.BattleState) -> void:
	match new_state:
		BattleStateManager.BattleState.PLAYER_TURN:
			# 当玩家回合开始时，战斗管理器会通过player_action_required信号通知
			pass
		BattleStateManager.BattleState.ENEMY_TURN:
			# 隐藏所有UI菜单
			battle_ui.hide_all_menus()
			battle_ui.update_battle_info("敌人回合...")
		BattleStateManager.BattleState.VICTORY:
			battle_ui.update_battle_info("战斗胜利！")
		BattleStateManager.BattleState.DEFEAT:
			battle_ui.update_battle_info("战斗失败...")


## 处理回合变化
func _on_turn_changed(character: Character) -> void:
	# 更新战斗信息
	battle_ui.update_battle_info(character.character_name + " 的回合")
	
	# 更新回合顺序显示
	var all_characters = battle_manager.get_all_characters()
	
	# 获取当前角色在列表中的索引
	var current_index = -1
	var current_character = battle_manager.turn_order_manager.current_character
	if current_character:
		current_index = all_characters.find(current_character)
	
	battle_ui.update_turn_order(all_characters, current_index)
	
	# 如果是战斗开始的第一个回合，播放淡入效果（屏幕恢复正常）
	if current_turn_count == 0:
		await play_battle_transition_fade_in()
		current_turn_count += 1

## 处理战斗结束
func _on_battle_ended(is_victory: bool) -> void:
	# 隐藏所有战斗UI
	battle_ui.hide_all_menus()
	
	# 播放战斗结束的淡出效果（屏幕变黑）
	await play_battle_transition_fade_out()
	
	# 更新战斗日志
	if is_victory:
		battle_ui.battle_log_panel.log_system("战斗胜利！")
	else:
		battle_ui.battle_log_panel.log_system("战斗失败...")
	
	# 可以在这里处理战斗结束后的逻辑，如显示结算界面等
	
	# 等待一些时间，然后播放淡入效果（屏幕恢复正常）
	await get_tree().create_timer(1.5).timeout
	await play_battle_transition_fade_in()


## 处理玩家行动请求
func _on_player_action_required(character: Character) -> void:
	# 显示行动菜单
	battle_ui.show_action_menu(character)
	battle_ui.update_battle_info("%s 的回合，请选择行动" % character.character_name)


## 处理敌人行动执行
func _on_enemy_action_executed(attacker: Character, target: Character, damage: int) -> void:
	# 更新战斗信息
	var info_text = attacker.character_name + " 对 " + target.character_name + " 造成了 " + str(damage) + " 点伤害!"
	battle_ui.update_battle_info(info_text)
	
	# 添加到战斗日志
	battle_ui.log_attack(attacker.character_name, target.character_name, damage)

# UI信号处理函数
func _on_action_menu_attack_pressed() -> void:
	if battle_manager.state_manager.is_in_state(BattleStateManager.BattleState.PLAYER_TURN):
		# 选择第一个存活的敌人作为目标
		var caster : Character = battle_manager.turn_order_manager.current_character
		var valid_targets = battle_manager.get_valid_enemy_targets(caster)
		if !valid_targets.is_empty():
			var target = valid_targets[0] # 这里简化为直接选择第一个敌人
			battle_manager.player_select_action(CharacterCombatComponent.ActionType.ATTACK, target)
			
			# 记录攻击日志
			battle_ui.log_attack(caster.character_name, target.character_name, 0) # 先记录攻击动作，实际伤害在执行时计算
		else:
			battle_ui.update_battle_info("没有可攻击的目标！")


func _on_action_menu_defend_pressed() -> void:
	if battle_manager.state_manager.is_in_state(BattleStateManager.BattleState.PLAYER_TURN):
		var character = battle_manager.turn_order_manager.current_character
		battle_manager.player_select_action(CharacterCombatComponent.ActionType.DEFEND)
		
		# 记录防御日志
		battle_ui.log_defend(character.character_name)


func _on_skill_button_pressed() -> void:
	if battle_manager.state_manager.is_in_state(BattleStateManager.BattleState.PLAYER_TURN):
		var character = battle_manager.turn_order_manager.current_character
		var success = battle_ui.show_skill_menu(character)
		
		if !success:
			battle_ui.update_battle_info("该角色没有可用的技能")


func _on_item_button_pressed() -> void:
	if battle_manager.state_manager.is_in_state(BattleStateManager.BattleState.PLAYER_TURN):
		battle_ui.update_battle_info("物品功能尚未实现")

## 处理技能选择
func _on_skill_selected(skill: SkillData) -> void:
	current_selected_skill = skill

	var caster : Character = battle_manager.turn_order_manager.current_character
	# 根据技能目标类型决定下一步操作
	match skill.target_type:
		SkillData.TargetType.SELF, \
		SkillData.TargetType.ENEMY_ALL, \
		SkillData.TargetType.ALLY_ALL, \
		SkillData.TargetType.ALLY_ALL_INC_SELF:
			# 自动目标技能，直接执行
			var params = {"skill": skill, "targets": []}
			battle_manager.player_select_action(CharacterCombatComponent.ActionType.SKILL, null, params)
			
			# 记录技能使用日志
			var target_names = []
			if skill.target_type == SkillData.TargetType.SELF:
				target_names = [caster.character_name]
			elif skill.target_type == SkillData.TargetType.ENEMY_ALL:
				var targets = battle_manager.get_valid_enemy_targets(caster)
				for target in targets:
					target_names.append(target.character_name)
			elif skill.target_type == SkillData.TargetType.ALLY_ALL or skill.target_type == SkillData.TargetType.ALLY_ALL_INC_SELF:
				var include_self = (skill.target_type == SkillData.TargetType.ALLY_ALL_INC_SELF)
				var targets = battle_manager.get_valid_ally_targets(caster, include_self)
				for target in targets:
					target_names.append(target.character_name)
			
			battle_ui.log_skill(caster.character_name, skill.skill_name, target_names, skill.description)
			
		SkillData.TargetType.ENEMY_SINGLE:
			# 显示敌人目标选择菜单
			var valid_targets := battle_manager.get_valid_enemy_targets(caster)
			if not valid_targets.is_empty():
				battle_ui.show_target_selection(valid_targets)
			else:
				battle_ui.update_battle_info("没有可选择的敌方目标！")
				_on_skill_selection_cancelled()
		
		SkillData.TargetType.ALLY_SINGLE:
			# 显示我方(不含自己)目标选择菜单
			var valid_targets = battle_manager.get_valid_ally_targets(caster, false)
			if !valid_targets.is_empty():
				battle_ui.show_target_selection(valid_targets)
			else:
				battle_ui.update_battle_info("没有可选择的友方目标！")
				_on_skill_selection_cancelled()
		
		SkillData.TargetType.ALLY_SINGLE_INC_SELF:  # 处理包含自己的单体友方目标选择
			# 显示我方(含自己)目标选择菜单
			var valid_targets = battle_manager.get_valid_ally_targets(caster, true)
			if !valid_targets.is_empty():
				battle_ui.show_target_selection(valid_targets)
			else:
				battle_ui.update_battle_info("没有可选择的友方目标！")
				_on_skill_selection_cancelled()
		_:
			battle_ui.update_battle_info("未处理的目标类型: " + str(skill.target_type))
			_on_skill_selection_cancelled()


## 处理技能选择取消
func _on_skill_selection_cancelled() -> void:
	# 重置当前选中的技能
	current_selected_skill = null
	
	# 返回到玩家行动选择状态
	var character = battle_manager.turn_order_manager.current_character
	battle_ui.show_action_menu(character)


## 当玩家选择了技能目标时调用
func _on_target_selected(target: Character) -> void:
	# 确保有选中的技能
	if current_selected_skill == null:
		push_error("选择了目标但没有当前技能")
		var character = battle_manager.turn_order_manager.current_character
		battle_ui.show_action_menu(character)
		return
	
	# 记录技能使用日志
	var caster = battle_manager.turn_order_manager.current_character
	battle_ui.log_skill(caster.character_name, current_selected_skill.skill_name, [target.character_name], current_selected_skill.description)
	
	# 覆盖技能的默认目标逻辑，强制使用玩家选择的目标
	var targets : Array[Character] = [target]
	var params = {"skill": current_selected_skill, "targets": targets}
	battle_manager.player_select_action(CharacterCombatComponent.ActionType.SKILL, target, params)


## 当玩家取消目标选择时调用
func _on_target_selection_cancelled() -> void:
	# 返回技能选择菜单
	# var skill = current_selected_skill
	current_selected_skill = null
	
	# 重新打开技能菜单
	var character = battle_manager.turn_order_manager.current_character
	var success = battle_ui.show_skill_menu(character)
	
	# 如果无法打开技能菜单，则返回到行动菜单
	if !success:
		battle_ui.show_action_menu(character)

## 连接所有角色的点击信号
func _connect_character_click_signals() -> void:
	# 获取所有玩家和敌人角色
	var all_characters = battle_manager.get_all_characters()
	
	# 连接每个角色的点击信号
	for character in all_characters:
		if character is Character:
			character.character_clicked.connect(_on_character_clicked)

## 处理角色点击事件
func _on_character_clicked(character: Character) -> void:
	# 显示角色详情
	battle_ui.show_character_details(character)


## 初始化战斗过渡效果
func _init_battle_transition() -> void:
	# 确保战斗过渡效果已正确引用
	if !battle_transition:
		push_error("BattleScene: BattleTransition not found")
		return
	
	# 初始时隐藏过渡效果
	#battle_transition.hide()

## 播放战斗过渡淡出效果（屏幕变黑）
func play_battle_transition_fade_out() -> void:
	if battle_transition:
		await battle_transition.play_fade_out()

## 播放战斗过渡淡入效果（屏幕恢复正常）
func play_battle_transition_fade_in() -> void:
	if battle_transition:
		await battle_transition.play_fade_in()
