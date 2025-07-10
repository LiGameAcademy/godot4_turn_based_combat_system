extends MarginContainer
class_name BattleLogPanel

# 日志类型枚举
enum LogType {
	INFO,     # 普通信息
	ATTACK,   # 攻击行为
	DEFEND,   # 防御行为
	SKILL,    # 技能使用
	ITEM,     # 道具使用
	DAMAGE,   # 伤害信息
	HEAL,     # 治疗信息
	STATUS,   # 状态效果
	SYSTEM    # 系统信息
}

# 日志颜色配置
const LOG_COLORS = {
	LogType.INFO: "white",
	LogType.ATTACK: "yellow",
	LogType.DEFEND: "#80bfff", # 浅蓝色
	LogType.SKILL: "#ff9966", # 橙色
	LogType.ITEM: "#99cc00",  # 浅绿色
	LogType.DAMAGE: "#ff3333", # 红色
	LogType.HEAL: "#00cc66",   # 绿色
	LogType.STATUS: "#cc99ff", # 紫色
	LogType.SYSTEM: "#cccccc"  # 灰色
}

# 最大日志条目数
const MAX_LOG_ENTRIES = 50

# UI组件引用
@onready var battle_info: RichTextLabel = %BattleInfo
@onready var title_label: Label = %TitleLabel
@onready var filter_button: Button = %FilterButton
@onready var clear_button: Button = %ClearButton
@onready var filter_popup: PopupPanel = %FilterPopup

# 过滤器复选框
@onready var info_checkbox: CheckBox = %InfoCheckBox
@onready var attack_checkbox: CheckBox = %AttackCheckBox
@onready var defend_checkbox: CheckBox = %DefendCheckBox
@onready var skill_checkbox: CheckBox = %SkillCheckBox
@onready var item_checkbox: CheckBox = %ItemCheckBox
@onready var damage_checkbox: CheckBox = %DamageCheckBox
@onready var heal_checkbox: CheckBox = %HealCheckBox
@onready var status_checkbox: CheckBox = %StatusCheckBox
@onready var apply_button: Button = %ApplyButton

# 日志存储
var _log_entries: Array = []

# 过滤设置
var _filter_enabled: bool = false
var _active_filters: Array[LogType] = []

func _ready() -> void:
	# 初始化
	battle_info.clear()
	_log_entries.clear()
	
	# 连接按钮信号
	filter_button.pressed.connect(_on_filter_button_pressed)
	clear_button.pressed.connect(_on_clear_button_pressed)
	apply_button.pressed.connect(_on_apply_button_pressed)
	
	# 添加测试日志
	if OS.is_debug_build():
		_add_test_logs()

## 添加一条日志
func add_log(message: String, log_type: LogType = LogType.INFO, details: String = "") -> void:
	# 创建日志条目
	var timestamp = Time.get_time_string_from_system()
	var log_entry = {
		"timestamp": timestamp,
		"message": message,
		"type": log_type,
		"details": details
	}
	
	# 添加到日志数组
	_log_entries.append(log_entry)
	
	# 如果超过最大条目数，移除最早的条目
	if _log_entries.size() > MAX_LOG_ENTRIES:
		_log_entries.pop_front()
	
	# 更新显示
	_update_log_display()

## 清空日志
func clear_log() -> void:
	_log_entries.clear()
	battle_info.clear()

## 设置过滤器
func set_filter(log_types: Array[LogType]) -> void:
	_active_filters = log_types
	_filter_enabled = !_active_filters.is_empty()
	_update_log_display()

## 禁用过滤器
func disable_filter() -> void:
	_filter_enabled = false
	_active_filters.clear()
	_update_log_display()

## 更新日志显示
func _update_log_display() -> void:
	# 清空当前显示
	battle_info.clear()
	
	# 应用过滤器并显示日志
	for entry in _log_entries:
		# 如果过滤器启用且该类型不在过滤器中，则跳过
		if _filter_enabled and not entry["type"] in _active_filters:
			continue
		
		# 获取颜色
		var color = LOG_COLORS[entry["type"]]
		
		# 格式化并添加日志条目
		var formatted_log = "[color=%s][%s] %s[/color]" % [color, entry["timestamp"], entry["message"]]
		
		# 如果有详细信息，添加可折叠的详情
		if not entry["details"].is_empty():
			formatted_log += "\n  [color=#aaaaaa]%s[/color]" % entry["details"]
		
		# 添加到富文本
		battle_info.append_text(formatted_log)
		battle_info.add_text("\n\n") # 添加空行分隔
	
	# 滚动到底部
	# 使用 call_deferred 确保在内容完全更新后再滚动
	call_deferred("_scroll_to_bottom")

