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

# 添加状态效果应用的视觉特效方法
func play_status_effect_applied(target: Character, effect_data: StatusEffectData) -> void:
	# 根据状态效果类型设置适当的颜色
	var color = Color.WHITE
	var is_positive = false
	
	match effect_data.effect_type:
		StatusEffectData.EffectType.BUFF:
			color = Color(0.2, 0.8, 0.2)  # 绿色
			is_positive = true
		StatusEffectData.EffectType.DEBUFF:
			color = Color(0.8, 0.2, 0.2)  # 红色
			is_positive = false
		StatusEffectData.EffectType.DOT:
			color = Color(0.8, 0.5, 0.2)  # 橙色
			is_positive = false
		StatusEffectData.EffectType.HOT:
			color = Color(0.2, 0.8, 0.8)  # 青色
			is_positive = true
		StatusEffectData.EffectType.CONTROL:
			color = Color(0.8, 0.2, 0.8)  # 紫色
			is_positive = false
	
	# 根据是否为正面效果，使用已有的play_status_effect方法
	play_status_effect(target, {
		"status_type": effect_data.effect_type,
		"is_positive": is_positive
	})
	
	# 此外，也可以添加特定于效果类型的特殊视觉效果
	match effect_data.effect_type:
		StatusEffectData.EffectType.CONTROL:
			# 控制效果特殊视觉效果 - 例如星星环绕
			_play_control_effect(target)
		StatusEffectData.EffectType.HOT:
			# 治疗特殊视觉效果 - 上升的绿色粒子
			_play_hot_effect(target)
		StatusEffectData.EffectType.DOT:
			# 持续伤害特殊视觉效果 - 例如毒气效果
			_play_dot_effect(target)

# 控制效果特殊视觉效果
func _play_control_effect(target: Character) -> void:
	# 创建星星效果
	var control_effect = Node2D.new()
	add_child(control_effect)
	control_effect.global_position = target.global_position
	
	# 创建星星精灵
	var stars = []
	for i in range(3):
		var star = ColorRect.new()
		control_effect.add_child(star)
		star.color = Color(0.8, 0.2, 0.8, 0.7)  # 半透明紫色
		star.size = Vector2(10, 10)
		star.position = Vector2(sin(i * 2.0) * 30, cos(i * 2.0) * 30)
		stars.append(star)
	
	# 创建动画 - 星星围绕角色旋转
	var tween = create_tween()
	tween.set_loops(2)  # 重复两次
	
	for i in range(stars.size()):
		var star = stars[i]
		var start_angle = i * 2.0
		
		# 创建旋转动画
		tween.parallel().tween_method(
			func(angle): star.position = Vector2(sin(angle) * 30, cos(angle) * 30),
			start_angle, start_angle + 6.28, 1.0  # 一圈的弧度是2π
		)
	
	# 结束后淡出并清理
	await tween.finished
	var fade_tween = create_tween()
	fade_tween.tween_property(control_effect, "modulate", Color(1, 1, 1, 0), 0.5)
	await fade_tween.finished
	control_effect.queue_free()

# 持续治疗特殊视觉效果
func _play_hot_effect(target: Character) -> void:
	# 创建上升的绿色粒子效果
	var particles = Node2D.new()
	add_child(particles)
	particles.global_position = target.global_position
	
	# 创建几个上升的小方块代表绿色粒子
	var rects = []
	for i in range(5):
		var rect = ColorRect.new()
		particles.add_child(rect)
		rect.color = Color(0.2, 0.8, 0.2, 0.7)  # 半透明绿色
		rect.size = Vector2(5, 5)
		rect.position = Vector2(randf_range(-20, 20), randf_range(0, 10))
		rects.append(rect)
	
	# 创建上升动画
	var tween = create_tween()
	
	for rect in rects:
		var start_pos = rect.position
		var end_pos = start_pos - Vector2(0, 40)  # 向上移动
		
		# 添加上升和淡出动画
		tween.parallel().tween_property(rect, "position", end_pos, 1.0)
		tween.parallel().tween_property(rect, "modulate", Color(1, 1, 1, 0), 1.0)
	
	# 动画结束后清理
	await tween.finished
	particles.queue_free()

