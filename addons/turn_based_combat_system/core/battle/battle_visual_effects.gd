extends Node
class_name BattleVisualEffects

## 伤害数字场景 (需要预加载或在编辑器中设置)
@export var _damage_number_scene: PackedScene 

## 初始化
func initialize(damage_number_scene: PackedScene = null) -> void:
	_damage_number_scene = damage_number_scene
	# 预加载资源检查
	if not _damage_number_scene:
		push_warning("Damage number scene not set in BattleVisualEffects.")
	# 初始化完成
	print("BattleVisualEffects initialized.")

## 显示伤害数字
## [param target_character] 受到伤害的角色
## [param damage_amount] 伤害数值
## [param is_critical] 是否暴击
## [param color] 伤害数字颜色
## [param prefix] 伤害数字前缀
## [param offset] 位置偏移
func show_damage_number(
		target_character: Character, 
		damage_amount: float, 
		is_critical: bool = false,
		color: Color = Color.RED,
		prefix: String = "",
		offset: Vector2 = Vector2(0, 50)
		) -> void:
	var damage_num_instance : DamageNumber = _create_damage_number(target_character, offset)
	damage_num_instance.show_damage(damage_amount, is_critical, color, prefix)

## 显示治疗数字
func show_heal_number(
		target_character: Character, 
		heal_amount: float,
		offset: Vector2 = Vector2(0, 50)
		) -> void:
	var heal_num_instance : DamageNumber = _create_damage_number(target_character, offset)
	heal_num_instance.show_heal(heal_amount)

## 显示状态文本 (例如 "中毒!", "眩晕!")
## [param target_character] 受到状态的角色
## [param text] 状态文本
## [param is_positive] 是否为正面状态
func show_status_text(target_character: Character, text: String, is_positive: bool = true) -> void:
	var status_text_instance : DamageNumber = _create_damage_number(target_character, Vector2(0, 70))
	status_text_instance.show_status(text, is_positive)
	print("Showed status text: '%s' on %s" % [text, target_character.character_name])

## 播放技能特效 (例如在目标身上显示一个爆炸效果)
## [param skill_data] 使用的技能数据
## [param caster] 施法者
## [param targets] 技能目标
func play_skill_visual_effects(skill_data: SkillData, caster: Character, targets: Array[Character]) -> Signal:
	if not skill_data:
		return Signal() # 返回一个立即完成的信号

	print("Playing visual effects for skill: %s by %s on %s" % [skill_data.skill_name, caster.character_name, targets])
	
	# 根据 skill_data.visual_effect_scene_path (假设有这个属性) 来实例化特效
	# if skill_data.visual_effect_scene_path and not skill_data.visual_effect_scene_path.is_empty():
	# 	var vfx_scene = load(skill_data.visual_effect_scene_path) as PackedScene
	# 	if vfx_scene:
	# 		for target in targets:
	# 			if is_instance_valid(target):
	# 				var vfx_instance = vfx_scene.instantiate()
	# 				target.add_child(vfx_instance) # 或者添加到全局层
	# 				# vfx_instance.global_position = target.global_position
	# 				# 如果特效节点有自己的播放逻辑和完成信号，可以 await 它
	# else:
	# 	print("No specific visual effect scene for skill: ", skill_data.skill_name)

	# 模拟特效播放
	var tween = get_tree().create_tween()
	tween.tween_interval(0.3) # 假设特效持续0.3秒
	await tween.finished
	return tween.finished

# 治疗效果视觉反馈
func play_heal_effect(target: Character, params: Dictionary = {}) -> void:
	var tween = create_tween()
	
	# 目标变绿效果（表示恢复）
	tween.tween_property(target, "modulate", Color(0.7, 1.5, 0.7), 0.2)
	
	# 上升的小动画，暗示"提升"
	var original_pos = target.position
	tween.tween_property(target, "position", original_pos - Vector2(0, 5), 0.2)
	tween.tween_property(target, "position", original_pos, 0.1)
	
	# 恢复正常颜色
	tween.tween_property(target, "modulate", Color(1, 1, 1), 0.2)
	
	# 如果有指定动画，则播放
	if target.has_method("play_animation") and "animation" in params:
		target.play_animation(params["animation"])