## 添加攻击日志
func log_attack(attacker: String, target: String, damage: int) -> void:
	var message = "%s 攻击了 %s" % [attacker, target]
	var details = "造成了 %d 点伤害" % damage
	add_log(message, LogType.ATTACK, details)

## 添加防御日志
func log_defend(character: String) -> void:
	var message = "%s 选择了防御" % character
	add_log(message, LogType.DEFEND)

## 滚动到日志底部
func _scroll_to_bottom() -> void:
	# 确保滚动到最后一行
	if battle_info.get_line_count() > 0:
		# 使用最大值确保滚动到底部
		#battle_info.scroll_vertical = battle_info.get_content_height()
		# 另一种方法是滚动到最后一行
		battle_info.scroll_to_line(battle_info.get_line_count() - 1)

## 添加技能日志
func log_skill(caster: String, skill_name: String, targets: Array, effects: String) -> void:
	var targets_str = ", ".join(targets) if targets.size() > 0 else "自身"
	var message = "%s 使用了技能 %s" % [caster, skill_name]
	var details = "目标: %s\n效果: %s" % [targets_str, effects]
	add_log(message, LogType.SKILL, details)

## 添加道具日志
func log_item(user: String, item_name: String, target: String, effect: String) -> void:
	var message = "%s 对 %s 使用了 %s" % [user, target, item_name]
	add_log(message, LogType.ITEM, effect)

## 添加伤害日志
func log_damage(target: String, amount: int, source: String) -> void:
	var message = "%s 受到了 %d 点伤害" % [target, amount]
	var details = "来源: %s" % source
	add_log(message, LogType.DAMAGE, details)

## 添加治疗日志
func log_heal(target: String, amount: int, source: String) -> void:
	var message = "%s 恢复了 %d 点生命值" % [target, amount]
	var details = "来源: %s" % source
	add_log(message, LogType.HEAL, details)

## 添加状态效果日志
func log_status_effect(target: String, effect_name: String, is_applied: bool) -> void:
	var action = "获得" if is_applied else "解除"
	var message = "%s %s了状态 %s" % [target, action, effect_name]
	add_log(message, LogType.STATUS)

## 添加系统日志
func log_system(message: String) -> void:
	add_log(message, LogType.SYSTEM)

## 处理过滤按钮点击
func _on_filter_button_pressed() -> void:
	# 显示过滤器弹窗
	filter_popup.popup_centered()

## 处理清除按钮点击
func _on_clear_button_pressed() -> void:
	clear_log()
	log_system("日志已清除")

## 处理应用过滤按钮点击
func _on_apply_button_pressed() -> void:
	# 收集所有选中的过滤器类型
	var selected_filters: Array[LogType] = []
	
	if info_checkbox.button_pressed:
		selected_filters.append(LogType.INFO)
	
	if attack_checkbox.button_pressed:
		selected_filters.append(LogType.ATTACK)
	
	if defend_checkbox.button_pressed:
		selected_filters.append(LogType.DEFEND)
	
	if skill_checkbox.button_pressed:
		selected_filters.append(LogType.SKILL)
	
	if item_checkbox.button_pressed:
		selected_filters.append(LogType.ITEM)
	
	if damage_checkbox.button_pressed:
		selected_filters.append(LogType.DAMAGE)
	
	if heal_checkbox.button_pressed:
		selected_filters.append(LogType.HEAL)
	
	if status_checkbox.button_pressed:
		selected_filters.append(LogType.STATUS)
	
	# 应用过滤器
	if selected_filters.is_empty():
		disable_filter()
		log_system("已显示所有日志类型")
	else:
		set_filter(selected_filters)
		log_system("已应用日志过滤器")
	
	# 关闭弹窗
	filter_popup.hide()

## 添加测试日志
func _add_test_logs() -> void:
	# 添加一些测试日志条目
	log_system("战斗开始!")
	log_attack("英雄", "哥布林", 25)
	log_defend("精灵法师")
	log_skill("法师", "火球术", ["哥布林", "小哥布林"], "造成区域伤害")
	log_item("战士", "生命药水", "战士", "恢复50点生命值")
	log_damage("精灵法师", 30, "哥布林的攻击")
	log_heal("战士", 50, "生命药水")
	log_status_effect("哥布林", "中毒", true)
	log_system("玩家回合开始")
