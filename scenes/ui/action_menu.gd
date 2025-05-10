# scripts/ui/action_menu.gd
extends Panel
class_name ActionMenu

# 引用UI元素
@onready var attack_button: Button = $HBoxContainer/AttackButton
@onready var defend_button: Button = $HBoxContainer/DefendButton
@onready var skill_button: Button = $HBoxContainer/SkillButton
@onready var item_button: Button = $HBoxContainer/ItemButton

# 信号
signal attack_pressed
signal defend_pressed
signal skill_pressed
signal item_pressed

func _ready():
	# 连接按钮信号
	attack_button.pressed.connect(_on_attack_button_pressed)
	defend_button.pressed.connect(_on_defend_button_pressed)
	skill_button.pressed.connect(_on_skill_button_pressed)
	item_button.pressed.connect(_on_item_button_pressed)

# 设置技能按钮是否可用
func set_skill_button_enabled(enabled: bool) -> void:
	skill_button.disabled = !enabled

# 设置物品按钮是否可用
func set_item_button_enabled(enabled: bool) -> void:
	item_button.disabled = !enabled

# 获取焦点时，默认选中攻击按钮
func grab_focus() -> void:
	attack_button.grab_focus()

# 信号处理函数
func _on_attack_button_pressed() -> void:
	emit_signal("attack_pressed")

func _on_defend_button_pressed() -> void:
	emit_signal("defend_pressed")

func _on_skill_button_pressed() -> void:
	emit_signal("skill_pressed")

func _on_item_button_pressed() -> void:
	emit_signal("item_pressed")