extends SkillEffect
class_name ActionRestrictionEffect

@export var restricted_categories: Array[String] = []

func apply(_source: Character, target: Character, _context: Dictionary) -> void:
    if not is_instance_valid(target): return
    target.skill_component._add_action_restrictions(restricted_categories)

func remove(_source: Character, target: Character, _context: Dictionary) -> void:
    if not is_instance_valid(target): return
    target.skill_component._remove_action_restrictions(restricted_categories)