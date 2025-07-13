extends Node
class_name BattleCharacterRegistryManager

## 参与战斗的角色注册管理器
## 负责管理战斗中的角色注册和反注册
## 包括队伍管理和角色状态跟踪

var _all_characters: Array[Character] = []			## 存储所有参与战斗的角色 (包括玩家和敌人)
var _player_team: Array[Character] = []				## 玩家队伍
var _enemy_team: Array[Character] = []				## 敌人队伍

signal character_registered(character: Character)							## 角色注册信号
signal character_unregistered(character: Character)							## 角色反注册信号
signal team_changed(team_characters: Array[Character], team_id: String)		## 队伍变化信号

## 初始化
func initialize() -> void:
	_all_characters.clear()
	_player_team.clear()
	_enemy_team.clear()
	print("CharacterRegistryManager initialized.")

## 注册一个角色到战斗中
## [param character] 要注册的角色
## [param is_player_team] 是否是玩家队伍
## [return] 是否注册成功
func register_character(character: Character, is_player_team: bool) -> bool:
	if not is_instance_valid(character):
		push_error("Attempted to register an invalid character instance.")
		return false
	
	if character in _all_characters:
		push_warning("Character %s is already registered." % character.character_name)
		return false

	_all_characters.append(character)
	if is_player_team:
		_player_team.append(character)
		team_changed.emit(_player_team, "player")
	else:
		_enemy_team.append(character)
		team_changed.emit(_enemy_team, "enemy")
		
	# 连接角色死亡信号，以便自动反注册
	if not character.character_defeated.is_connected(_on_character_defeated):
		character.character_defeated.connect(_on_character_defeated.bind(character))
		
	character_registered.emit(character)
	print("Character registered: %s (Player Team: %s)" % [character.character_name, is_player_team])
	return true

## 从战斗中反注册一个角色
## [param character] 要反注册的角色
## [return] 是否反注册成功
func unregister_character(character: Character) -> bool:
	if not is_instance_valid(character) or not character in _all_characters:
		push_warning("Attempted to unregister a character (%s) not found in the registry." % character)
		return false

	_all_characters.erase(character)
	var team_id_changed = ""
	if character in _player_team:
		_player_team.erase(character)
		team_id_changed = "player"
	elif character in _enemy_team:
		_enemy_team.erase(character)
		team_id_changed = "enemy"
	
	if character.character_defeated.is_connected(_on_character_defeated):
		character.character_defeated.disconnect(_on_character_defeated)

	character_unregistered.emit(character)
	if team_id_changed == "player":
		team_changed.emit(_player_team, "player")
	elif team_id_changed == "enemy":
		team_changed.emit(_enemy_team, "enemy")
		
	print("Character unregistered: %s" % character.character_name)
	return true

## 获取所有已注册的角色
## [return] 所有已注册的角色
func get_all_characters() -> Array[Character]:
	return _all_characters

## 获取所有存活的角色
## [return] 所有存活的角色
func get_all_living_characters() -> Array[Character]:
	var living_chars: Array[Character] = []
	for character in _all_characters:
		if is_instance_valid(character) and character.is_alive:
			living_chars.append(character)
	return living_chars

## 获取玩家队伍的角色
## [param is_only_alive] 是否只返回存活的角色
## [return] 玩家队伍的角色
func get_player_team(is_only_alive: bool = false) -> Array[Character]:
	if is_only_alive:
		var living_players: Array[Character] = []
		for character in _player_team:
			if is_instance_valid(character) and character.is_alive:
				living_players.append(character)
		return living_players
	return _player_team

## 获取敌人队伍的角色
## [param is_only_alive] 是否只返回存活的角色
## [return] 敌人队伍的角色
func get_enemy_team(is_only_alive: bool = false) -> Array[Character]:
	if is_only_alive:
		var living_enemies: Array[Character] = []
		for character in _enemy_team:
			if is_instance_valid(character) and character.is_alive:
				living_enemies.append(character)
		return living_enemies
	return _enemy_team

## 清空所有注册信息 (例如战斗结束时)
func clear_registry() -> void:
	# 在移除前断开所有连接，避免悬空引用问题
	for character in _all_characters:
		if is_instance_valid(character) and character.character_defeated.is_connected(_on_character_defeated):
			character.character_defeated.disconnect(_on_character_defeated)
			
	_all_characters.clear()
	_player_team.clear()
	_enemy_team.clear()
	print("Character registry cleared.")
	team_changed.emit(_player_team, "player") # 发送空数组信号
	team_changed.emit(_enemy_team, "enemy")   # 发送空数组信号

## 检查特定队伍是否全部被击败
## [param is_player_team_check] 是否检查玩家队伍
## [return] 是否全部被击败
func is_team_defeated(is_player_team_check: bool) -> bool:
	var team_to_check = _player_team if is_player_team_check else _enemy_team
	if team_to_check.is_empty(): # 如果队伍一开始就为空，根据游戏逻辑判断是否算作失败
		return true # 或者 false，取决于你的游戏规则
		
	for character in team_to_check:
		if is_instance_valid(character) and character.is_alive:
			return false # 只要有一个存活，队伍就未被击败
	return true # 所有角色都已死亡

## 检查角色是否在玩家队伍
## [param character] 要检查的角色
## [return] 是否在玩家队伍
func is_player_character(character: Character) -> bool:
	return character in _player_team

## 获取角色的友方队伍
## [param character] 目标角色
## [param include_self] 是否包含自己
## [return] 友方队伍角色列表
func get_allied_team_for_character(character: Character, include_self: bool = true) -> Array[Character]:
	var team: Array[Character] = []
	if is_player_character(character):
		# 玩家角色的盟友是玩家队伍
		team = get_player_team(true)
	else:
		# 敌人角色的盟友是敌人队伍
		team = get_enemy_team(true)
	
	# 如果不包含自己，则移除
	if not include_self and character in team:
		var filtered_team: Array[Character] = []
		for ally in team:
			if ally != character:
				filtered_team.append(ally)
		return filtered_team
	
	return team

## 获取角色的敌对队伍
## [param character] 目标角色
## [return] 敌对队伍角色列表
func get_opposing_team_for_character(character: Character) -> Array[Character]:
	if not is_instance_valid(character):
		push_error("cannot get opposing team for character, character is null!")
		return []
	if is_player_character(character):
		# 玩家角色的敌人是敌人队伍
		return get_enemy_team(true)
	else:
		# 敌人角色的敌人是玩家队伍
		return get_player_team(true)

## 判断是否为敌人
func is_enemy_of(character: Character, target: Character) -> bool:
	return target in get_opposing_team_for_character(character)

#region --- 信号处理 ---
## 当角色被击败时自动反注册
## [param defeated_character] 被击败的角色
func _on_character_defeated(defeated_character: Character) -> void:
	print("Character %s defeated, attempting to unregister." % defeated_character.character_name)
	unregister_character(defeated_character)
	# BattleManager 可能还需要处理其他逻辑，比如检查战斗是否结束
#endregion
