extends Node2D
class_name BattleScene

const CHARACTER = preload("res://scenes/characters/character.tscn")

## 战斗场景，负责战斗的UI显示和交互
@onready var player_area: Node2D = %PlayerArea
@onready var enemy_area: Node2D = %EnemyArea
@onready var battle_manager: BattleManager = %BattleManager
@onready var battle_ui : BattleUI = %BattleUI
@onready var stream_player: AudioStreamPlayer = $AudioStreamPlayer

var current_action : CharacterCombatComponent.ActionType
var current_selected_skill : SkillData

func _ready() -> void:
	# 连接战斗管理器信号
	battle_manager.turn_changed.connect(_on_turn_changed)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.battle_info_logged.connect(_on_battle_info_logged)
	# 链接BattleUI信号
	battle_ui.action_attack_pressed.connect(_on_action_attack_pressed)
	battle_ui.action_defend_pressed.connect(_on_action_defend_pressed)
	battle_ui.action_skill_pressed.connect(_on_action_skill_pressed)
	battle_ui.action_item_pressed.connect(_on_action_item_pressed)
	battle_ui.skill_selected.connect(_on_skill_selected)
	battle_ui.skill_selection_cancelled.connect(_on_skill_selection_cancelled)
	battle_ui.target_selected.connect(_on_target_selected)
	battle_ui.target_selection_cancelled.connect(_on_target_selection_cancelled)

func initialize_battle(battle_data: BattleData) -> void:
	for player in player_area.get_children():
		player.queue_free()

	for enemy in enemy_area.get_children():
		enemy.queue_free()

	for player_data in battle_data.player_data_list:
		var pos : Vector2 = battle_data.player_data_list[player_data]
		var player: Character = _spawn_character(player_data, pos)
		player_area.add_child(player)
		battle_manager.add_character(player, true)

	for enemy_data in battle_data.enemy_data_list:
		var pos : Vector2 = battle_data.enemy_data_list[enemy_data]
		var enemy: Character = _spawn_character(enemy_data, pos)
		enemy.is_player = false
		enemy_area.add_child(enemy)
		battle_manager.add_character(enemy, false)

	stream_player.stream = battle_data.battle_music
	stream_player.play()

	_connect_character_click_signals()
	battle_manager.start_battle()

# 显示/隐藏行动UI
func show_action_ui(should_show: bool) -> void:
	if should_show:
		battle_ui.show_action_menu(battle_manager.current_turn_character)
	else:
		battle_ui.hide_all_menus()

# 更新战斗信息
func update_battle_info(text: String) -> void:
	battle_ui.update_battle_info(text)

## 连接所有角色的点击信号
func _connect_character_click_signals() -> void:
	# 获取所有玩家和敌人角色
	var all_characters = battle_manager.characters
	
	# 连接每个角色的点击信号
	for character in all_characters:
		character.character_clicked.connect(_on_character_clicked)

func _spawn_character(character_data: CharacterData, position_offset: Vector2) -> Character:
	var character: Character = CHARACTER.instantiate()
	character.character_data = character_data
	character.position = position_offset
	return character

#region --- 信号处理 ---
## 当回合改变时调用
func _on_turn_changed(character: Character) -> void:
	show_action_ui(battle_manager.is_player_turn)
	battle_ui.update_turn_order(battle_manager.characters, battle_manager.current_turn_index)
	update_battle_info("{0} 的回合".format([character.character_name]))

## 处理战斗结束
func _on_battle_ended(is_victory: bool) -> void:
	# 隐藏所有战斗UI
	battle_ui.hide_all_menus()
	
	# 更新战斗日志
	if is_victory:
		battle_ui.battle_log_panel.log_system("战斗胜利！")
	else:
		battle_ui.battle_log_panel.log_system("战斗失败...")
	
	# 可以在这里处理战斗结束后的逻辑，如显示结算界面等
	
## 处理敌人行动执行
func _on_enemy_action_executed(attacker: Character, target: Character, damage: int) -> void:
	# 更新战斗信息
	var info_text = attacker.character_name + " 对 " + target.character_name + " 造成了 " + str(damage) + " 点伤害!"
	battle_ui.update_battle_info(info_text)
	
	# 添加到战斗日志
	battle_ui.log_attack(attacker.character_name, target.character_name, damage)

## 当战斗信息记录时调用
func _on_battle_info_logged(text: String) -> void:
	update_battle_info(text)

## 处理角色点击事件
func _on_character_clicked(character: Character) -> void:
	# 显示角色详情
	battle_ui.show_character_details(character)
#endregion

#region --- UI信号处理函数 ---
## 当玩家选择攻击时调用
func _on_action_attack_pressed() -> void:
	if not battle_manager.is_player_turn:
		return
	current_action = CharacterCombatComponent.ActionType.ATTACK
	battle_ui.show_target_selection(battle_manager.get_valid_enemy_targets())

## 当玩家选择防御时调用
func _on_action_defend_pressed() -> void:
	if battle_manager.is_player_turn:
		current_action = CharacterCombatComponent.ActionType.DEFEND
		battle_manager.player_select_action(current_action)

## 当玩家选择技能时调用
func _on_action_skill_pressed() -> void:
	if battle_manager.is_player_turn:
		current_action = CharacterCombatComponent.ActionType.SKILL
		battle_ui.show_skill_menu(battle_manager.current_turn_character)

## 当玩家选择道具时调用
func _on_action_item_pressed() -> void:
	if battle_manager.is_player_turn:
		update_battle_info("物品功能尚未实现")

## 当玩家选择技能时调用
func _on_skill_selected(skill: SkillData) -> void:
	current_selected_skill = skill
	
	if skill.needs_target():
		var valid_targets : Array[Character] = []
		if skill.is_enemy_target():
			valid_targets = battle_manager.get_valid_enemy_targets()
		elif skill.is_including_self():
			valid_targets = battle_manager.get_valid_ally_targets(true)
		else:
			valid_targets = battle_manager.get_valid_ally_targets(false)
		battle_ui.show_target_selection(valid_targets)
	else:
		# 自动目标技能，直接执行
		var params = {"skill": skill, "targets": []}
		battle_manager.player_select_action(CharacterCombatComponent.ActionType.SKILL, null, params)

## 当玩家取消技能选择时调用
func _on_skill_selection_cancelled() -> void:
	# 重置当前选中的技能
	current_selected_skill = null
	
	# 返回到玩家行动选择状态
	show_action_ui(battle_manager.is_player_turn)

## 当玩家选择了技能目标时调用
func _on_target_selected(target: Character) -> void:
	var params : Dictionary = {}
	# 覆盖技能的默认目标逻辑，强制使用玩家选择的目标
	if current_selected_skill != null:
		# 确保有选中的技能
		params = {"skill": current_selected_skill}
		
	battle_manager.player_select_action(current_action, target, params)

## 当玩家取消目标选择时调用
func _on_target_selection_cancelled() -> void:
	# 返回技能选择菜单
	if current_selected_skill:
		battle_ui.show_skill_menu(battle_manager.current_turn_character)
		current_selected_skill = null
	show_action_ui(battle_manager.is_player_turn)
#endregion
