extends Node2D

@onready var attack_button: Button = %AttackButton
@onready var defend_button: Button = %DefendButton
@onready var battle_manager: BattleManager = %BattleManager

func _ready() -> void:
	# 连接UI按钮信号
	attack_button.pressed.connect(_on_attack_button_pressed)
	defend_button.pressed.connect(_on_defend_button_pressed)
	
	# 启动战斗
	battle_manager.start_battle()

func _on_attack_button_pressed():
	# 当玩家处于行动回合时，获取当前敌人作为目标
	if battle_manager.current_state == BattleManager.BattleState.PLAYER_TURN:
		# 选择第一个存活的敌人作为目标
		var target = null
		for enemy in battle_manager.enemy_characters:
			if enemy.current_hp > 0:
				target = enemy
				break
				
		if target:
			battle_manager.player_select_action("attack", target)

func _on_defend_button_pressed():
	if battle_manager.current_state == BattleManager.BattleState.PLAYER_TURN:
		battle_manager.player_select_action("defend")
