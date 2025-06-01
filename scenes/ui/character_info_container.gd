extends VBoxContainer
class_name CharacterInfoContainer

@onready var name_label: Label = %NameLabel
@onready var hp_bar: AttributeStatusBar = %HPBar
@onready var mp_bar: AttributeStatusBar = %MPBar
@onready var skill_status_container: HBoxContainer = %SkillStatusContainer

# 当前绑定的角色
var _character: Character = null

# 状态图标字典，用于快速查找和更新
# Key: status_id (StringName), Value: SkillStatusIcon
var _status_icons: Dictionary = {}

# 状态图标场景
@export var skill_status_icon_scene: PackedScene

## 初始化角色信息容器
## [param character] 要绑定的角色
func initialize(character: Character) -> void:
	if not character:
		push_error("CharacterInfoContainer: 无法初始化，角色为空")
		return
	
	# 清除之前的绑定
	if _character:
		_disconnect_signals()
		clear_status_icons()
	
	# 设置新角色
	_character = character
	
	# 连接信号
	_connect_signals()
	
	# 初始化显示
	_update_name_display()
	_update_attribute_bars()
	_initialize_status_icons()

## 连接信号
func _connect_signals() -> void:
	if not _character or not _character.skill_component:
		return
	
	# 连接属性变化信号
	_character.skill_component.attribute_current_value_changed.connect(_on_attribute_current_value_changed)
	
	# 连接状态变化信号
	_character.skill_component.status_applied.connect(_on_status_applied)
	_character.skill_component.status_removed.connect(_on_status_removed)
	_character.skill_component.status_updated.connect(_on_status_updated)

## 断开信号连接
func _disconnect_signals() -> void:
	if not _character or not _character.skill_component:
		return
	
	# 断开属性变化信号
	if _character.skill_component.attribute_current_value_changed.is_connected(_on_attribute_current_value_changed):
		_character.skill_component.attribute_current_value_changed.disconnect(_on_attribute_current_value_changed)
	
	# 断开状态变化信号
	if _character.skill_component.status_applied.is_connected(_on_status_applied):
		_character.skill_component.status_applied.disconnect(_on_status_applied)
	if _character.skill_component.status_removed.is_connected(_on_status_removed):
		_character.skill_component.status_removed.disconnect(_on_status_removed)
	if _character.skill_component.status_updated.is_connected(_on_status_updated):
		_character.skill_component.status_updated.disconnect(_on_status_updated)

## 更新名称显示
func _update_name_display() -> void:
	if not _character:
		return
	
	name_label.text = _character.character_name

## 更新属性条显示
func _update_attribute_bars() -> void:
	if not _character:
		return
	
	# 获取角色的属性组件
	var skill_comp : CharacterSkillComponent = _character.skill_component
	if not skill_comp:
		return
	
	# 获取HP属性
	var current_hp = skill_comp.get_attribute(&"CurrentHealth")
	var max_hp = skill_comp.get_attribute(&"MaxHealth")
	if current_hp and max_hp:
		hp_bar.setup(current_hp, max_hp)
	
	# 获取MP属性
	var current_mp = skill_comp.get_attribute(&"CurrentMana")
	var max_mp = skill_comp.get_attribute(&"MaxMana")
	if current_mp and max_mp:
		mp_bar.setup(current_mp, max_mp)

## 初始化状态图标
func _initialize_status_icons() -> void:
	if not _character or not _character.skill_component:
		return
	
	# 清除现有的状态图标
	clear_status_icons()
	
	# 获取当前所有状态
	var active_statuses = _character.skill_component.get_all_active_statuses()
	for status in active_statuses:
		_add_status_icon(status)

## 添加状态图标
func _add_status_icon(status_data: SkillStatusData) -> void:
	if not status_data or not skill_status_icon_scene:
		return
	
	# 检查是否已存在该状态的图标
	if _status_icons.has(status_data.status_id):
		# 如果已存在，更新它
		_status_icons[status_data.status_id].update_status(status_data)
		return
	
	# 创建新的状态图标
	var status_icon = skill_status_icon_scene.instantiate()
	if not status_icon is SkillStatusIcon:
		push_error("CharacterInfoContainer: 实例化的状态图标不是SkillStatusIcon类型")
		return
	
	# 添加到容器
	skill_status_container.add_child(status_icon)
	
	# 设置状态数据
	status_icon.setup(status_data)
	
	# 保存到字典中
	_status_icons[status_data.status_id] = status_icon

## 移除状态图标
func _remove_status_icon(status_id: StringName) -> void:
	if not _status_icons.has(status_id):
		return
	
	# 获取图标
	var status_icon = _status_icons[status_id]
	
	# 从字典中移除
	_status_icons.erase(status_id)
	
	# 从容器中移除并释放
	status_icon.queue_free()

## 清除所有状态图标
func clear_status_icons() -> void:
	# 清除所有状态图标
	for status_id in _status_icons.keys():
		var status_icon = _status_icons[status_id]
		status_icon.queue_free()
	
	# 清空字典
	_status_icons.clear()

## 属性当前值变化回调
func _on_attribute_current_value_changed(
		attribute: SkillAttribute, 
		_old_value: float, 
		_new_value: float, 
		_source: Variant) -> void:
	# 检查是否是HP或MP属性
	if attribute.attribute_name == &"CurrentHealth" or attribute.attribute_name == &"MaxHealth":
		# 更新HP条
		var current_hp = _character.skill_component.get_attribute(&"CurrentHealth")
		var max_hp = _character.skill_component.get_attribute(&"MaxHealth")
		if current_hp and max_hp:
			hp_bar.setup(current_hp, max_hp)
	
	elif attribute.attribute_name == &"CurrentMana" or attribute.attribute_name == &"MaxMana":
		# 更新MP条
		var current_mp = _character.skill_component.get_attribute(&"CurrentMana")
		var max_mp = _character.skill_component.get_attribute(&"MaxMana")
		if current_mp and max_mp:
			mp_bar.setup(current_mp, max_mp)

## 状态应用回调
func _on_status_applied(status_instance: SkillStatusData) -> void:
	_add_status_icon(status_instance)

## 状态移除回调
func _on_status_removed(status_id: StringName, _status_instance_data_before_removal: SkillStatusData) -> void:
	_remove_status_icon(status_id)

## 状态更新回调
func _on_status_updated(status_instance: SkillStatusData, _old_stacks: int, _old_duration: int) -> void:
	# 更新状态图标
	if _status_icons.has(status_instance.status_id):
		_status_icons[status_instance.status_id].update_status(status_instance)