# 状态效果应用视觉反馈
func play_status_effect(target: Character, params: Dictionary = {}) -> void:
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

# 防御姿态效果
func play_defend_effect(character: Character) -> void:
	var tween = create_tween()
	
	# 角色微光效果
	tween.tween_property(character, "modulate", Color(0.8, 0.9, 1.3), 0.2)
	
	# 如果有对应动画，播放防御动画
	if character.has_method("play_animation"):
		character.play_animation("defend")

# --- 元素克制相关的视觉效果方法 ---
## 显示元素克制效果（伤害加成）
func show_effective_hit(target: Character, params: Dictionary = {}) -> void:
	# 显示伤害数字
	var damage_amount = params.get("amount", 0)
	var damage_num_instance : DamageNumber = _create_damage_number(target, Vector2(0, 50))
	damage_num_instance.show_damage(damage_amount, false, Color(1.0, 0.7, 0.0), "克制! ")
	
	# 播放克制特效
	var tween = create_tween()
	# 闪烁黄色（表示克制）
	tween.tween_property(target, "modulate", Color(1.5, 1.2, 0.5), 0.1)
	tween.tween_property(target, "modulate", Color(1, 1, 1), 0.2)

## 显示元素被克制效果（伤害减免）
func show_ineffective_hit(target: Character, params: Dictionary = {}) -> void:
	# 显示伤害数字
	var damage_amount = params.get("amount", 0)
	var damage_num_instance : DamageNumber = _create_damage_number(target, Vector2(0, 50))
	damage_num_instance.show_damage(damage_amount, false, Color(0.5, 0.5, 0.5), "抵抗 ")
	
	# 播放抵抗特效
	var tween = create_tween()
	# 闪烁灰色（表示抵抗）
	tween.tween_property(target, "modulate", Color(0.7, 0.7, 0.8), 0.1)
	tween.tween_property(target, "modulate", Color(1, 1, 1), 0.2)
	

## 显示普通伤害效果
func show_normal_damage(target: Character, params: Dictionary = {}) -> void:
	# 显示伤害数字
	var damage_amount = params.get("amount", 0)
	var damage_num_instance : DamageNumber = _create_damage_number(target, Vector2(0, 50))
	damage_num_instance.show_damage(damage_amount, false, Color.RED, "")
	
	# 播放普通命中特效
	var tween = create_tween()
	tween.tween_property(target, "modulate", Color(1.3, 0.7, 0.7), 0.1)
	tween.tween_property(target, "modulate", Color(1, 1, 1), 0.2)

# --- 其他可能的视觉效果方法 ---
# func show_buff_applied_effect(target: Character, buff_name: String)
# func show_debuff_applied_effect(target: Character, debuff_name: String)
# func highlight_active_character(character: Character)
# func dim_inactive_characters(characters_to_dim: Array[Character])

## 创建伤害数字
## [param target_character] 受到伤害的角色
## [param offset] 相对于目标角色的位置偏移
## [return] 创建的伤害数字实例
func _create_damage_number(target_character: Character, offset: Vector2) -> DamageNumber:
	if not is_instance_valid(target_character):
		push_error("Invalid target character.")
		return

	if not _damage_number_scene:
		push_error("Damage number scene not set in BattleVisualEffects.")
		return null

	var damage_num_instance : DamageNumber = _damage_number_scene.instantiate()
	if not damage_num_instance: 
		push_error("Failed to instantiate damage number scene.")
		return null
	# 将伤害数字添加到目标角色的位置或一个全局的UI层
	# 这里假设添加到目标角色节点下，并向上偏移一些
	target_character.add_child(damage_num_instance)
	damage_num_instance.global_position = target_character.global_position - offset

	return damage_num_instance
