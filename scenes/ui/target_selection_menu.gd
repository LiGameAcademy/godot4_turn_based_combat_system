extends Control
class_name TargetSelectionMenu

## 信号定义
signal target_selected(target: Character)
signal target_selection_cancelled

## 节点引用
@onready var target_list: ItemList = %TargetList
@onready var select_button: Button = %SelectButton
@onready var cancel_button: Button = %CancelButton

## 数据存储
var available_targets: Array[Character] = []
var selected_target_index: int = -1

func _ready() -> void:
	# 连接信号
	if !target_list.item_selected.is_connected(_on_target_item_selected):
		target_list.item_selected.connect(_on_target_item_selected)
	
	if !target_list.item_activated.is_connected(_on_target_item_activated):
		target_list.item_activated.connect(_on_target_item_activated)
	
	if !select_button.pressed.is_connected(_on_select_button_pressed):
		select_button.pressed.connect(_on_select_button_pressed)
	
	if !cancel_button.pressed.is_connected(_on_cancel_button_pressed):
		cancel_button.pressed.connect(_on_cancel_button_pressed)
	
	# The menu is hidden by default
	hide()
	select_button.disabled = true

## 显示可选目标
func show_targets(targets: Array[Character]) -> void:
	self.available_targets = targets
	target_list.clear()
	selected_target_index = -1
	select_button.disabled = true

	for i in range(targets.size()):
		var character = targets[i]
		if character:
			var item_text = character.character_name + " (HP: " + str(character.current_hp) + "/" + str(character.max_hp) + ")"
			target_list.add_item(item_text)
			
			# 如果目标已死亡，标记为不可选
			if character.current_hp <= 0:
				target_list.set_item_disabled(i, true)
				target_list.set_item_custom_fg_color(i, Color(0.5, 0.5, 0.5))
	
	show()
	target_list.grab_focus()

## 当选择了目标项
func _on_target_item_selected(index: int) -> void:
	if index >= 0 and index < available_targets.size():
		selected_target_index = index
		select_button.disabled = target_list.is_item_disabled(index)

## 当双击了目标项
func _on_target_item_activated(index: int) -> void:
	_on_target_item_selected(index)
	if !select_button.disabled:
		_on_select_button_pressed()

## 当点击选择按钮
func _on_select_button_pressed() -> void:
	if selected_target_index >= 0 and selected_target_index < available_targets.size():
		var target = available_targets[selected_target_index]
		if target and target.current_hp > 0:
			target_selected.emit(target)
			hide()

## 当点击取消按钮
func _on_cancel_button_pressed() -> void:
	target_selection_cancelled.emit()
	hide()