extends MarginContainer
class_name AttributeLabel

@onready var attribute_name_label: Label = %AttributeNameLabel
@onready var attribute_value_label: Label = %AttributeValueLabel

@export var attribute_id : StringName
var _attribute : SkillAttribute

func setup(attribute_set: SkillAttributeSet) -> void:
	_attribute = attribute_set.get_attribute(attribute_id)
	if not _attribute:
		return

	attribute_name_label.text = _attribute.display_name + " :"
	_attribute.current_value_changed.connect(_on_attribute_current_value_changed)
	_update_display()

func _update_display() -> void:
	attribute_value_label.text = str(_attribute.get_current_value())

func _on_attribute_current_value_changed(_value: float) -> void:
	_update_display()
