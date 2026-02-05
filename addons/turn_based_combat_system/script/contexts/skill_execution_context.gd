extends ContextBase
class_name SkillExecutionContext 

var battle_manager: BattleManager
var damage_info : DamageInfo
var skill_data: SkillData

func _init(p_battle_manager: BattleManager = null) -> void:
	battle_manager = p_battle_manager

static func from_dictionary(dictionary: Dictionary) -> SkillExecutionContext:
	var context = SkillExecutionContext.new()
	context.battle_manager = dictionary.get("battle_manager", null)
	context.damage_info = dictionary.get("damage_info", null)
	context.skill_data = dictionary.get("skill_data", null)
	return context

func to_dictionary() -> Dictionary:
	return {
		"battle_manager": battle_manager,
		"damage_info": damage_info,
		"skill_data": skill_data
	}