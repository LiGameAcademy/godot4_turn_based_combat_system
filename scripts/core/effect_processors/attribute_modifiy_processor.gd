extends EffectProcessor
class_name AttributeModifyEffectProcessor

## 获取处理器ID
func get_processor_id() -> StringName:
    return &"attribute_modify"

## 判断是否可以处理该效果
func can_process(effect: SkillEffectData) -> bool:
    return effect.effect_type == SkillEffectData.EffectType.ATTRIBUTE_MODIFY

## 执行效果
func process_effect(effect_data: SkillEffectData, _source: Character, target: Character) -> Dictionary:
    if effect_data.effect_type != SkillEffectData.EffectType.ATTRIBUTE_MODIFY:
        return {"error": "wrong_effect_type"}

    var target_combat_comp = _get_target_combat_component(target)
    if not target_combat_comp:
        return {"error": "invalid_target"}

    var modifier_res: SkillAttributeModifier = effect_data.attr_modifier # SkillEffectData 中定义的修改器资源
    if not modifier_res:
        return {"error": "missing_attribute_modifier_resource_in_effect_data"}
    
    # 重要：此处理器通常用于“瞬时”的属性修改，或应用一个会“过期/被移除”的修改器。
    # 如果是应用一个随状态持续的修改器，通常是 StatusEffectProcessor 应用状态，状态再通过其
    # attribute_modifiers 数组让 CombatComponent 处理。
    # 此处假设是应用一个“独立的”修改器，它需要一个来源标识（如技能ID）和可能的持续时间。
    # 如果 SkillAttributeModifier 自身能定义持续时间，则 CombatComponent.add_attribute_modifier 需要处理。
    # 为简单起见，这里假设我们直接请求 CombatComponent 添加。

    # 假设 CombatComponent 有一个更通用的添加修改器的方法
    # 或者 AttributeSet 可以直接被访问和修改
    var attr_set : SkillAttributeSet = target.active_attribute_set
    if attr_set:
        # add_modifier_from_effect 可能需要处理持续时间，如果不是永久的
        attr_set.apply_modifier(effect_data.attr, effect_data.attr_modifier) # 使用effect_data的ID作为临时来源

        if effect_data.visual_effect != "":
             request_visual_effect(effect_data.visual_effect, target, {"attribute": effect_data.attr, "value": effect_data.attr_modifier.magnitude})
        
        return {
            "attribute_modified": effect_data.attr, # 假设 modifier_res 有 attribute_type
            "modifier_applied": true
        }
    else:
        push_warning("Target %s has no AttributeSet or add_modifier_from_effect method." % target.name)
        return {"error": "target_cannot_receive_attribute_modifier", "modifier_applied": false}