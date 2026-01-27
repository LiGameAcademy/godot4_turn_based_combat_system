@tool
extends EditorPlugin

## 回合制战斗系统插件入口
## 负责插件的启用和禁用

func _enter_tree():
	# 插件启用时的初始化
	print("Turn Based Combat System plugin enabled")
	add_autoload_singleton("SkillSystem", "res://addons/turn_based_combat_system/skill_system/skill_system.gd")

func _exit_tree():
	# 插件禁用时的清理
	print("Turn Based Combat System plugin disabled")
	remove_autoload_singleton("SkillSystem")
