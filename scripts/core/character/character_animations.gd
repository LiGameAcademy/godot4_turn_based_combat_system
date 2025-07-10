extends Node

## 角色动画辅助类，用于创建和管理角色动画

## 为角色创建原型动画
## [param animation_player] 角色的AnimationPlayer节点
static func setup_prototype_animations(animation_player: AnimationPlayer) -> void:
	if not animation_player:
		push_error("AnimationPlayer为空，无法设置动画")
		return
	
	# 创建攻击动画
	_create_attack_animation(animation_player)
	
	# 创建防御动画
	_create_defend_animation(animation_player)
	
	# 创建技能施放动画
	_create_skill_animation(animation_player)
	
	# 创建物品使用动画
	_create_item_animation(animation_player)
	
	# 创建受击动画
	_create_hit_animation(animation_player)
	
	# 创建死亡动画
	_create_death_animation(animation_player)
	
	print("角色原型动画设置完成")

## 创建攻击动画
static func _create_attack_animation(animation_player: AnimationPlayer) -> void:
	var animation = Animation.new()
	animation.length = 0.5  # 动画持续时间
	
	# 创建位置轨道
	var track_index = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ":position:x")
	animation.track_insert_key(track_index, 0.0, 0)  # 初始位置
	animation.track_insert_key(track_index, 0.2, 20)  # 向前移动
	animation.track_insert_key(track_index, 0.5, 0)   # 回到原位
	
	# 创建颜色轨道（攻击时略微变亮）
	track_index = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ":modulate")
	animation.track_insert_key(track_index, 0.0, Color(1, 1, 1, 1))  # 初始颜色
	animation.track_insert_key(track_index, 0.2, Color(1.2, 1.2, 1.2, 1))  # 变亮
	animation.track_insert_key(track_index, 0.5, Color(1, 1, 1, 1))  # 恢复正常
	
	# 添加到AnimationPlayer
	_add_animation(animation_player, "attack", animation)

## 创建防御动画
static func _create_defend_animation(animation_player: AnimationPlayer) -> void:
	var animation = Animation.new()
	animation.length = 0.5  # 动画持续时间
	
	# 创建颜色轨道（防御时变蓝）
	var track_index = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ":modulate")
	animation.track_insert_key(track_index, 0.0, Color(1, 1, 1, 1))  # 初始颜色
	animation.track_insert_key(track_index, 0.2, Color(0.5, 0.5, 1.5, 1))  # 变蓝
	animation.track_insert_key(track_index, 0.5, Color(1, 1, 1, 1))  # 恢复正常
	
	# 添加到AnimationPlayer
	_add_animation(animation_player, "defend", animation)

## 创建技能施放动画
static func _create_skill_animation(animation_player: AnimationPlayer) -> void:
	var animation = Animation.new()
	animation.length = 0.5  # 动画持续时间
	
	# 创建颜色轨道（施法时发光）
	var track_index = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ":modulate")
	animation.track_insert_key(track_index, 0.0, Color(1, 1, 1, 1))  # 初始颜色
	animation.track_insert_key(track_index, 0.2, Color(1.5, 1.5, 0.5, 1))  # 变黄
	animation.track_insert_key(track_index, 0.5, Color(1, 1, 1, 1))  # 恢复正常
	
	# 添加到AnimationPlayer
	_add_animation(animation_player, "skill", animation)

## 创建物品使用动画
static func _create_item_animation(animation_player: AnimationPlayer) -> void:
	var animation = Animation.new()
	animation.length = 0.5  # 动画持续时间
	
	# 创建颜色轨道（使用物品时变绿）
	var track_index = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ":modulate")
	animation.track_insert_key(track_index, 0.0, Color(1, 1, 1, 1))  # 初始颜色
	animation.track_insert_key(track_index, 0.2, Color(0.5, 1.5, 0.5, 1))  # 变绿
	animation.track_insert_key(track_index, 0.5, Color(1, 1, 1, 1))  # 恢复正常
	
	# 添加到AnimationPlayer
	_add_animation(animation_player, "item", animation)

## 创建受击动画
static func _create_hit_animation(animation_player: AnimationPlayer) -> void:
	var animation = Animation.new()
	animation.length = 0.3  # 动画持续时间
	
	# 创建颜色轨道（受击时变红）
	var track_index = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ":modulate")
	animation.track_insert_key(track_index, 0.0, Color(1, 1, 1, 1))  # 初始颜色
	animation.track_insert_key(track_index, 0.1, Color(1.5, 0.5, 0.5, 1))  # 变红
	animation.track_insert_key(track_index, 0.3, Color(1, 1, 1, 1))  # 恢复正常
	
	# 创建位置轨道（受击时抖动）
	track_index = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ":position")
	animation.track_insert_key(track_index, 0.0, Vector2(0, 0))  # 初始位置
	animation.track_insert_key(track_index, 0.05, Vector2(5, 0))  # 右移
	animation.track_insert_key(track_index, 0.1, Vector2(-5, 0))  # 左移
	animation.track_insert_key(track_index, 0.15, Vector2(3, 0))  # 右移
	animation.track_insert_key(track_index, 0.2, Vector2(-3, 0))  # 左移
	animation.track_insert_key(track_index, 0.3, Vector2(0, 0))  # 回到原位
	
	# 添加到AnimationPlayer
	_add_animation(animation_player, "hit", animation)

## 创建死亡动画
static func _create_death_animation(animation_player: AnimationPlayer) -> void:
	var animation = Animation.new()
	animation.length = 1.0  # 动画持续时间
	
	# 创建颜色轨道（死亡时变红然后淡出）
	var track_index = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ":modulate")
	animation.track_insert_key(track_index, 0.0, Color(1, 1, 1, 1))  # 初始颜色
	animation.track_insert_key(track_index, 0.3, Color(0.8, 0, 0, 1))  # 变红
	animation.track_insert_key(track_index, 1.0, Color(0.8, 0, 0, 0))  # 淡出
	
	# 创建位置轨道（死亡时下沉）
	track_index = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ":position:y")
	animation.track_insert_key(track_index, 0.0, 0)  # 初始位置
	animation.track_insert_key(track_index, 1.0, 30)  # 下沉
	
	# 添加到AnimationPlayer
	_add_animation(animation_player, "death", animation)

## 添加动画到AnimationPlayer
static func _add_animation(animation_player: AnimationPlayer, animation_name: StringName, animation: Animation) -> void:
	var animation_library = animation_player.get_animation_library("")
	animation_library.add_animation(animation_name, animation)
	
