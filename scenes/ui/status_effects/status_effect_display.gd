class_name StatusEffectDisplay
extends HBoxContainer

var character: Character = null
var effect_icons = {}  # 效果ID -> 图标节点

@export var status_icon_scene: PackedScene

func initialize(target_character: Character) -> void:
    character = target_character
    
    # 连接信号
    character.status_effect_added.connect(_on_status_effect_added)
    character.status_effect_updated.connect(_on_status_effect_updated)
    character.status_effect_removed.connect(_on_status_effect_removed)
    
    # 清除现有图标
    for child in get_children():
        child.queue_free()
    
    effect_icons.clear()
    
    # 添加现有效果的图标
    for effect in character.active_status_effects:
        _add_effect_icon(effect)

func _add_effect_icon(effect) -> void:
    var icon_instance = status_icon_scene.instantiate()
    add_child(icon_instance)
    icon_instance.initialize(effect)
    
    effect_icons[effect.data.effect_id] = icon_instance

func _on_status_effect_added(effect) -> void:
    _add_effect_icon(effect)

func _on_status_effect_updated(effect) -> void:
    if effect.data.effect_id in effect_icons:
        effect_icons[effect.data.effect_id].update_display()

func _on_status_effect_removed(effect) -> void:
    if effect.data.effect_id in effect_icons:
        var icon = effect_icons[effect.data.effect_id]
        icon.play_remove_animation()
        effect_icons.erase(effect.data.effect_id) 