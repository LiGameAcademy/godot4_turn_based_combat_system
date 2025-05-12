extends Node
class_name BattleVisualEffects

const DAMAGE_NUMBER_SCENE : PackedScene = preload("res://scenes/ui/damage_number.tscn")

# 元素颜色映射
var ELEMENT_COLORS = {}

func _ready():
	# 初始化元素颜色
	for element in ElementTypes.Element.keys():
		var element_value = ElementTypes.Element[element]
		ELEMENT_COLORS[element_value] = ElementTypes.get_element_color(element_value)

# 生成伤害数字
func spawn_damage_number(position: Vector2, amount: int, color: Color, prefix: String = "") -> void:
	var damage_number = DAMAGE_NUMBER_SCENE.instantiate()
	get_parent().add_child(damage_number)
	damage_number.global_position = position + Vector2(0, -50)
	
	# 如果有前缀，则添加到显示文本
	var display_text = prefix + str(amount)
	damage_number.show_number(display_text, color)
	
# 播放施法动画
func play_cast_effect(caster: Character, params: Dictionary = {}) -> void:
	var element = params.get("element", 0)
	var element_color = ELEMENT_COLORS.get(element, Color(1, 1, 1))
	
	var tween = create_tween()
	# 角色短暂发光效果，使用元素颜色
	tween.tween_property(caster, "modulate", element_color.lightened(0.5), 0.2)
	tween.tween_property(caster, "modulate", Color(1, 1, 1), 0.2)
	
	# 这里可以播放施法音效
	# AudioManager.play_sfx("spell_cast")
	
	# 如果有指定动画，则播放
	if caster.has_method("play_animation") and "animation" in params:
		caster.play_animation(params["animation"])

# 播放治疗施法动画
func play_heal_cast_effect(caster: Character, params: Dictionary = {}) -> void:
	# 治疗施法效果更柔和，绿色光芒
	var tween = create_tween()
	tween.tween_property(caster, "modulate", Color(0.7, 1.0, 0.7), 0.3)
	tween.tween_property(caster, "modulate", Color(1, 1, 1), 0.3)
	
	# 如果有指定动画，则播放
	if caster.has_method("play_animation") and "animation" in params:
		caster.play_animation(params["animation"])

# 播放命中动画
func play_hit_effect(target: Character, params: Dictionary = {}) -> void:
	var element = params.get("element", 0)
	var element_color = ELEMENT_COLORS.get(element, Color(1, 1, 1))
	
	var tween = create_tween()
	
	# 目标变色效果，根据元素
	tween.tween_property(target, "modulate", element_color, 0.1)
	
	# 抖动效果
	var original_pos = target.position
	tween.tween_property(target, "position", original_pos + Vector2(5, 0), 0.05)
	tween.tween_property(target, "position", original_pos - Vector2(5, 0), 0.05)
	tween.tween_property(target, "position", original_pos, 0.05)
	
	# 恢复正常颜色
	tween.tween_property(target, "modulate", Color(1, 1, 1), 0.1)
	
	# 如果有指定动画，则播放
	if target.has_method("play_animation") and "animation" in params:
		target.play_animation(params["animation"])

# 播放克制效果命中
func play_effective_hit_effect(target: Character, params: Dictionary = {}) -> void:
	var element = params.get("element", 0)
	var element_color = ELEMENT_COLORS.get(element, Color(1, 1, 1))
	
	var tween = create_tween()
	
	# 更强烈的颜色和晃动，表现克制效果
	tween.tween_property(target, "modulate", Color(2.0, 0.5, 0.5), 0.1)
	tween.tween_property(target, "modulate", Color(1.0, 1.0, 1.0), 0.1)
	
	var original_pos = target.position
	tween.tween_property(target, "position", original_pos + Vector2(10, 0), 0.05)
	tween.tween_property(target, "position", original_pos - Vector2(10, 0), 0.05)
	tween.tween_property(target, "position", original_pos, 0.05)
	
	# 如果有指定动画，则播放
	if target.has_method("play_animation") and "animation" in params:
		target.play_animation(params["animation"])

# 播放抵抗效果命中
func play_ineffective_hit_effect(target: Character, params: Dictionary = {}) -> void:
	var element = params.get("element", 0)
	var element_color = ELEMENT_COLORS.get(element, Color(1, 1, 1))
	
	var tween = create_tween()
	
	# 轻微视觉反馈，表现抵抗效果
	tween.tween_property(target, "modulate", Color(0.7, 0.7, 1.0), 0.1)
	tween.tween_property(target, "modulate", Color(1.0, 1.0, 1.0), 0.1)
	
	# 几乎不晃动，表示伤害被抵抗
	var original_pos = target.position
	tween.tween_property(target, "position", original_pos + Vector2(2, 0), 0.05)
	tween.tween_property(target, "position", original_pos, 0.05)
	
	# 如果有指定动画，则播放
	if target.has_method("play_animation") and "animation" in params:
		target.play_animation(params["animation"])

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
	var status_type = params.get("status_type", "buff")
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
		
# 重置视觉效果 (回合开始时调用)
func reset_visual_effects(character: Character) -> void:
	# 重置所有角色的颜色和位置修改
	character.modulate = Color(1, 1, 1)

# 其他视觉效果方法...
