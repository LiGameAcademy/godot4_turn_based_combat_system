extends Resource
class_name CharacterData

@export var character_name: String = "英雄"
@export_multiline var description: String = "一个勇敢的战士。"
@export var attribute_set_resource: SkillAttributeSet		## 导出AttributeSet资源模板（在编辑器中指定）

# 添加元素属性
@export_enum("NONE", "FIRE", "WATER", "EARTH", "AIR") var element: int = 0 # ElementTypes.Element.NONE

@export_group("技能列表")
@export var basic_attack_skill_id: StringName = "" # 基础攻击技能ID
@export var basic_attack_skill_resource: SkillData = null # 基础攻击技能资源
@export var defend_skill_id: StringName = "defend" # 防御技能ID
@export var defend_skill_resource: SkillData = null # 防御技能资源
@export var skills: Array[SkillData] = [] # 存储角色拥有的技能

@export_group("视觉表现")
@export var color: Color = Color.BLUE  # 为原型阶段设置的角色颜色

## 获取技能的辅助方法
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