# 持续伤害特殊视觉效果
func _play_dot_effect(target: Character) -> void:
	# 创建毒气/火焰效果
	var effect = Node2D.new()
	add_child(effect)
	effect.global_position = target.global_position
	
	# 创建几个代表毒气/火焰的小方块
	var particles = []
	for i in range(5):
		var particle = ColorRect.new()
		effect.add_child(particle)
		particle.color = Color(0.8, 0.5, 0.2, 0.7)  # 半透明橙色
		particle.size = Vector2(7, 7)
		particle.position = Vector2(randf_range(-20, 20), randf_range(-10, 10))
		particles.append(particle)
	
	# 创建动画 - 粒子扩散并淡出
	var tween = create_tween()
	
	for particle in particles:
		var start_pos = particle.position
		var direction = start_pos.normalized()
		var end_pos = start_pos + direction * 30
		
		# 添加扩散和淡出动画
		tween.parallel().tween_property(particle, "position", end_pos, 0.8)
		tween.parallel().tween_property(particle, "modulate", Color(1, 1, 1, 0), 0.8)
	
	# A动画结束后清理
	await tween.finished
	effect.queue_free()

# 播放控制效果应用时的视觉效果
func play_control_applied(target: Node2D, params: Dictionary = {}):
	var control_type = params.get("control_type", "stun")
	
	# 根据控制类型设置不同颜色
	var color = Color.WHITE
	match control_type:
		"stun":
			color = Color.YELLOW
		"silence":
			color = Color.PURPLE
		"root":
			color = Color.DARK_GREEN
		"sleep":
			color = Color.BLUE
	
	# 创建粒子效果
	var particles = create_particle_effect(color, 15, 1.0, 0.6)
	target.add_child(particles)
	particles.global_position = target.global_position
	particles.emitting = true
	
	# 添加控制效果的图标或动画
	show_control_icon(target, control_type)
	
	# 播放音效 (如果有)
	
	# 延迟销毁
	await get_tree().create_timer(1.0).timeout
	if particles and is_instance_valid(particles):
		particles.queue_free()

# 播放控制效果抵抗时的视觉效果
func play_control_resist(target: Node2D, params: Dictionary = {}):
	# 创建粒子效果 - 灰色表示抵抗
	var particles = create_particle_effect(Color.DARK_GRAY, 10, 0.8, 0.4)
	target.add_child(particles)
	particles.global_position = target.global_position
	particles.emitting = true
	
	# 添加"抵抗"文字提示
	var text = create_floating_text(target.global_position, "抵抗!", Color.DARK_GRAY)
	get_tree().current_scene.add_child(text)
	
	# 延迟销毁
	await get_tree().create_timer(0.8).timeout
	if particles and is_instance_valid(particles):
		particles.queue_free()

# 显示控制效果图标
func show_control_icon(target: Node2D, control_type: String):
	# 这里可以实现添加一个图标显示到目标上方
	# 在实际游戏中，可能需要创建一个独立的控制效果图标系统
	var icon = Label.new()
	
	# 设置图标文本 (临时使用文字代替图标)
	var text = ""
	match control_type:
		"stun":
			text = "眩晕"
			icon.modulate = Color.YELLOW
		"silence":
			text = "沉默"
			icon.modulate = Color.PURPLE
		"root":
			text = "定身"
			icon.modulate = Color.DARK_GREEN
		"sleep":
			text = "睡眠"
			icon.modulate = Color.BLUE
		_:
			text = control_type
	
	icon.text = text
	target.add_child(icon)
	
	# 设置位置在角色上方
	icon.position = Vector2(0, -50)
	
	# 添加动画效果
	var tween = create_tween()
	tween.tween_property(icon, "position", Vector2(0, -70), 0.5)
	tween.tween_property(icon, "modulate:a", 0.0, 0.5)
	
	# 动画结束后移除
	await tween.finished
	icon.queue_free()

# 创建粒子效果
func create_particle_effect(color: Color, count: int = 10, lifetime: float = 1.0, scale: float = 1.0) -> CPUParticles2D:
	var particles = CPUParticles2D.new()
	
	# 设置粒子属性
	particles.emitting = false
	particles.amount = count
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.randomness = 0.5
	particles.scale_amount = scale
	
	# 设置粒子颜色
	particles.color = color
	
	# 设置粒子移动
	particles.direction = Vector2(0, -1)
	particles.spread = 80
	particles.initial_velocity_min = 20
	particles.initial_velocity_max = 40
	particles.gravity = Vector2(0, 40)
	
	return particles

# 创建浮动文字
func create_floating_text(position: Vector2, text: String, color: Color = Color.WHITE) -> Node2D:
	var container = Node2D.new()
	var label = Label.new()
	
	# 设置标签属性
	label.text = text
	label.modulate = color
	
	# 添加标签到容器
	container.add_child(label)
	container.position = position
	
	# 设置动画效果
	var tween = container.create_tween()
	tween.tween_property(container, "position", position + Vector2(0, -30), 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	
	# 动画完成后销毁
	tween.tween_callback(container.queue_free)
	
	return container
