extends Node
class_name AudioManager

# 音频管理器：负责音效播放、背景音乐与音量控制。

const CLICK_SOUND := preload("res://assets/sound/普通点击miao.mp3")
const SUCCESS_SOUND := preload("res://assets/sound/连接正确small-victory.mp3")
const SUCCESS_SLOW_SOUND := preload("res://assets/sound/连接正确但10秒间隔以上.mp3")
const ERROR_SOUND := preload("res://assets/sound/error.mp3")
const GAME_WON_SOUND := preload("res://assets/sound/game-won.mp3")
const LEVEL_COMPLETE_MUSIC := preload("res://assets/sound/欢乐音乐17秒（用于关卡顺利完成.mp3")
const LEVEL_VICTORY_SOUND := preload("res://assets/sound/胜利两秒（用于中间关卡胜利）.mp3")
const GAME_OVER_SOUND := preload("res://assets/sound/游戏结束.mp3")
const BGM_TRACKS: Array[AudioStream] = [
	preload("res://assets/sound/背景音乐之欢快钢琴21秒.mp3"),
	preload("res://assets/sound/背景音乐之吉他40秒音乐.mp3")
]
# 背景音乐相对主音量的缩放比例（当前保留常量但保持与原代码一致的行为）
const BGM_VOLUME_SCALE := 0.35

var _audio_player: AudioStreamPlayer
var _bgm_player: AudioStreamPlayer

var _master_volume: float = 0.8
var _sfx_volume: float = 0.8
var _bgm_volume: float = 0.5
var _sound_effects_enabled: bool = true
var _background_music_enabled: bool = true


func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.stream = null
	add_child(_bgm_player)

	# 设置背景音乐单曲循环
	for track: AudioStream in BGM_TRACKS:
		track.loop = true


# 一次性配置所有音量和开关
func configure(master: float, sfx: float, bgm: float, sfx_enabled: bool, bgm_enabled: bool) -> void:
	_master_volume = master
	_sfx_volume = sfx
	_bgm_volume = bgm
	_sound_effects_enabled = sfx_enabled
	_background_music_enabled = bgm_enabled
	_update_background_music()


# 播放音效
func play_sound(stream: AudioStream) -> void:
	if not _sound_effects_enabled:
		return
	_audio_player.volume_db = linear_to_db(_master_volume * _sfx_volume)
	_audio_player.stream = stream
	_audio_player.play()


# 随机挑选一首背景音乐并开始播放
func play_random_bgm() -> void:
	var track: AudioStream = BGM_TRACKS[randi() % BGM_TRACKS.size()]
	_bgm_player.stop()
	_bgm_player.stream = track
	_update_background_music()


# 播放指定背景音乐（用于通关庆祝等一次性音乐）
func play_bgm(stream: AudioStream) -> void:
	_bgm_player.stop()
	_bgm_player.stream = stream
	_bgm_player.volume_db = linear_to_db(_master_volume * _bgm_volume)
	_bgm_player.play()


# 停止背景音乐
func stop_bgm() -> void:
	_bgm_player.stop()


# 更新背景音乐播放状态
func _update_background_music() -> void:
	if _bgm_player.stream == null:
		return
	_bgm_player.volume_db = linear_to_db(_master_volume * _bgm_volume)
	if _background_music_enabled:
		if not _bgm_player.playing:
			_bgm_player.play()
	else:
		_bgm_player.stop()


# 单独更新音量
func set_volumes(master: float, sfx: float, bgm: float) -> void:
	_master_volume = master
	_sfx_volume = sfx
	_bgm_volume = bgm
	_update_background_music()


# 单独更新开关
func set_sfx_enabled(enabled: bool) -> void:
	_sound_effects_enabled = enabled


func set_bgm_enabled(enabled: bool) -> void:
	_background_music_enabled = enabled
	_update_background_music()
