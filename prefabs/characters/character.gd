extends Node2D

@onready var character_combat_component: CharacterCombatComponent = %CharacterCombatComponent
@onready var character_ai_component: CharacterAIComponent = %CharacterAIComponent
@onready var gas_skill_component_adapter: GAS_SkillComponentAdapter = $GAS_SkillComponentAdapter

var _character_data : CharacterData

func setup(character_data : CharacterData) -> void:
	_character_data = character_data

func initialize(_battle_manager: BattleManager, _p_cast_marker: Marker2D) -> void:
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
	return _character_data.icon

func play_animation() -> void:
	pass
