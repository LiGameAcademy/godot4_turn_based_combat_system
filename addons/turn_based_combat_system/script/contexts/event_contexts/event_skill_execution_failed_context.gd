extends EventContext
class_name EventSkillExecutionFailedContext

var skill_data: SkillData
var targets: Array[Node]
var result: Dictionary

func _init(p_source: Node, p_skill_data: SkillData, p_targets: Array[Node], p_result: Dictionary) -> void:
	super(p_source)
	skill_data = p_skill_data
	targets = p_targets
	result = p_result