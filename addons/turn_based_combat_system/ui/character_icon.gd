extends MarginContainer
class_name CharacterIcon

## 角色图标控件

@onready var texture_rect: TextureRect = $TextureRect

func setup(icon: Texture2D) -> void:
	if not is_instance_valid(icon):
		push_error("角色图标不能为空！")
		return
	if not is_instance_valid(texture_rect):
		texture_rect = $TextureRect
	if not is_instance_valid(texture_rect):
		push_error("角色图标控件不能为空！")
		return
	texture_rect.texture = icon
