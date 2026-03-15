extends Control
class_name SkillSelectMenu

## 节点引用
@onready var skill_list: ItemList = %SkillList
@onready var skill_description: RichTextLabel = %SkillDescription
@onready var use_button: Button = %UseButton
@onready var cancel_button: Button = %CancelButton

## 数据存储
var current_character_skills: Array[StringName] = []
var selected_skill_index: int = -1

var _skill_component: SkillComponentInterface = null

## 信号定义
signal skill_selected(skill_id: StringName)
signal skill_selection_cancelled

func _ready() -> void:
	# 连接信号
	if !skill_list.item_selected.is_connected(_on_skill_item_selected):
		skill_list.item_selected.connect(_on_skill_item_selected)
	
	if !skill_list.item_activated.is_connected(_on_skill_item_activated):
		skill_list.item_activated.connect(_on_skill_item_activated)
	
	if !use_button.pressed.is_connected(_on_use_button_pressed):
		use_button.pressed.connect(_on_use_button_pressed)
	
	if !cancel_button.pressed.is_connected(_on_cancel_button_pressed):
		cancel_button.pressed.connect(_on_cancel_button_pressed)
	
	# 初始隐藏并禁用使用按钮
	use_button.disabled = true
	hide()

## 显示技能菜单
func show_menu(skills: Dictionary[StringName, Resource], skill_component: SkillComponentInterface) -> void:
	current_character_skills = skills.keys()
	_skill_component = skill_component
	skill_list.clear()
	skill_description.text = "选择一个技能查看描述..."
	selected_skill_index = -1
	use_button.disabled = true
	var caster_mp: float = skill_component.get_current_mp()

	for i in range(current_character_skills.size()):
		var skill_id: StringName = current_character_skills[i]
		var skill_name : String = skill_component.get_skill_display_name(skill_id)
		var skill_mp_cost: float = skill_component.get_skill_mp_cost(skill_id)
		var item_text = skill_name + " (MP: " + str(skill_mp_cost) + ")"
		skill_list.add_item(item_text)
		
		# 根据MP是否足够，设置项目是否可用
		if caster_mp < skill_mp_cost:
			skill_list.set_item_disabled(i, true)
			skill_list.set_item_custom_fg_color(i, Color(0.5, 0.5, 0.5)) # 灰色表示不可用
	
	# 获取焦点以便键盘操作
	skill_list.grab_focus()
	show()

## 当选择了技能项
func _on_skill_item_selected(index: int) -> void:
	if index >= 0 and index < current_character_skills.size():
		selected_skill_index = index
		var skill_id: StringName = current_character_skills[index]
		skill_description.text = _skill_component.get_skill_description(skill_id)
		use_button.disabled = skill_list.is_item_disabled(index)

## 当双击了技能项
func _on_skill_item_activated(index: int) -> void:
	_on_skill_item_selected(index)
	if !use_button.disabled:
		_on_use_button_pressed()

## 当点击使用按钮
func _on_use_button_pressed() -> void:
	if selected_skill_index >= 0 and selected_skill_index < current_character_skills.size():
		var skill_id: StringName = current_character_skills[selected_skill_index]
		skill_selected.emit(skill_id)
		hide()

## 当点击取消按钮
func _on_cancel_button_pressed() -> void:
	skill_selection_cancelled.emit()
	hide()
