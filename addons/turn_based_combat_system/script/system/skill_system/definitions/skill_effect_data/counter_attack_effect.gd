extends SkillEffect
class_name CounterAttackEffect

## 反击效果

@export var counter_attack_skill: SkillData # 用于反击的技能（通常是普攻）

func _get_base_description() -> String:
	return "反击"

func _process_effect(source: Character, _target: Character, context : SkillExecutionContext) -> Dictionary:
	var counter_attacker: Character = source
	var original_attacker: Character = context.damage_info.source

	# 检查概率和目标有效性
	if not is_instance_valid(original_attacker) or not original_attacker.is_alive:
		return {
			"success": false,
			"reason": "original_attacker_invalid"
		}

	var is_melee: bool = context.damage_info.is_melee
	if not is_melee:
		return {
			"success": false,
			"reason": "counter_attack_failed, only melee skills can counter attack!"
		}
		
	print_rich("[color=yellow]%s 发动了反击！[/color]" % counter_attacker.character_name)

	#TODO 这里需要优化，不能直接使用source.execute_skill，因为source可能是CharacterSkillComponent，需要使用CharacterSkillComponent.execute_skill
	var result = await source.execute_skill(counter_attack_skill, counter_attacker, [original_attacker], context)
	if not result.get("success"):
		return {
			"success": false,
			"reason": "counter_attack_failed"
		}

	return {
		"success": true,
		"reason": "counter_attack_success"
	}
