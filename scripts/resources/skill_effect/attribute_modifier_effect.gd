extends SkillEffect
class_name AttributeModifierEffect

@export var modifiers: Array[SkillAttributeModifier] = []

func apply(_source: Character, target: Character, _context: Dictionary) -> void:
    if not is_instance_valid(target): return

    for mod in modifiers:
        # 注意：Modifier需要知道它属于哪个属性
        target.skill_component.add_attribute_modifier(mod.attribute_id, mod)

func remove(_source: Character, target: Character, _context: Dictionary) -> void:
    if not is_instance_valid(target): return

    for mod in modifiers:
        target.skill_component.remove_attribute_modifier(mod.attribute_id, mod)