# scripts/managers/audio_manager.gd (设为Autoload: AudioManager)
extends Node
class_name AudioManager

# 预加载常用的音效资源
@export var sfx_library: Dictionary = {
    # &"attack_swing": preload("res://assets/sfx/attack_swing.wav"),
    # &"attack_hit_flesh": preload("res://assets/sfx/hit_flesh.wav"),
    # &"attack_hit_armor": preload("res://assets/sfx/hit_armor.wav"),
    # &"skill_cast_fire": preload("res://assets/sfx/cast_fire.wav"),
    # &"skill_impact_heal": preload("res://assets/sfx/impact_heal.wav"),
    # &"status_buff_apply": preload("res://assets/sfx/buff_apply.wav"),
    # &"status_debuff_apply": preload("res://assets/sfx/debuff_apply.wav"),
    &"ui_button_click": preload("res://assets/sfx/ui_click.ogg"),
    # &"battle_victory": preload("res://assets/music/victory_fanfare.ogg"), # 也可以管理短音乐片段
    # &"battle_defeat": preload("res://assets/music/defeat_jingle.ogg")
}

@export var default_bus_name: String = "Master" # 默认播放总线
@export var sfx_pool_size: int = 10 # 同时播放音效的最大数量

var _sfx_players: Array[AudioStreamPlayer] = []

func _ready():
    # 初始化音效播放器对象池
    for i in range(sfx_pool_size):
        var player = AudioStreamPlayer.new()
        player.bus = default_bus_name # 设置音频总线
        add_child(player) # AudioManager 作为节点，需要将播放器作为其子节点才能正常工作
        _sfx_players.append(player)
    print("AudioManager initialized with %d SFX players." % sfx_pool_size)

## 播放音效
func play_sfx(sfx_key: StringName, volume_db_offset: float = 0.0, pitch_scale: float = 1.0, bus: String = ""):
    var stream: AudioStream = sfx_library.get(sfx_key)
    if not stream:
        push_warning("AudioManager: SFX key '%s' not found in library." % sfx_key)
        return

    var player_found = false
    for player_node in _sfx_players:
        if not player_node.playing:
            player_node.stream = stream
            player_node.volume_db = volume_db_offset # 基础音量来自stream，再做偏移
            # Godot 4 中 AudioStreamPlayer 的音量是 stream 自身的音量 + volume_db
            # 如果想让 stream 保持原始音量，volume_db_offset 就是实际的音量调整
            # 如果 stream 音量为0，则 volume_db_offset 就是绝对音量
            # 此处假设 stream 的音量已在导入时设置好，volume_db_offset 是额外的调整
            player_node.pitch_scale = pitch_scale
            if bus != "" and AudioServer.get_bus_index(bus) != -1: # 检查总线是否存在
                player_node.bus = bus
            else:
                player_node.bus = default_bus_name
            player_node.play()
            player_found = true
            break
    
    if not player_found:
        push_warning("AudioManager: All SFX players are busy. SFX '%s' might not play or will cut off another." % sfx_key)
        # 可以选择强制播放（覆盖最旧的），或者简单地丢弃本次播放请求
        # _sfx_players[0].stop() # 示例：强制停止第一个播放器
        # _sfx_players[0].stream = stream ... play()

# TODO: BGM 管理方法 (play_bgm, stop_bgm, fade_bgm 等)
