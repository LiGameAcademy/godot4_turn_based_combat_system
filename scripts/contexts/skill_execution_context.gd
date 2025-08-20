extends ContextBase
class_name SkillExecutionContext 

var battle_manager: BattleManager
var damage_info : DamageInfo

func _init(p_battle_manager: BattleManager = null) -> void:
	battle_manager = p_battle_manager
