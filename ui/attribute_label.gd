extends MarginContainer
class_name AttributeLabel

## 属性标签控件

@onready var attribute_name_label: Label = %AttributeNameLabel
@onready var attribute_value_label: Label = %AttributeValueLabel

@export var attribute_id : StringName

func update_display(attribute_name : StringName, attribute_value : float) -> void:
	attribute_name_label.text = attribute_name + " :"
	attribute_value_label.text = str(attribute_value)
