extends Node2D
class_name BattleScene

## 战斗场景，负责战斗的UI显示和交互

@onready var action_panel: Panel = %ActionPanel
@onready var info_label: RichTextLabel = %InfoLabel
@onready var skill_select_menu: SkillSelectMenu = $BattleUI/SkillSelectMenu
@onready var target_selection_menu: TargetSelectionMenu = $BattleUI/TargetSelectionMenu
@onready var player_area: Node2D = %PlayerArea
@onready var enemy_area: Node2D = %EnemyArea
@onready var battle_manager: BattleManager = %BattleManager

var current_selected_skill : SkillData

func _ready() -> void:
	# 连接战斗管理器信号
	battle_manager.turn_changed.connect(_on_turn_changed)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.battle_info_logged.connect(_on_battle_info_logged)
	# 连接技能选择菜单信号
	skill_select_menu.skill_selected.connect(_on_skill_selected)
	skill_select_menu.skill_selection_cancelled.connect(_on_skill_selection_cancelled)
	skill_select_menu.hide()
	# 连接目标选择菜单信号
	target_selection_menu.target_selected.connect(_on_target_selected)
	target_selection_menu.target_selection_cancelled.connect(_on_target_selection_cancelled)
	target_selection_menu.hide()
	# 连接行动菜单信号
	action_panel.attack_pressed.connect(_on_action_panel_attack_pressed)
	action_panel.defend_pressed.connect(_on_action_panel_defend_pressed)
	action_panel.skill_pressed.connect(_on_action_panel_skill_pressed)
	action_panel.item_pressed.connect(_on_action_panel_item_pressed)
	action_panel.hide()
	for player in player_area.get_children():
		if player is Character:
			battle_manager.add_character(player, true)
			
	for enemy in enemy_area.get_children():
		if enemy is Character:
			battle_manager.add_character(enemy, false)

	battle_manager.start_battle()

# 显示/隐藏行动UI
func show_action_ui(should_show: bool) -> void:
	if action_panel:
		action_panel.visible = should_show

# 更新战斗信息
func update_battle_info(text: String) -> void:
	if info_label:
		info_label.text += "\n" + text

#region --- 信号处理 ---
## 当回合改变时调用
func _on_turn_changed(character: Character) -> void:
	show_action_ui(battle_manager.is_player_turn)
	update_battle_info("{0} 的回合".format([character.character_name]))

## 当战斗结束时调用
func _on_battle_ended(_is_victory: bool) -> void:
	show_action_ui(false)

## 当战斗信息记录时调用
func _on_battle_info_logged(text: String) -> void:
	update_battle_info(text)
#endregion

#region --- UI信号处理函数 ---
## 当玩家选择攻击时调用
func _on_action_panel_attack_pressed() -> void:
	if battle_manager.is_player_turn:
		# 选择第一个存活的敌人作为目标
		var valid_targets = battle_manager.get_valid_enemy_targets()
		if !valid_targets.is_empty():
			var target = valid_targets[0] # 这里简化为直接选择第一个敌人
			battle_manager.player_select_action(CharacterCombatComponent.ActionType.ATTACK, target)
		else:
			update_battle_info("没有可攻击的目标！")

## 当玩家选择防御时调用
func _on_action_panel_defend_pressed() -> void:
	if battle_manager.is_player_turn:
		battle_manager.player_select_action(CharacterCombatComponent.ActionType.DEFEND)

## 当玩家选择技能时调用
func _on_action_panel_skill_pressed() -> void:
	if battle_manager.is_player_turn:
		_open_skill_menu()

## 当玩家选择道具时调用
func _on_action_panel_item_pressed() -> void:
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
		target_selection_menu.show_targets(valid_targets)
	else:
		# 自动目标技能，直接执行
		var params = {"skill": skill, "targets": []}
		battle_manager.player_select_action(CharacterCombatComponent.ActionType.SKILL, null, params)

## 当玩家取消技能选择时调用
func _on_skill_selection_cancelled() -> void:
	# 重置当前选中的技能
	current_selected_skill = null
	
	# 返回到玩家行动选择状态
	_show_action_menu()

## 当玩家选择了技能目标时调用
func _on_target_selected(target: Character) -> void:
	# 确保有选中的技能
	if current_selected_skill == null:
		push_error("选择了目标但没有当前技能")
		_show_action_menu()
		return
	
	# 覆盖技能的默认目标逻辑，强制使用玩家选择的目标
	var params = {"skill": current_selected_skill}
	battle_manager.player_select_action(CharacterCombatComponent.ActionType.SKILL, target, params)

## 当玩家取消目标选择时调用
func _on_target_selection_cancelled() -> void:
	# 返回技能选择菜单
	current_selected_skill = null
	_open_skill_menu()

## 打开技能选择菜单
func _open_skill_menu() -> void:
	if battle_manager.current_turn_character == null || !battle_manager.is_player_turn:
		return
	
	# 隐藏行动菜单
	action_panel.visible = false
	
	# 显示技能菜单
	if skill_select_menu:
		skill_select_menu.show_menu(
			battle_manager.current_turn_character.character_data.skills,
			battle_manager.current_turn_character.current_mp
		)

## 显示动作菜单
func _show_action_menu() -> void:
	# 确保当前是玩家角色的回合
	if battle_manager.current_turn_character == null || !battle_manager.is_player_turn:
		return
	
	# 隐藏其他可能显示的菜单
	_hide_all_menus()
	
	# 显示行动菜单并更新状态
	if action_panel:
		# 更新菜单状态
		_update_action_menu_state()
		# 显示菜单
		action_panel.visible = true
		# 设置默认焦点
		action_panel.setup_default_focus()

## 隐藏所有菜单
func _hide_all_menus() -> void:
	if skill_select_menu:
		skill_select_menu.hide()
	if target_selection_menu:
		target_selection_menu.hide()
	if action_panel:
		action_panel.visible = false

## 更新行动菜单状态
func _update_action_menu_state() -> void:
	if !action_panel || !battle_manager.current_turn_character:
		return
		
	# 根据MP是否足够来启用/禁用技能按钮
	var has_enough_mp_for_any_skill = battle_manager.current_turn_character.has_enough_mp_for_any_skill()
	action_panel.set_skill_button_enabled(has_enough_mp_for_any_skill)
	
	var has_usable_items = false #TODO 这里需要根据实际的物品系统来实现
	action_panel.set_item_button_enabled(has_usable_items)
