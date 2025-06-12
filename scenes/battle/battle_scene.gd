extends Node2D

@onready var action_panel: Panel = %ActionPanel
@onready var attack_button: Button = %AttackButton
@onready var defend_button: Button = %DefendButton
@onready var battle_manager: BattleManager = %BattleManager
@onready var info_label: RichTextLabel = %InfoLabel
@onready var player_area: Node2D = %PlayerArea
@onready var enemy_area: Node2D = %EnemyArea

func _ready() -> void:
	attack_button.pressed.connect(_on_attack_button_pressed)
	defend_button.pressed.connect(_on_defend_button_pressed)
	battle_manager.turn_changed.connect(_on_turn_changed)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.battle_info_logged.connect(_on_battle_info_logged)

	for player in player_area.get_children():
		if player is Character:
			battle_manager.add_player_character(player)
			
	for enemy in enemy_area.get_children():
		if enemy is Character:
			battle_manager.add_enemy_character(enemy)

	battle_manager.start_battle()

# 显示/隐藏行动UI
func show_action_ui(should_show: bool) -> void:
	if action_panel:
		action_panel.visible = should_show

# 更新战斗信息
func update_battle_info(text: String) -> void:
	if info_label:
		info_label.text += "\n" + text
	
# UI按钮事件处理
func _on_attack_button_pressed():
	# 当玩家处于行动回合时，获取当前敌人作为目标
	if battle_manager.is_player_turn:
		# 选择第一个存活的敌人作为目标
		var target = null
		for enemy in battle_manager.enemy_characters:
			if enemy.current_hp > 0:
				target = enemy
				break
				
		if target:
			battle_manager.player_select_action("attack", target)

func _on_defend_button_pressed():
	if battle_manager.is_player_turn:
		battle_manager.player_select_action("defend")

func _on_turn_changed(character: Character) -> void:
	show_action_ui(battle_manager.is_player_turn)
	update_battle_info("{0} 的回合".format([character.character_name]))

func _on_battle_ended(_is_victory: bool) -> void:
	show_action_ui(false)
	update_battle_info("战斗结束")

func _on_battle_info_logged(text: String) -> void:
	update_battle_info(text)
