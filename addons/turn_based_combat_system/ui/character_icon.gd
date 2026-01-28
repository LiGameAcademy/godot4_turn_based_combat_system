extends MarginContainer
class_name CharacterIcon

@onready var texture_rect: TextureRect = $TextureRect

func setup(character: BaseCombatCharacter) -> void:
	if not texture_rect:
		texture_rect = $TextureRect
	texture_rect.texture = character.character_data.icon
