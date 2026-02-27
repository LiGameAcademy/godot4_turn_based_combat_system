extends AbilityPreviewStrategy
class_name TurnBasedUnitSelectionPreviewStrategy

enum TargetType {
	Enemy,      ## 敌人
	Ally,       ## 友方单位（不包含自身）
	AllyIncludingSelf   ## 友方单位包含自身
}

@export var target_type : TargetType = TargetType.Enemy

var _battle_manager : BattleManager
var _caster : Node

func begin(caster: Node, _ability_instance: GameplayAbilityInstance, extra_context: Dictionary = {}) -> void:
	_caster = caster
	_battle_manager = extra_context.get("battle_manager", null)

func cancel() -> void:
	_battle_manager = null
	_caster = null

func get_result_context() -> Dictionary:
	var result : Dictionary
	if not is_instance_valid(_battle_manager):
		return result
	var targets : Array[Node] = []
	if target_type == TargetType.Enemy:
		targets = _battle_manager.get_valid_enemy_targets(_caster)
	elif target_type == TargetType.Ally:
		# 不包含自身
		targets = _battle_manager.get_valid_ally_targets(_caster, false)
	elif target_type == TargetType.AllyIncludingSelf:
		targets = _battle_manager.get_valid_ally_targets(_caster, true)
	result["targets"] = targets
	return result
