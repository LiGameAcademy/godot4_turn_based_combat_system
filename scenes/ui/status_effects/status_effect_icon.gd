class_name StatusEffectIcon
extends Control

@onready var icon_texture = $IconTexture
@onready var stack_label = $StackCount
@onready var duration_label = $Duration
@onready var animation_player = $AnimationPlayer

var effect = null

func initialize(status_effect) -> void:
    effect = status_effect
    
    # 设置图标
    var texture = load(effect.data.icon_path)
    if texture:
        icon_texture.texture = texture
    
    # 设置堆叠数
    if effect.stack_count > 1:
        stack_label.text = str(effect.stack_count)
        stack_label.show()
    else:
        stack_label.hide()
    
    # 设置持续时间
    duration_label.text = str(effect.remaining_duration)
    
    # 根据效果类型设置颜色
    match effect.data.status_type:
        SkillStatusData.StatusType.BUFF:
            self_modulate = Color(0.2, 0.8, 0.2)  # 绿色
        SkillStatusData.StatusType.DEBUFF:
            self_modulate = Color(0.8, 0.2, 0.2)  # 红色
        SkillStatusData.StatusType.NEUTRAL:
            self_modulate = Color(0.8, 0.5, 0.2)  # 橙色
    
    # 播放添加动画
    animation_player.play("add")

func update_display() -> void:
    if effect.stack_count > 1:
        stack_label.text = str(effect.stack_count)
        stack_label.show()
    else:
        stack_label.hide()
    
    duration_label.text = str(effect.remaining_duration)
    
    # 播放更新动画
    animation_player.play("update")

func play_remove_animation() -> void:
    animation_player.play("remove")
    await animation_player.animation_finished
    queue_free() 