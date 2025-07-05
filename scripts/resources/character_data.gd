extends Resource
class_name CharacterData

@export var character_name: String = "英雄"								## 角色名称
@export_multiline var description: String = "一个勇敢的战士"		  	## 描述
@export var attribute_set_resource: SkillAttributeSet = null			## 属性模版

## 元素属性
@export_enum("none", "fire", "water", "earth", "light") var element: int = 0 # ElementTypes.Element.NONE

@export_group("技能列表")
@export var skills: Array[SkillData] = [] # 存储角色拥有的技能
@export var attack_skill : SkillData = null
@export var defense_skill : SkillData = null

@export_group("视觉表现")
@export var color: Color = Color.BLUE  # 为原型阶段设置的角色颜色

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
