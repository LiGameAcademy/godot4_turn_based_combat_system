extends Node2D

@onready var character_combat_component: CharacterCombatComponent = %CharacterCombatComponent
@onready var character_ai_component: CharacterAIComponent = %CharacterAIComponent
@onready var gas_skill_component_adapter: GAS_SkillComponentAdapter = $GAS_SkillComponentAdapter

func initialize(battle_manager: BattleManager, p_cast_marker: Marker2D) -> void:
	pass

func get_combat_component() -> CharacterCombatComponent:
	return character_combat_component

func get_skill_component() -> SkillComponentInterface:
	return gas_skill_component_adapter

func get_ai_component() -> CharacterAIComponent:
	return character_ai_component
	
func get_character_name() -> String:
	return ""

func get_icon() -> Texture2D:
	return null

func play_animation() -> void:
	pass
