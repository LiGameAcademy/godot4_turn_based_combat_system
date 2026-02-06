extends SkillEffect
class_name RedirectDamage

## 承受伤害效果参数

@export var redirect_damage_percent: float = 0.8    ## 为队友承受多少比例的伤害
@export var self_damage_multiplier: float = 0.5     ## 承受的伤害会乘以这个系数

func _process_effect(source: Node, target: Node, context : SkillExecutionContext) -> Dictionary:
	if not is_instance_valid(source):
		push_error("RedirectDamageEffect: 无效的源节点引用")
		return {
			"success": false,
			"reason": "Invalid source node reference!"
		}
	if not is_instance_valid(target):
		push_error("RedirectDamageEffect: 无效的目标节点引用")
		return {
			"success": false,
			"reason": "Invalid target node reference!"
		}
	
	var guardian: Node = source    ## 守护者
	var original_target: Node = target    ## 被攻击的队友
	var damage_info : DamageInfo = context.damage_info    ## 从事件上下文中获取伤害信息

	var guardian_combat_component : CharacterCombatComponent = guardian.get_combat_component() if guardian.has_method("get_combat_component") else null
	if not is_instance_valid(guardian_combat_component):
		push_error("RedirectDamageEffect: 无效的守护者战斗组件引用")
		return {
			"success": false,
			"reason": "Invalid guardian combat component reference!"
		}
	# 核心逻辑：修改伤害信息对象
	damage_info.is_redirected = true
	damage_info.original_target = original_target

	var redirected_damage : float = damage_info.final_damage * redirect_damage_percent

	# 让守护者承受伤害
	var damage_to_guardian : float = redirected_damage * self_damage_multiplier
	guardian_combat_component.take_damage(damage_to_guardian, source, damage_info.element) # 这里可以简化，直接扣血

	# 减免原目标的伤害
	damage_info.final_damage *= (1.0 - redirect_damage_percent)

	# 请求视觉表现
	_request_visual_effect("guard_action", guardian, context.battle_manager, {"original_target": original_target})

	return  {
		"success": true,
		"original_damage": damage_info.final_damage,
		"modified_damage": damage_info.final_damage
	}

## 获取效果描述
func _get_base_description() -> String:
	var redirect_damage_percent_int : int = int(redirect_damage_percent * 100)
	var self_damage_multiplier_int : int = int(self_damage_multiplier * 100)
	var description : String = "为队友承受 {0}% 伤害, 承受的伤害会乘以 {1}%".format([redirect_damage_percent_int, self_damage_multiplier_int])
	return description
