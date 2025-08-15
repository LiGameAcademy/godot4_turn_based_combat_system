extends SkillEffectData
class_name RedirectDamageEffect

@export var redirect_damage_percent: float = 0.8    ## 为队友承受多少比例的伤害
@export var self_damage_multiplier: float = 0.5     ## 承受的伤害会乘以这个系数

func process_effect(source: Character, target: Character, context : SkillExecutionContext) -> Dictionary:
	var guardian: Character = source    ## 守护者
	var original_target: Character = target    ## 被攻击的队友
	var damage_info : DamageInfo = context.damage_info    ## 从事件上下文中获取伤害信息

	# 核心逻辑：修改伤害信息对象
	damage_info.is_redirected = true
	damage_info.original_target = original_target

	var redirected_damage : float = damage_info.final_damage * redirect_damage_percent

	# 让守护者承受伤害
	var damage_to_guardian : float = redirected_damage * self_damage_multiplier
	guardian.combat_component.take_damage(damage_to_guardian) # 这里可以简化，直接扣血

	# 减免原目标的伤害
	damage_info.final_damage *= (1.0 - redirect_damage_percent)

	# 请求视觉表现
	_request_visual_effect("guard_action", guardian, {"original_target": original_target})

	return  {
		"success": true,
		"original_damage": damage_info.final_damage,
		"modified_damage": damage_info.final_damage
	}

## 获取效果描述
func get_description() -> String:
	var redirect_damage_percent_int : int = int(redirect_damage_percent * 100)
	var self_damage_multiplier_int : int = int(self_damage_multiplier * 100)
	var description : String = "为队友承受 {0}% 伤害, 承受的伤害会乘以 {1}%".format([redirect_damage_percent_int, self_damage_multiplier_int])
	return description
