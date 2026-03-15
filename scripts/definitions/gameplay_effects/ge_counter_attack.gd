extends GameplayEffect
class_name GE_CounterAttack

## 反击效果

@export var counter_attack_ability_id : StringName = "attack"
@export var ability_component_name : StringName = "GameplayAbilityComponent"

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	var damage_info: GameplayDamageInfo = context.get("damage_info")
	var ability_component : GameplayAbilityComponent = GameplayAbilitySystem.get_component_by_interface(target, ability_component_name)
	ability_component.try_activate_ability(counter_attack_ability_id, {
		"targets": [damage_info.instigator] as Array[Node],
	})
