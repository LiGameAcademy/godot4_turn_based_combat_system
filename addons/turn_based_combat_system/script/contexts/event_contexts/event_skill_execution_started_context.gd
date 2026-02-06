extends EventContext
class_name EventSkillExecutionStartedContext

var skill_data: SkillData
var targets: Array[Node]
var skill_execution_context: Dictionary

func _init(p_source: Node, p_skill_data: SkillData, p_targets: Array[Node], p_skill_execution_context: Dictionary) -> void:
	super(p_source)
	skill_data = p_skill_data
	targets = p_targets
	skill_execution_context = p_skill_execution_context
