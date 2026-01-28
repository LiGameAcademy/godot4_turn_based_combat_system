extends Resource
class_name CharacterDataWithGAS

## 集成 godot_ability_system 的角色配置数据
## 参考 CharacterData，但使用 GameplayAttributeSet 替代 SkillAttributeSet

@export var character_name: String = "英雄"								## 角色名称
@export_multiline var description: String = "一个勇敢的战士"		  	## 描述
@export var attribute_set_resource: GameplayAttributeSet = null			## 属性集资源（使用 GameplayAttributeSet）

## 元素属性 0: 无 1: 火 2: 水 3: 土 4: 光
@export_enum("none", "fire", "water", "earth", "light") var element: int = 0 # ElementTypes.Element.NONE

@export var ai_behavior: AIBehavior = AIBehavior.new()

@export_group("技能列表")
@export var skills: Array[SkillData] = [] # 存储角色拥有的技能（兼容旧系统）
@export var attack_skill : SkillData = null
@export var defense_skill : SkillData = null

@export_group("视觉表现")
@export var animation_library : AnimationLibrary			## 角色动画库
@export var sprite_offset : Vector2 = Vector2.ZERO		## 角色偏移
@export var icon : Texture2D								## 角色图标

# 辅助函数
func get_skill_by_id(id: StringName) -> SkillData:
	for skill in skills:
		if skill and skill.skill_id == id:
			return skill
	return null

func get_skill_by_name(name: String) -> SkillData:
	for skill in skills:
		if skill and skill.skill_name == name:
			return skill
	return null

