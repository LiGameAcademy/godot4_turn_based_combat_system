extends EventContext
class_name EventActionTagsChangedContext

var restricted_tags: Array[String]

func _init(p_source: Node, p_restricted_tags: Array[String]) -> void:
	super(p_source)
	restricted_tags = p_restricted_tags