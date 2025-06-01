extends Node2D
class_name Main

const BATTLE_SCENE = preload("res://scenes/battle/battle_scene.tscn")

@export var battle_data : BattleData

func _ready() -> void:
	var battle_scene : BattleScene = BATTLE_SCENE.instantiate()
	add_child(battle_scene)
	battle_scene.initialize_battle(battle_data)
