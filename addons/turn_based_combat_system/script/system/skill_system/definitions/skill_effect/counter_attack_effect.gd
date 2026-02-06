extends SkillEffect
class_name CounterAttackEffect

## 反击效果

@export var counter_attack_skill_id: StringName = &"attack" # 用于反击的技能（通常是普攻）

func _get_base_description() -> String:
	return "反击"

func _process_effect(source: Node, target: Node, context : SkillExecutionContext) -> Dictionary:
	if not is_instance_valid(source):
		push_error("CounterAttackEffect: 无效的源节点引用")
		return {
			"success": false,
			"reason": "Invalid source node reference!"
		}
	if not is_instance_valid(target):
		push_error("CounterAttackEffect: 无效的目标节点引用")
		return {
			"success": false,
			"reason": "Invalid target node reference!"
		}
	
	var counter_attacker: Node = source
	var original_attacker: Node = context.damage_info.source

	var original_attacker_combat_component : CharacterCombatComponent = original_attacker.get_combat_component() if original_attacker.has_method("get_combat_component") else null
	if not is_instance_valid(original_attacker_combat_component):
		push_error("CounterAttackEffect: 无效的原始攻击者战斗组件引用")
		return {
			"success": false,
			"reason": "Invalid original attacker combat component reference!"
		}

	# 检查概率和目标有效性
	if not is_instance_valid(original_attacker) or not original_attacker_combat_component.is_alive:
		return {
			"success": false,
			"reason": "original_attacker_invalid"
		}
	
	var source_skill_component : SkillComponentInterface = source.get_skill_component() if source.has_method("get_skill_component") else null
	if not is_instance_valid(source_skill_component):
		push_error("CounterAttackEffect: 无效的源技能组件引用")
		return {
			"success": false,
			"reason": "Invalid source skill component reference!"
		}

	var is_melee: bool = context.damage_info.is_melee
	if not is_melee:
		return {
			"success": false,
			"reason": "counter_attack_failed, only melee skills can counter attack!"
		}
		
	print_rich("[color=yellow]%s 发动了反击！[/color]" % counter_attacker.character_name)

	var result = await source_skill_component.execute_skill(counter_attack_skill_id, [original_attacker], context.to_dictionary())
	if not result.get("success"):
		return {
			"success": false,
			"reason": "counter_attack_failed"
		}

	return {
		"success": true,
		"reason": "counter_attack_success"
	}
