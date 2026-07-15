extends Control

# 主游戏控制器：管理 7×12 连连看棋盘、倒计时、路径匹配、UI 交互与胜负判定。

enum GameState {PLAYING, GAME_OVER}

# ------------------------------
# 模块：游戏常量
# 说明：棋盘尺寸、移动方向、关卡与倒计时相关常量
# ------------------------------
# 默认棋盘尺寸（宝可梦图版 / 经典高级难度使用）
const ROWS := 7
const COLS := 12
const PAIRS := 42
const MIN_MATCHABLE_PAIRS := 5
const DIRECTIONS := [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1)]

# 经典图版各难度的棋盘尺寸（行, 列）与图块文件夹
const CLASSIC_LEVELS := {
	1: {"rows": 7, "cols": 12, "folder": "level1"},
	2: {"rows": 8, "cols": 14, "folder": "level2"},
	3: {"rows": 9, "cols": 16, "folder": "level3"},
}

# 宝可梦图版各难度的棋盘尺寸与图块数量
const POKEMON_LEVELS := {
	1: {"rows": 6, "cols": 10, "tile_count": 14},
	2: {"rows": 8, "cols": 12, "tile_count": 28},
	3: {"rows": 8, "cols": 14, "tile_count": 42},
}

const LEVEL_NAMES := {
	1: "不变",
	2: "向左/右",
	3: "向上/下",
	4: "向外扩",
	5: "向内聚",
	6: "向左右扩",
	7: "向上下扩",
	8: "向竖中线聚",
	9: "向横中线聚",
	10: "左扩右聚"
}

enum Level2Dir {LEFT, RIGHT}
enum Level4Dir {UP, DOWN}

const MAX_TIME := 60.0
const TIME_BONUS := 15.0

# 棋盘整体缩放比例：1.0 表示棋盘占满可用空间，让棋子尽可能大
const BOARD_SCALE := 0.95

const CLICK_SOUND := preload("res://assets/sound/普通点击miao.mp3")
const SUCCESS_SOUND := preload("res://assets/sound/连接正确small-victory.mp3")
const SUCCESS_SLOW_SOUND := preload("res://assets/sound/连接正确但10秒间隔以上.mp3")
const ERROR_SOUND := preload("res://assets/sound/error.mp3")
const GAME_WON_SOUND := preload("res://assets/sound/game-won.mp3")
const LEVEL_COMPLETE_MUSIC := preload("res://assets/sound/欢乐音乐17秒（用于关卡顺利完成.mp3")
const LEVEL_VICTORY_SOUND := preload("res://assets/sound/胜利两秒（用于中间关卡胜利）.mp3")
const GAME_OVER_SOUND := preload("res://assets/sound/游戏结束.mp3")
const FIREWORKS_SCENE := preload("res://fireworks.tscn")
const BGM_TRACKS: Array[AudioStream] = [
	preload("res://assets/sound/背景音乐之欢快钢琴21秒.mp3"),
	preload("res://assets/sound/背景音乐之吉他40秒音乐.mp3")
]
# 背景音乐相对主音量的缩放比例（0.5 表示背景音乐为主音量的一半）
const BGM_VOLUME_SCALE := 0.35

# ------------------------------
# 模块：棋盘尺寸与图块数量 —— 根据当前图版和难度动态计算
# ------------------------------
func _get_rows() -> int:
	match Cell.current_skin:
		Cell.TileSkin.CLASSIC:
			return CLASSIC_LEVELS[current_difficulty]["rows"]
		Cell.TileSkin.POKEMON:
			return POKEMON_LEVELS[current_difficulty]["rows"]
	return ROWS

func _get_cols() -> int:
	match Cell.current_skin:
		Cell.TileSkin.CLASSIC:
			return CLASSIC_LEVELS[current_difficulty]["cols"]
		Cell.TileSkin.POKEMON:
			return POKEMON_LEVELS[current_difficulty]["cols"]
	return COLS

func _get_pairs() -> int:
	return int((_get_rows() * _get_cols()) / 2.0)

# 读取当前图版对应难度下实际要使用的图块数量
func _get_skin_tile_count(difficulty: int) -> int:
	match Cell.current_skin:
		Cell.TileSkin.CLASSIC:
			# 经典图案素材已统一集中到 level3，所有难度共用。
			# 直接返回 Cell 中预加载的纹理数量，避免导出后 DirAccess
			# 扫描目录不可靠导致图块数量计算错误。
			return Cell.get_texture_count(Cell.TileSkin.CLASSIC)
		Cell.TileSkin.POKEMON:
			# 防止配置的数量超过实际已打包的纹理数量
			return mini(POKEMON_LEVELS[difficulty]["tile_count"], Cell.get_texture_count(Cell.TileSkin.POKEMON))
	return _get_pairs()

# 指定难度下完整棋盘应有的对数
func _get_pairs_for_difficulty(difficulty: int, levels: Dictionary = CLASSIC_LEVELS) -> int:
	return int((levels[difficulty]["rows"] * levels[difficulty]["cols"]) / 2.0)

# ------------------------------
# 模块：游戏状态与运行数据
# 说明：当前对局状态、棋盘数据、选中索引、历史记录、设置等
# ------------------------------
var game_state: GameState
var board: Array = []
var selected_index: int = -1
var pairs_left: int = 0
var remaining_time: float = MAX_TIME

var move_history: Array[Dictionary] = []
var undo_history: Array[Dictionary] = []

var _hint_active: bool = false
var _timer_running: bool = false
var _is_paused: bool = false
var _is_animating: bool = false
var _timer_pulse_tween: Tween = null
var _compact_timer_pulse_tween: Tween = null

var _ui_hidden: bool = false
var _top_leave_time: float = 0.0
var _auto_hide_hint_count: int = 0
var _hint_flash_tween: Tween = null

var _last_points: int = 0
var _combo_count: int = 0

const AUTO_HIDE_HINT_MAX := 1           # 每局游戏最多显示几次恢复提示

# 鼠标按键状态（用于左右键同时按下的洗牌快捷键）
var _left_mouse_pressed: bool = false
var _right_mouse_pressed: bool = false
var _left_press_time: int = 0
var _right_press_time: int = 0
const MOUSE_COMBO_WINDOW_MS := 150

# 顶部 UI 自动隐藏相关常量
const AUTO_HIDE_DELAY := 5.0          # 游戏开始后多久自动隐藏顶部 UI
const TOP_TRIGGER_HEIGHT := 24.0      # 鼠标移到屏幕顶部多少像素内触发显示
const TOP_HIDE_DELAY := 1.5           # 鼠标离开顶部后多久恢复紧凑 UI

# 加分反馈相关常量
const SCHEME_1_FLOATING_TEXT_ENABLED := true  # 方案 1：消除位置飘字（可独立开关）
const COMBO_FAST_THRESHOLD := 10.0            # 多少秒内消除算一次连击
const SCORE_COLOR_GOLD := "#FFD700"
const SCORE_COLOR_SILVER := "#E0E0E0"
const SCORE_COLOR_BRONZE := "#FF8C00"
const SCORE_COLOR_NORMAL := "#FFFFFF"

# 自定义弹窗类型与回调
enum DialogType {WELCOME, RULES, ABOUT, SHORTCUTS, SCORE_RULES, LEVEL_COMPLETE, LEADERBOARD, NAME_INPUT}
var _current_dialog_type: DialogType = DialogType.WELCOME
var _dialog_callback: Callable = Callable()

# 当前难度：1=初级，2=中级，3=高级
var current_level: int = 1
var _level2_direction: Level2Dir = Level2Dir.LEFT
var _level4_direction: Level4Dir = Level4Dir.UP
var current_difficulty: int = 1

# 排行榜数据：键为难度 "1"/"2"/"3"，值为记录数组
var _leaderboard_data: Dictionary = {}
const LEADERBOARD_FILE := "user://leaderboard.json"

# 排行榜弹窗当前查看的难度与页码（0 起始）
var _leaderboard_difficulty: int = 1
var _leaderboard_page: int = 0
const LEADERBOARD_MAX_ENTRIES := 1000
const LEADERBOARD_ENTRIES_PER_PAGE := 10
const SETTINGS_FILE := "user://settings.json"

# 关卡完成弹窗待进入的下一关
var _pending_next_level: int = -1

# 分数与计时
var score: int = 0
var total_game_time: float = 0.0
var level_time: float = 0.0
var _last_eliminate_time: float = -1.0
# 音效与背景音乐开关
var sound_effects_enabled: bool = true
var background_music_enabled: bool = true
# 音量：0.0 ~ 1.0
var master_volume: float = 0.8
var sfx_volume: float = 0.8
var bgm_volume: float = 0.5

var _audio_player: AudioStreamPlayer
var _bgm_player: AudioStreamPlayer

# ------------------------------
# 模块：UI 节点引用
# 说明：按钮、标签、进度条、网格与提示线等场景节点
# ------------------------------
@onready var undo_button: Button = %UndoButton
@onready var redo_button: Button = %RedoButton
@onready var pause_button: Button = %PauseButton
@onready var restart_button: Button = %RestartButton
@onready var hint_button: Button = %HintButton
@onready var shuffle_button: Button = %ShuffleButton
@onready var time_label: RichTextLabel = %TimeLabel
@onready var score_label: RichTextLabel = %ScoreLabel
@onready var difficulty_label: RichTextLabel = %DifficultyLabel
@onready var level_label: RichTextLabel = %LevelLabel
@onready var remaining_pairs_label: RichTextLabel = %RemainingPairsLabel
@onready var timer_bar: ProgressBar = %TimerBar
@onready var compact_timer_bar: ProgressBar = %CompactTimerBar
@onready var compact_time_label: RichTextLabel = %CompactTimeLabel
@onready var compact_score_label: RichTextLabel = %CompactScoreLabel
@onready var menu_bar: PanelContainer = %MenuBar
@onready var info_bar: PanelContainer = %InfoBar
@onready var toolbar: HBoxContainer = %HBoxContainer
@onready var compact_top_bar: PanelContainer = %CompactTopBar
@onready var ui_hide_timer: Timer = %UIHideTimer
@onready var auto_hide_hint: RichTextLabel = %AutoHideHint
@onready var hint_hide_timer: Timer = %HintHideTimer
@onready var grid_container: GridContainer = %GridContainer
@onready var aspect_ratio_container: AspectRatioContainer = %AspectRatioContainer
@onready var board_center: CenterContainer = %BoardCenter
@onready var hint_line: Line2D = %HintLine
@onready var match_line: Line2D = %MatchLine
@onready var score_popups: Array[Label] = [%ScorePopup, %ScorePopup2, %ScorePopup3]
var _score_popup_index: int = 0
var _score_popup_tweens: Array[Tween] = []
@onready var score_gain_label: RichTextLabel = %ScoreGainLabel
@onready var combo_label: RichTextLabel = %ComboLabel
@onready var compact_combo_label: RichTextLabel = %CompactComboLabel
@onready var game_over_label: Label = %GameOverLabel
@onready var game_over_panel: PanelContainer = %GameOverPanel
@onready var pause_label: Label = %PauseLabel
@onready var pause_dim: ColorRect = %PauseDim
@onready var pause_menu_panel: PanelContainer = %PauseMenuPanel
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var master_slider: HSlider = %MasterSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var bgm_slider: HSlider = %BGMSlider
@onready var master_value_label: Label = %MasterValueLabel
@onready var sfx_value_label: Label = %SFXValueLabel
@onready var bgm_value_label: Label = %BGMValueLabel
@onready var sfx_mute_button: CheckButton = %SFXMuteButton
@onready var bgm_mute_button: CheckButton = %BGMMuteButton
@onready var cell_scene := preload("res://cell.tscn")

@onready var game_menu: MenuButton = %GameMenu
@onready var options_menu: MenuButton = %OptionsMenu
@onready var help_menu: MenuButton = %HelpMenu
@onready var skin_menu: MenuButton = %SkinMenu

@onready var custom_dialog: PanelContainer = %CustomDialog
@onready var dialog_title: Label = %DialogTitle
@onready var dialog_content: RichTextLabel = %DialogContent
@onready var dialog_hint: Label = %DialogHint
@onready var dialog_name_input: LineEdit = %DialogNameInput

@onready var leaderboard_panel: VBoxContainer = %LeaderboardPanel
@onready var leaderboard_content: RichTextLabel = %LeaderboardContent
@onready var leaderboard_page_label: Label = %LeaderboardPageLabel
@onready var leaderboard_close_button: Button = %LeaderboardCloseButton
@onready var leaderboard_tab_buttons: Array[Button] = [%LeaderboardTab1, %LeaderboardTab2, %LeaderboardTab3]
@onready var leaderboard_prev_button: Button = %PrevPageButton
@onready var leaderboard_next_button: Button = %NextPageButton


# 模块：生命周期 —— 初始化音频、棋盘、菜单与游戏
func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.stream = null
	add_child(_bgm_player)

	# 设置背景音乐单曲循环
	for track: AudioStream in BGM_TRACKS:
		track.loop = true

	randomize()
	Cell.set_level(current_difficulty)
	_setup_grid()
	_setup_menus()
	_load_leaderboard()
	restart_game()
	_show_welcome_dialog()

	hint_button.pressed.connect(_on_hint_button_pressed)
	dialog_name_input.text_submitted.connect(_on_name_input_submitted)
	shuffle_button.pressed.connect(_on_shuffle_button_pressed)
	pause_button.pressed.connect(_toggle_pause)
	ui_hide_timer.timeout.connect(_on_ui_hide_timer_timeout)
	hint_hide_timer.timeout.connect(_on_hint_hide_timer_timeout)

	# 排行榜弹窗按钮
	leaderboard_tab_buttons[0].pressed.connect(_on_leaderboard_tab_pressed.bind(1))
	leaderboard_tab_buttons[1].pressed.connect(_on_leaderboard_tab_pressed.bind(2))
	leaderboard_tab_buttons[2].pressed.connect(_on_leaderboard_tab_pressed.bind(3))
	leaderboard_prev_button.pressed.connect(_on_leaderboard_prev_page_pressed)
	leaderboard_next_button.pressed.connect(_on_leaderboard_next_page_pressed)
	leaderboard_close_button.pressed.connect(_hide_custom_dialog)

	# 暂停菜单按钮
	%ResumeButton.pressed.connect(_on_resume_button_pressed)
	%RestartButton2.pressed.connect(_on_restart_button_pressed)
	%SettingsButton.pressed.connect(_on_settings_button_pressed)
	%CloseSettingsButton.pressed.connect(_on_close_settings_button_pressed)

	# 设置面板控件
	master_slider.value_changed.connect(_on_master_volume_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_slider_changed)
	bgm_slider.value_changed.connect(_on_bgm_volume_slider_changed)
	sfx_mute_button.toggled.connect(_on_sfx_mute_toggled)
	bgm_mute_button.toggled.connect(_on_bgm_mute_toggled)

	# 禁止按钮通过空格/回车获得焦点，避免空格误触提示等功能
	undo_button.focus_mode = Control.FOCUS_NONE
	redo_button.focus_mode = Control.FOCUS_NONE
	pause_button.focus_mode = Control.FOCUS_NONE
	restart_button.focus_mode = Control.FOCUS_NONE
	hint_button.focus_mode = Control.FOCUS_NONE
	shuffle_button.focus_mode = Control.FOCUS_NONE
	game_menu.focus_mode = Control.FOCUS_NONE
	options_menu.focus_mode = Control.FOCUS_NONE
	help_menu.focus_mode = Control.FOCUS_NONE
	skin_menu.focus_mode = Control.FOCUS_NONE
	%ResumeButton.focus_mode = Control.FOCUS_NONE
	%RestartButton2.focus_mode = Control.FOCUS_NONE
	%SettingsButton.focus_mode = Control.FOCUS_NONE
	%CloseSettingsButton.focus_mode = Control.FOCUS_NONE
	%LeaderboardTab1.focus_mode = Control.FOCUS_NONE
	%LeaderboardTab2.focus_mode = Control.FOCUS_NONE
	%LeaderboardTab3.focus_mode = Control.FOCUS_NONE
	%PrevPageButton.focus_mode = Control.FOCUS_NONE
	%NextPageButton.focus_mode = Control.FOCUS_NONE
	%LeaderboardCloseButton.focus_mode = Control.FOCUS_NONE

	# 加载持久化设置
	_load_settings()

	# 设置分数标签的缩放中心，便于加分动画
	score_label.resized.connect(_on_score_label_resized)
	_on_score_label_resized()

	# 初始化飘字动画 Tween 池
	_score_popup_tweens.resize(score_popups.size())
	for i in range(_score_popup_tweens.size()):
		_score_popup_tweens[i] = null


# 最终关卡胜利
func _update_level_info() -> void:
	var difficulty_name := "初级"
	match current_difficulty:
		2: difficulty_name = "中级"
		3: difficulty_name = "高级"
	var level_total := 5 if current_difficulty == 1 else 10
	difficulty_label.text = "[color=#8C5C33]难度：[/color][color=#264D61]%s[/color]" % difficulty_name
	level_label.text = "[color=#8C5C33]关卡 %d/%d：[/color][color=#264D61]%s[/color]" % [current_level, level_total, _get_level_name(current_level)]
	_update_pairs_label()


# 刷新剩余对数显示
func _update_pairs_label() -> void:
	remaining_pairs_label.text = "[color=#8C5C33]剩余：[/color][color=#264D61]%d[/color]" % pairs_left



# 获取关卡名称
func _get_level_name(level: int) -> String:
	match level:
		2:
			return "向左" if _level2_direction == Level2Dir.LEFT else "向右"
		3:
			return "向外扩"
		4:
			return "向上" if _level4_direction == Level4Dir.UP else "向下"
		5:
			return "向内坍塌"
		6:
			return "向左右扩"
		7:
			return "向上下扩"
		8:
			return "向竖中线汇聚"
		9:
			return "向横中线汇聚"
		10:
			return "左扩右聚"
	return LEVEL_NAMES.get(level, "未知")


# 获取当前难度下的最大关卡数
func _get_max_level() -> int:
	return _get_max_level_for_difficulty(current_difficulty)


# 判断当前关卡是否为该难度下的最终关卡
func _is_final_level() -> bool:
	return current_level >= _get_max_level()


# 随机决定第二关方向
func _roll_level2_direction() -> void:
	_level2_direction = Level2Dir.LEFT if randi() % 2 == 0 else Level2Dir.RIGHT


# 随机决定第四关方向
func _roll_level4_direction() -> void:
	_level4_direction = Level4Dir.UP if randi() % 2 == 0 else Level4Dir.DOWN


# 通关后进入下一关
func _advance_level() -> void:
	var max_level := _get_max_level()
	current_level += 1
	if current_level > max_level:
		current_level = 1
	if current_level == 2:
		_roll_level2_direction()
	if current_level == 4:
		_roll_level4_direction()
	_update_level_info()


# 关卡完成后的统一处理
func _on_level_complete() -> void:
	# 播放胜利音效
	_play_sound(GAME_WON_SOUND)
	_show_full_ui()
	if _is_final_level():
		# 最终关卡胜利时播放烟花庆祝
		var fireworks := FIREWORKS_SCENE.instantiate()
		add_child(fireworks)
		_show_final_victory()
	else:
		_show_level_complete_dialog()


func _show_final_victory() -> void:
	game_state = GameState.GAME_OVER
	_timer_running = false
	# 用背景音乐播放器播放通关庆祝音乐，避免覆盖胜利音效
	_bgm_player.stop()
	_bgm_player.stream = LEVEL_COMPLETE_MUSIC
	_bgm_player.volume_db = linear_to_db(master_volume * bgm_volume)
	_bgm_player.play()
	_show_name_input_dialog()


# 显示通关后的姓名输入弹窗
func _show_name_input_dialog() -> void:
	_show_custom_dialog(DialogType.NAME_INPUT, "恭喜通关！", "请输入您的姓名：", "输入后按回车，直接回车则为「神秘大侠」")
	dialog_name_input.text = ""
	dialog_name_input.show()
	dialog_name_input.grab_focus()


# 提交姓名并保存排行榜，然后显示最终胜利界面
func _on_name_input_submitted(text: String) -> void:
	var player_name := text.strip_edges()
	if player_name.is_empty():
		player_name = "神秘大侠"
	_add_leaderboard_entry(player_name)
	_save_leaderboard()
	dialog_name_input.hide()
	dialog_name_input.release_focus()
	_hide_custom_dialog()
	_display_final_victory_label()


# 显示最终胜利标签
func _display_final_victory_label() -> void:
	if current_difficulty == 1:
		game_over_label.text = "初级通关！\n总分：%d\n总用时：%s" % [score, _format_time(total_game_time)]
	elif current_difficulty == 2:
		game_over_label.text = "中级通关！\n总分：%d\n总用时：%s" % [score, _format_time(total_game_time)]
	else:
		game_over_label.text = "高级通关！\n总分：%d\n总用时：%s" % [score, _format_time(total_game_time)]
	game_over_panel.show()


# 模块：排行榜 —— 加载本地排行榜数据
func _load_leaderboard() -> void:
	if not FileAccess.file_exists(LEADERBOARD_FILE):
		_leaderboard_data = {"1": [], "2": [], "3": []}
		return
	var file := FileAccess.open(LEADERBOARD_FILE, FileAccess.READ)
	if file == null:
		_leaderboard_data = {"1": [], "2": [], "3": []}
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		_leaderboard_data = {"1": [], "2": [], "3": []}
		return
	var data = json.data
	if data is Dictionary:
		_leaderboard_data = data
	else:
		_leaderboard_data = {"1": [], "2": [], "3": []}


# 模块：排行榜 —— 保存排行榜数据到本地
func _save_leaderboard() -> void:
	var file := FileAccess.open(LEADERBOARD_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_leaderboard_data, "\t"))
	file.close()


# 模块：排行榜 —— 添加一条新记录并排序截断
func _add_leaderboard_entry(player_name: String) -> void:
	var key := str(current_difficulty)
	if not _leaderboard_data.has(key) or not (_leaderboard_data[key] is Array):
		_leaderboard_data[key] = []
	var entries: Array = _leaderboard_data[key]
	var date_dict := Time.get_datetime_dict_from_system()
	var date_str := "%04d-%02d-%02d %02d:%02d" % [date_dict.year, date_dict.month, date_dict.day, date_dict.hour, date_dict.minute]
	entries.append({
		"name": player_name,
		"date": date_str,
		"time": _format_time(total_game_time),
		"time_seconds": int(total_game_time),
		"score": score
	})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		if a["time_seconds"] != b["time_seconds"]:
			return a["time_seconds"] < b["time_seconds"]
		return a["date"] > b["date"]
	)
	if entries.size() > LEADERBOARD_MAX_ENTRIES:
		entries.resize(LEADERBOARD_MAX_ENTRIES)


# 模块：排行榜 —— 格式化指定难度与页码的排行榜字符串
func _get_leaderboard_page_text(difficulty: int, page: int) -> String:
	var key := str(difficulty)
	var raw_entries = _leaderboard_data.get(key, [])
	var entries: Array = raw_entries if raw_entries is Array else []
	var diff_name := "初级" if difficulty == 1 else ("中级" if difficulty == 2 else "高级")
	var content := "[center][color=#E0B45A][b]%s排行榜（%d 关）[/b][/color][/center]\n\n" % [diff_name, _get_max_level_for_difficulty(difficulty)]
	if entries.is_empty():
		content += "[center]暂无记录[/center]"
		return content

	var total_pages := maxi(1, ceili(float(entries.size()) / LEADERBOARD_ENTRIES_PER_PAGE))
	var current_page := clampi(page, 0, total_pages - 1)
	var start_index := current_page * LEADERBOARD_ENTRIES_PER_PAGE
	var end_index := mini(start_index + LEADERBOARD_ENTRIES_PER_PAGE, entries.size())

	# 使用 RichTextLabel [table] 让各列自动与表头严格对齐
	const HEADER_COLOR := "#E0B45A"
	var table := "[center][table=5]"
	table += "[cell][color=%s][b]排名[/b][/color][/cell]" % HEADER_COLOR
	table += "[cell][color=%s][b]姓名[/b][/color][/cell]" % HEADER_COLOR
	table += "[cell][color=%s][b]日期[/b][/color][/cell]" % HEADER_COLOR
	table += "[cell][color=%s][b]用时[/b][/color][/cell]" % HEADER_COLOR
	table += "[cell][color=%s][b]分数[/b][/color][/cell]" % HEADER_COLOR
	for i in range(start_index, end_index):
		var entry: Dictionary = entries[i]
		table += "[cell]%d[/cell][cell]%s[/cell][cell]%s[/cell][cell]%s[/cell][cell]%d[/cell]" % [i + 1, entry["name"], entry["date"], entry["time"], entry["score"]]
	table += "[/table][/center]\n"
	content += table
	return content


# 模块：排行榜 —— 显示带标签页与分页的排行榜弹窗
func _show_leaderboard_dialog() -> void:
	_leaderboard_difficulty = 1
	_leaderboard_page = 0
	_update_leaderboard_view()
	_show_custom_dialog(DialogType.LEADERBOARD, "排行榜", "")


# 模块：排行榜 —— 刷新当前难度/页码的视图与按钮状态
func _update_leaderboard_view() -> void:
	var key := str(_leaderboard_difficulty)
	var raw_entries = _leaderboard_data.get(key, [])
	var entries: Array = raw_entries if raw_entries is Array else []
	var total_pages := maxi(1, ceili(float(entries.size()) / LEADERBOARD_ENTRIES_PER_PAGE))
	_leaderboard_page = clampi(_leaderboard_page, 0, total_pages - 1)

	leaderboard_content.text = _get_leaderboard_page_text(_leaderboard_difficulty, _leaderboard_page)
	leaderboard_page_label.text = "第 %d 页 / 共 %d 页" % [_leaderboard_page + 1, total_pages]

	for i in range(leaderboard_tab_buttons.size()):
		leaderboard_tab_buttons[i].disabled = (i + 1 == _leaderboard_difficulty)

	leaderboard_prev_button.disabled = (_leaderboard_page == 0)
	leaderboard_next_button.disabled = (_leaderboard_page >= total_pages - 1)


# 模块：排行榜 —— 切换难度标签
func _on_leaderboard_tab_pressed(difficulty: int) -> void:
	if _leaderboard_difficulty == difficulty:
		return
	_leaderboard_difficulty = difficulty
	_leaderboard_page = 0
	_update_leaderboard_view()


# 模块：排行榜 —— 上一页
func _on_leaderboard_prev_page_pressed() -> void:
	if _leaderboard_page > 0:
		_leaderboard_page -= 1
		_update_leaderboard_view()


# 模块：排行榜 —— 下一页
func _on_leaderboard_next_page_pressed() -> void:
	var key := str(_leaderboard_difficulty)
	var raw_entries = _leaderboard_data.get(key, [])
	var entries: Array = raw_entries if raw_entries is Array else []
	var total_pages := maxi(1, ceili(float(entries.size()) / LEADERBOARD_ENTRIES_PER_PAGE))
	if _leaderboard_page < total_pages - 1:
		_leaderboard_page += 1
		_update_leaderboard_view()


# 获取指定难度下的最大关卡数
func _get_max_level_for_difficulty(difficulty: int) -> int:
	return 5 if difficulty == 1 else 10


# 显示欢迎弹窗
func _show_welcome_dialog() -> void:
	var content := "[center]"
	content += "[color=#E0B45A][b]【游戏规则】[/b][/color]\n"
	content += "点击两个 [color=#E08787]相同图案[/color] 的格子，\n"
	content += "若能用不超过 [color=#66ff66][b]2 个转弯[/b][/color] 的直线连接，则消除。\n"
	content += "消除所有图案即可获胜。\n\n"
	content += "[color=#E0B45A][b]【操作说明】[/b][/color]\n"
	content += "[color=#5AB4E0][b]T / 鼠标右键[/b][/color]：提示\n"
	content += "[color=#5AB4E0][b]X / 左右键同时按[/b][/color]：洗牌\n"
	content += "[color=#5AB4E0][b]空格键 / 鼠标左键快速双击[/b][/color]：暂停 / 继续\n"
	content += "[color=#5AB4E0][b]鼠标左键[/b][/color]：选择 / 消除"
	content += "[/center]"
	_show_custom_dialog(DialogType.WELCOME, "欢迎游玩连连看", content, "点击任意位置或按任意键开始")
	_flash_dialog_hint()


# 普通关卡完成弹窗
func _show_level_complete_dialog() -> void:
	game_state = GameState.GAME_OVER
	_timer_running = false

	_pending_next_level = current_level + 1
	if _pending_next_level > _get_max_level():
		_pending_next_level = 1
	if _pending_next_level == 2:
		_roll_level2_direction()
	if _pending_next_level == 4:
		_roll_level4_direction()

	var next_name := _get_level_name(_pending_next_level)
	var content := "恭喜完成第 %d 关，下一关为 [color=#006400]%s[/color]\n" % [current_level, next_name]
	_show_custom_dialog(DialogType.LEVEL_COMPLETE, "关卡完成", content)


# 点击关卡完成弹窗的确定后进入下一关
func _on_level_complete_confirmed() -> void:
	if _pending_next_level < 0:
		return
	current_level = _pending_next_level
	_pending_next_level = -1
	_update_level_info()
	restart_game(false)


# 播放音效（受音效开关、主音量与音效音量控制）
func _play_sound(stream: AudioStream) -> void:
	if not sound_effects_enabled:
		return
	_audio_player.volume_db = linear_to_db(master_volume * sfx_volume)
	_audio_player.stream = stream
	_audio_player.play()


# 刷新背景音乐播放状态
func _update_background_music() -> void:
	if _bgm_player.stream == null:
		return
	_bgm_player.volume_db = linear_to_db(master_volume * bgm_volume)
	if background_music_enabled:
		if not _bgm_player.playing:
			_bgm_player.play()
	else:
		_bgm_player.stop()


# 随机挑选一首背景音乐并开始播放
func _play_random_bgm() -> void:
	var track: AudioStream = BGM_TRACKS[randi() % BGM_TRACKS.size()]
	_bgm_player.stop()
	_bgm_player.stream = track
	_update_background_music()


# 模块：设置 —— 从文件加载音量与开关状态
func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE):
		_apply_settings_to_ui()
		return
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if file == null:
		_apply_settings_to_ui()
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		_apply_settings_to_ui()
		return
	var data = json.data
	if data is Dictionary:
		master_volume = clampf(data.get("master_volume", master_volume), 0.0, 1.0)
		sfx_volume = clampf(data.get("sfx_volume", sfx_volume), 0.0, 1.0)
		bgm_volume = clampf(data.get("bgm_volume", bgm_volume), 0.0, 1.0)
		sound_effects_enabled = data.get("sound_effects_enabled", sound_effects_enabled)
		background_music_enabled = data.get("background_music_enabled", background_music_enabled)
	_apply_settings_to_ui()
	_update_background_music()


# 模块：设置 —— 保存音量与开关状态到文件
func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file == null:
		return
	var data := {
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"bgm_volume": bgm_volume,
		"sound_effects_enabled": sound_effects_enabled,
		"background_music_enabled": background_music_enabled,
	}
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


# 模块：设置 —— 将当前设置同步到设置面板 UI
func _apply_settings_to_ui() -> void:
	master_slider.set_block_signals(true)
	sfx_slider.set_block_signals(true)
	bgm_slider.set_block_signals(true)
	sfx_mute_button.set_block_signals(true)
	bgm_mute_button.set_block_signals(true)

	master_slider.value = master_volume
	sfx_slider.value = sfx_volume
	bgm_slider.value = bgm_volume
	master_value_label.text = "%d%%" % int(master_volume * 100)
	sfx_value_label.text = "%d%%" % int(sfx_volume * 100)
	bgm_value_label.text = "%d%%" % int(bgm_volume * 100)
	sfx_mute_button.button_pressed = sound_effects_enabled
	bgm_mute_button.button_pressed = background_music_enabled

	master_slider.set_block_signals(false)
	sfx_slider.set_block_signals(false)
	bgm_slider.set_block_signals(false)
	sfx_mute_button.set_block_signals(false)
	bgm_mute_button.set_block_signals(false)

	# 同步 OptionsMenu 的勾选状态
	var options_popup := options_menu.get_popup()
	options_popup.set_item_checked(0, sound_effects_enabled)
	options_popup.set_item_checked(1, background_music_enabled)


# 模块：设置 —— 主音量滑块变化
func _on_master_volume_slider_changed(value: float) -> void:
	master_volume = value
	master_value_label.text = "%d%%" % int(value * 100)
	_update_background_music()
	_save_settings()


# 模块：设置 —— 音效音量滑块变化
func _on_sfx_volume_slider_changed(value: float) -> void:
	sfx_volume = value
	sfx_value_label.text = "%d%%" % int(value * 100)
	_save_settings()


# 模块：设置 —— 背景音乐音量滑块变化
func _on_bgm_volume_slider_changed(value: float) -> void:
	bgm_volume = value
	bgm_value_label.text = "%d%%" % int(value * 100)
	_update_background_music()
	_save_settings()


# 模块：设置 —— 音效开关变化
func _on_sfx_mute_toggled(pressed: bool) -> void:
	sound_effects_enabled = pressed
	_save_settings()


# 模块：设置 —— 背景音乐开关变化
func _on_bgm_mute_toggled(pressed: bool) -> void:
	background_music_enabled = pressed
	_update_background_music()
	_save_settings()


# 模块：设置 —— 打开设置面板
func _open_settings_panel() -> void:
	settings_panel.show()


# 模块：设置 —— 关闭设置面板
func _close_settings_panel() -> void:
	settings_panel.hide()


# 暂停菜单：继续游戏
func _on_resume_button_pressed() -> void:
	_set_paused(false)


# 暂停菜单：打开设置
func _on_settings_button_pressed() -> void:
	_open_settings_panel()


# 设置面板：关闭按钮
func _on_close_settings_button_pressed() -> void:
	_close_settings_panel()


# 模块：网格与显示 —— 生成棋盘格子并绑定点击事件
func _setup_grid() -> void:
	var rows := _get_rows()
	var cols := _get_cols()
	grid_container.columns = cols
	aspect_ratio_container.ratio = float(cols) / float(rows)

	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()

	for i in range(rows * cols):
		var cell: Cell = cell_scene.instantiate()
		grid_container.add_child(cell)
		cell.cell_clicked.connect(_on_cell_clicked)

	board_center.resized.connect(_on_grid_resized)
	_on_grid_resized()


# 模块：菜单栏 —— 配置游戏、选项、帮助三个下拉菜单
func _setup_menus() -> void:
	var game_popup := game_menu.get_popup()
	game_popup.add_item("初级", 0)
	game_popup.add_item("中级", 1)
	game_popup.add_item("高级", 2)

	var level_popup := PopupMenu.new()
	level_popup.name = "LevelMenu"
	for i in range(1, 11):
		level_popup.add_item("第 %d 关 %s" % [i, LEVEL_NAMES.get(i, "")], i - 1)
	level_popup.index_pressed.connect(_on_level_menu_item_pressed)
	game_popup.add_child(level_popup)
	game_popup.add_submenu_item("选择关卡", "LevelMenu", 3)

	game_popup.index_pressed.connect(_on_game_menu_item_pressed)

	var options_popup := options_menu.get_popup()

	var master_volume_popup := PopupMenu.new()
	master_volume_popup.name = "MasterVolumeMenu"
	master_volume_popup.add_item("静音", 0)
	master_volume_popup.add_item("25%", 1)
	master_volume_popup.add_item("50%", 2)
	master_volume_popup.add_item("75%", 3)
	master_volume_popup.add_item("100%", 4)
	master_volume_popup.index_pressed.connect(_on_master_volume_menu_item_pressed)
	options_popup.add_child(master_volume_popup)

	var sfx_volume_popup := PopupMenu.new()
	sfx_volume_popup.name = "SFXVolumeMenu"
	sfx_volume_popup.add_item("静音", 0)
	sfx_volume_popup.add_item("25%", 1)
	sfx_volume_popup.add_item("50%", 2)
	sfx_volume_popup.add_item("75%", 3)
	sfx_volume_popup.add_item("100%", 4)
	sfx_volume_popup.index_pressed.connect(_on_sfx_volume_menu_item_pressed)
	options_popup.add_child(sfx_volume_popup)

	var bgm_volume_popup := PopupMenu.new()
	bgm_volume_popup.name = "BGMVolumeMenu"
	bgm_volume_popup.add_item("静音", 0)
	bgm_volume_popup.add_item("25%", 1)
	bgm_volume_popup.add_item("50%", 2)
	bgm_volume_popup.add_item("75%", 3)
	bgm_volume_popup.add_item("100%", 4)
	bgm_volume_popup.index_pressed.connect(_on_bgm_volume_menu_item_pressed)
	options_popup.add_child(bgm_volume_popup)

	options_popup.add_check_item("音效", 0)
	options_popup.set_item_checked(0, sound_effects_enabled)
	options_popup.add_check_item("背景音乐", 1)
	options_popup.set_item_checked(1, background_music_enabled)
	options_popup.add_submenu_item("主音量", "MasterVolumeMenu", 2)
	options_popup.add_submenu_item("音效音量", "SFXVolumeMenu", 3)
	options_popup.add_submenu_item("背景音乐音量", "BGMVolumeMenu", 4)
	options_popup.add_item("排行榜", 5)
	options_popup.index_pressed.connect(_on_options_menu_item_pressed)

	var help_popup := help_menu.get_popup()
	help_popup.add_item("连连看规则", 0)
	help_popup.add_item("快捷键说明", 2)
	help_popup.add_item("积分规则", 3)
	help_popup.add_item("关于", 1)
	help_popup.index_pressed.connect(_on_help_menu_item_pressed)

	var skin_popup := skin_menu.get_popup()
	skin_popup.add_check_item("新版宝可梦", 0)
	skin_popup.add_check_item("经典图案", 1)
	skin_popup.index_pressed.connect(_on_skin_menu_item_pressed)
	_update_skin_menu_check()


# 处理游戏菜单：切换难度并重新开始
func _on_game_menu_item_pressed(index: int) -> void:
	current_difficulty = index + 1
	Cell.set_level(current_difficulty)
	Cell.clear_texture_cache()
	_setup_grid()
	restart_game()


# 处理关卡选择子菜单
func _on_level_menu_item_pressed(index: int) -> void:
	current_level = index + 1
	# 若选择超出初级上限，自动提升到中级以便测试
	if current_level > 5 and current_difficulty == 1:
		current_difficulty = 2
	# 难度变化时重新设置棋盘网格
	Cell.set_level(current_difficulty)
	Cell.clear_texture_cache()
	_setup_grid()
	# 跳转到指定关卡，重置本局分数与时间，但保留选中的关卡编号
	score = 0
	total_game_time = 0.0
	level_time = 0.0
	_last_eliminate_time = -1.0
	restart_game(false)


# 处理选项菜单：音效、背景音乐、排行榜
func _on_options_menu_item_pressed(index: int) -> void:
	var popup := options_menu.get_popup()
	match index:
		0:
			sound_effects_enabled = not sound_effects_enabled
			popup.set_item_checked(0, sound_effects_enabled)
			_apply_settings_to_ui()
			_save_settings()
		1:
			background_music_enabled = not background_music_enabled
			popup.set_item_checked(1, background_music_enabled)
			_update_background_music()
			_apply_settings_to_ui()
			_save_settings()
		5:
			_show_leaderboard_dialog()


# 处理主音量子菜单
func _on_master_volume_menu_item_pressed(index: int) -> void:
	match index:
		0: master_volume = 0.0
		1: master_volume = 0.25
		2: master_volume = 0.5
		3: master_volume = 0.75
		4: master_volume = 1.0
	_update_background_music()
	_apply_settings_to_ui()
	_save_settings()


# 处理音效音量子菜单
func _on_sfx_volume_menu_item_pressed(index: int) -> void:
	match index:
		0: sfx_volume = 0.0
		1: sfx_volume = 0.25
		2: sfx_volume = 0.5
		3: sfx_volume = 0.75
		4: sfx_volume = 1.0
	_apply_settings_to_ui()
	_save_settings()


# 处理背景音乐音量子菜单
func _on_bgm_volume_menu_item_pressed(index: int) -> void:
	match index:
		0: bgm_volume = 0.0
		1: bgm_volume = 0.25
		2: bgm_volume = 0.5
		3: bgm_volume = 0.75
		4: bgm_volume = 1.0
	_update_background_music()
	_apply_settings_to_ui()
	_save_settings()


# 处理帮助菜单：打开连连看规则、快捷键说明、积分规则或关于弹窗
# 注意：菜单项按当前显示顺序（连连看规则、快捷键说明、积分规则、关于）处理
func _on_help_menu_item_pressed(index: int) -> void:
	match index:
		0:
			var rules := "点击两个相同图案的格子。\n若能用不超过 2 个转弯的直线连接，则消除。\n消除所有图案即可获胜。\n\n提示：路径可以经过棋盘外圈的虚拟空白区域。"
			_show_custom_dialog(DialogType.RULES, "连连看规则", rules)
		1:
			var shortcuts := "T / 鼠标右键：提示（高亮显示一对可连通的图案）\nX / 鼠标左右键同时按下：洗牌（重新排列剩余图案）\n空格键 / 鼠标左键快速双击：暂停 / 继续游戏\n鼠标左键：点击选择或消除图案"
			_show_custom_dialog(DialogType.SHORTCUTS, "快捷键说明", shortcuts)
		2:
			var score_rules := "从上一次消除完成到下一次消除完成的时间间隔决定得分：\n3 秒内消除：30 分\n5 秒内消除：20 分\n10 秒内消除：15 分\n20 秒内消除：12 分\n超过 20 秒：10 分"
			_show_custom_dialog(DialogType.SCORE_RULES, "积分规则", score_rules)
		3:
			_show_custom_dialog(DialogType.ABOUT, "关于", "连连看 v1.0\n使用 Godot 4.5 制作")


# 处理图版菜单：切换图案版本并重新开始本局
func _on_skin_menu_item_pressed(index: int) -> void:
	var new_skin := Cell.TileSkin.POKEMON if index == 0 else Cell.TileSkin.CLASSIC
	if Cell.current_skin == new_skin:
		return

	Cell.set_skin(new_skin)
	Cell.set_level(current_difficulty)
	Cell.clear_texture_cache()
	_update_skin_menu_check()
	_setup_grid()
	restart_game(false)


# 更新图版菜单的勾选状态
func _update_skin_menu_check() -> void:
	var popup := skin_menu.get_popup()
	for i in range(popup.item_count):
		popup.set_item_checked(i, false)
	match Cell.current_skin:
		Cell.TileSkin.POKEMON:
			popup.set_item_checked(0, true)
		Cell.TileSkin.CLASSIC:
			popup.set_item_checked(1, true)
		#Cell.TileSkin.LifeItems:
			#popup.set_item_checked(2,true)


# 模块：网格与显示 —— 根据可用空间计算 80% 大小的棋盘，并让格子自适应
func _on_grid_resized() -> void:
	var available_size := board_center.size
	if available_size.x <= 0 or available_size.y <= 0:
		return

	var rows := _get_rows()
	var cols := _get_cols()
	var h_sep: int = grid_container.get_theme_constant("h_separation")
	var v_sep: int = grid_container.get_theme_constant("v_separation")

	# 目标棋盘区域为父容器可用空间的 80%
	var target_size := available_size * BOARD_SCALE

	var cell_w: float = (target_size.x - (cols - 1) * h_sep) / cols
	var cell_h: float = (target_size.y - (rows - 1) * v_sep) / rows
	var cell_size: float = min(cell_w, cell_h)

	for child in grid_container.get_children():
		child.custom_minimum_size = Vector2(cell_size, cell_size)

	# 同步设置棋盘容器尺寸，使其在 CenterContainer 中居中显示
	aspect_ratio_container.custom_minimum_size = Vector2(
		cols * cell_size + (cols - 1) * h_sep,
		rows * cell_size + (rows - 1) * v_sep
	)


# 显示自定义弹窗（居中的欢迎面板样式）
func _show_custom_dialog(type: DialogType, title: String, content: String, hint: String = "点击任意位置或按任意键继续", callback: Callable = Callable()) -> void:
	_current_dialog_type = type
	_dialog_callback = callback
	dialog_title.text = title

	if type == DialogType.LEADERBOARD:
		dialog_content.hide()
		dialog_hint.hide()
		leaderboard_panel.show()
	else:
		dialog_content.show()
		dialog_content.text = content
		dialog_hint.show()
		dialog_hint.text = hint
		dialog_hint.modulate = Color.WHITE
		leaderboard_panel.hide()

	custom_dialog.show()
	_set_paused(true, false)


# 让「按任意键继续」文字快速闪烁两下
func _flash_dialog_hint() -> void:
	var tween := create_tween()
	tween.set_loops(2)
	tween.tween_property(dialog_hint, "modulate:a", 0.15, 0.12)
	tween.tween_property(dialog_hint, "modulate:a", 1.0, 0.12)


# 关闭自定义弹窗
func _hide_custom_dialog() -> void:
	custom_dialog.hide()
	leaderboard_panel.hide()
	_set_paused(false)
	match _current_dialog_type:
		DialogType.LEVEL_COMPLETE:
			_on_level_complete_confirmed()
	_dialog_callback = Callable()


# 键盘与鼠标快捷键处理
func _input(event: InputEvent) -> void:
	# 设置面板打开时，按 Esc 关闭设置面板
	if settings_panel.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_settings_panel()
		get_viewport().set_input_as_handled()
		return

	# 自定义弹窗打开时，按任意键或点击鼠标关闭
	if custom_dialog.visible:
		# 姓名输入弹窗由 LineEdit 的 text_submitted 信号处理回车提交
		if _current_dialog_type == DialogType.NAME_INPUT:
			return
		# 排行榜弹窗由按钮自行处理，不响应全局关闭
		if _current_dialog_type == DialogType.LEADERBOARD:
			return
		if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
			_hide_custom_dialog()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# 设置面板打开时不响应游戏快捷键（让 UI 控件自己处理输入）
		if settings_panel.visible:
			return
		match event.keycode:
			KEY_T:
				_on_hint_button_pressed()
			KEY_X:
				_on_shuffle_button_pressed()
			KEY_SPACE, KEY_ESCAPE:
				_toggle_pause()
		return

	if event is InputEventMouseButton:
		# 鼠标左键快速双击：暂停 / 继续
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return

		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_left_mouse_pressed = event.pressed
				if event.pressed:
					_left_press_time = Time.get_ticks_msec()
					if _right_mouse_pressed and (Time.get_ticks_msec() - _right_press_time <= MOUSE_COMBO_WINDOW_MS):
						_on_shuffle_button_pressed()
						get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT:
				_right_mouse_pressed = event.pressed
				if event.pressed:
					_right_press_time = Time.get_ticks_msec()
					if _left_mouse_pressed and (Time.get_ticks_msec() - _left_press_time <= MOUSE_COMBO_WINDOW_MS):
						_on_shuffle_button_pressed()
					else:
						_on_hint_button_pressed()
					get_viewport().set_input_as_handled()


# 切换暂停状态
func _toggle_pause() -> void:
	if game_state == GameState.GAME_OVER:
		return
	_set_paused(not _is_paused)


# 设置暂停状态并更新 UI
func _set_paused(paused: bool, show_pause_label: bool = true) -> void:
	_is_paused = paused
	_timer_running = not paused
	ui_hide_timer.paused = paused
	pause_label.visible = false
	pause_dim.visible = paused and show_pause_label
	pause_menu_panel.visible = paused and show_pause_label
	pause_button.text = "继续" if paused else "暂停"
	# 恢复游戏时自动关闭设置面板
	if not paused:
		_close_settings_panel()

	undo_button.disabled = paused or move_history.is_empty()
	redo_button.disabled = paused or undo_history.is_empty()
	hint_button.disabled = paused
	shuffle_button.disabled = paused
	_update_timer_bar()


# 模块：游戏流程 —— 倒计时、胜负判定
func _process(delta: float) -> void:
	if _is_paused or not _timer_running or game_state != GameState.PLAYING:
		return

	remaining_time -= delta
	total_game_time += delta
	level_time += delta
	if remaining_time <= 0.0:
		remaining_time = 0.0
		_timer_running = false
		_on_time_up()

	# 超过 10 秒未消除，连击清零
	if _last_eliminate_time >= 0 and (total_game_time - _last_eliminate_time) > COMBO_FAST_THRESHOLD:
		if _combo_count != 0:
			_combo_count = 0
			_update_combo_display()

	_update_timer_bar()
	_update_time_labels()
	_update_ui_visibility(delta)


# 时间耗尽：显示结束语并播放失败音效
func _on_time_up() -> void:
	game_state = GameState.GAME_OVER
	game_over_label.text = "时间结束~欢迎游玩，下次再接再厉！"
	game_over_panel.show()
	_play_sound(GAME_OVER_SOUND)
	_show_full_ui()


# 顶部 UI 自动隐藏/显示：游戏开始 5 秒后进入紧凑模式，鼠标移到屏幕顶部恢复完整 UI
func _update_ui_visibility(delta: float) -> void:
	if game_state != GameState.PLAYING or _is_paused:
		return

	var mouse_y := get_global_mouse_position().y
	if mouse_y <= TOP_TRIGGER_HEIGHT:
		_top_leave_time = 0.0
		if _ui_hidden:
			_show_full_ui()
		return

	if not _ui_hidden:
		if ui_hide_timer.is_stopped():
			_top_leave_time += delta
			if _top_leave_time >= TOP_HIDE_DELAY:
				_show_compact_ui()


# 切换到紧凑顶部 UI（只显示倒计时条、本关用时、分数）
func _show_compact_ui() -> void:
	_ui_hidden = true
	_top_leave_time = 0.0
	menu_bar.hide()
	info_bar.hide()
	toolbar.hide()
	compact_top_bar.show()
	_update_compact_ui()
	# 每局首次进入紧凑模式时显示闪烁 3 次后再停留 5 秒的恢复提示
	if _auto_hide_hint_count < AUTO_HIDE_HINT_MAX:
		_auto_hide_hint_count += 1
		auto_hide_hint.show()
		auto_hide_hint.modulate = Color.WHITE
		auto_hide_hint.scale = Vector2(1.0, 1.0)
		hint_hide_timer.stop()
		if _hint_flash_tween != null:
			_hint_flash_tween.kill()
		_hint_flash_tween = create_tween()
		_hint_flash_tween.set_loops(3)
		# 每次闪烁：仅通过缩放脉冲提醒，不改变透明度，避免文字变暗变糊
		_hint_flash_tween.tween_property(auto_hide_hint, "scale", Vector2(1.08, 1.08), 0.75)
		_hint_flash_tween.chain().tween_property(auto_hide_hint, "scale", Vector2(1.0, 1.0), 0.75)
		_hint_flash_tween.finished.connect(func() -> void:
			hint_hide_timer.start(5.0)
			_hint_flash_tween = null
		)


# 恢复完整顶部 UI（菜单栏、信息栏、工具栏）
func _show_full_ui() -> void:
	_ui_hidden = false
	_top_leave_time = 0.0
	menu_bar.show()
	info_bar.show()
	toolbar.show()
	compact_top_bar.hide()
	auto_hide_hint.hide()
	auto_hide_hint.modulate = Color.WHITE
	auto_hide_hint.scale = Vector2(1.0, 1.0)
	hint_hide_timer.stop()
	if _hint_flash_tween != null:
		_hint_flash_tween.kill()
		_hint_flash_tween = null


# 刷新紧凑顶部 UI 的倒计时条、本关用时与分数
func _update_compact_ui() -> void:
	compact_timer_bar.max_value = MAX_TIME
	compact_timer_bar.value = remaining_time
	compact_time_label.text = "[color=#8C5C33]本关用时：[/color][color=#FFF8F0]%s[/color]" % _format_time(level_time)
	compact_score_label.text = "[color=#8C5C33]分数：[/color][color=#E07A82]%d[/color]" % score


# 游戏开始 5 秒后尝试切换到紧凑 UI；若鼠标正在屏幕顶部则保持完整 UI
func _on_ui_hide_timer_timeout() -> void:
	if game_state != GameState.PLAYING or _is_paused:
		return
	if get_global_mouse_position().y <= TOP_TRIGGER_HEIGHT:
		return
	_show_compact_ui()


# 提示闪烁结束并停留 5 秒后隐藏恢复提示
func _on_hint_hide_timer_timeout() -> void:
	auto_hide_hint.hide()
	auto_hide_hint.modulate = Color.WHITE
	auto_hide_hint.scale = Vector2(1.0, 1.0)


# 重置游戏状态、棋盘与倒计时
func restart_game(reset_progress: bool = true) -> void:
	if reset_progress:
		current_level = 1

	if current_level > _get_max_level():
		current_level = 1

	game_state = GameState.PLAYING
	game_over_panel.hide()
	custom_dialog.hide()
	selected_index = -1
	pairs_left = _get_pairs()
	remaining_time = MAX_TIME
	_timer_running = true
	move_history.clear()
	undo_history.clear()
	level_time = 0.0
	_pending_next_level = -1
	_ui_hidden = false
	_top_leave_time = 0.0
	_auto_hide_hint_count = 0
	_combo_count = 0
	_update_combo_display()

	# 重置鼠标按键状态，避免跨关卡误触发左右键组合快捷键
	_left_mouse_pressed = false
	_right_mouse_pressed = false
	_left_press_time = 0
	_right_press_time = 0

	# 每次重新开始后恢复完整 UI，并在 5 秒后尝试自动隐藏
	_show_full_ui()
	ui_hide_timer.stop()
	ui_hide_timer.start(AUTO_HIDE_DELAY)

	if reset_progress:
		total_game_time = 0.0
		score = 0
		_last_eliminate_time = -1.0

	if current_level == 2:
		_roll_level2_direction()
	if current_level == 4:
		_roll_level4_direction()

	_generate_board()
	_update_all_cells()
	_update_ui()
	_update_timer_bar()
	_set_paused(false)
	_update_level_info()
	_update_time_labels()
	_update_score_label()
	_play_random_bgm()
	print("game started!")


# 同步倒计时进度条的最大值与当前值，最后 10 秒触发脉冲闪烁
func _update_timer_bar() -> void:
	timer_bar.max_value = MAX_TIME
	timer_bar.value = remaining_time
	compact_timer_bar.max_value = MAX_TIME
	compact_timer_bar.value = remaining_time

	var should_pulse := remaining_time <= 10.0 and remaining_time > 0.0 \
		and game_state == GameState.PLAYING and _timer_running and not _is_paused
	if should_pulse and _timer_pulse_tween == null:
		_timer_pulse_tween = _create_timer_pulse_tween(timer_bar)
		_compact_timer_pulse_tween = _create_timer_pulse_tween(compact_timer_bar)
	elif not should_pulse and _timer_pulse_tween != null:
		_timer_pulse_tween.kill()
		_timer_pulse_tween = null
		if _compact_timer_pulse_tween != null:
			_compact_timer_pulse_tween.kill()
			_compact_timer_pulse_tween = null
		timer_bar.modulate = Color.WHITE
		compact_timer_bar.modulate = Color.WHITE


# 创建倒计时条脉冲闪烁动画
func _create_timer_pulse_tween(bar: ProgressBar) -> Tween:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(bar, "modulate", Color(1.45, 1.45, 1.45, 1.0), 0.25)
	tween.tween_property(bar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)
	return tween


# 生成随机棋盘，并确保至少存在一对可消除的牌
func _generate_board() -> void:
	var rows := _get_rows()
	var cols := _get_cols()
	var pairs := _get_pairs()
	var tile_count := pairs

	# 根据当前图版和难度，使用对应文件夹里的实际图块数量
	tile_count = mini(_get_skin_tile_count(current_difficulty), pairs)

	var tiles: Array[int] = []
	# 先为每种图块生成一对
	for type in range(1, tile_count + 1):
		tiles.append(type)
		tiles.append(type)

	# 如果棋盘格数多于已有对数，循环补充成对的图块，确保所有图块成对出现
	var next_type := 1
	while tiles.size() < rows * cols:
		tiles.append(next_type)
		tiles.append(next_type)
		next_type = next_type % tile_count + 1

	# 随机洗牌并确保至少存在指定数量可消除的对
	var required := mini(MIN_MATCHABLE_PAIRS, pairs_left)
	var attempts := 0
	while true:
		tiles.shuffle()
		board.clear()
		for r in range(rows):
			board.append([])
			for c in range(cols):
				board[r].append(tiles[r * cols + c])

		if _count_matchable_pairs(required) >= required:
			break

		attempts += 1
		if attempts > 2000:
			push_warning("未能在 2000 次尝试内生成含 %d 对可消除牌的棋盘" % required)
			break


# 刷新所有格子的图案与选中状态
func _update_all_cells() -> void:
	var rows := _get_rows()
	var cols := _get_cols()
	for i in range(rows * cols):
		var cell: Cell = grid_container.get_child(i)
		var r := int(float(i) / cols)
		var c := i % cols
		cell.tile_type = board[r][c]
		cell.selected = (i == selected_index)


# 刷新按钮可用状态
func _update_ui() -> void:
	undo_button.disabled = move_history.is_empty()
	redo_button.disabled = undo_history.is_empty()


# 将秒数格式化为 MM:SS 或 HH:MM:SS
func _format_time(seconds: float) -> String:
	var total_secs := int(seconds)
	var hours := int(total_secs / 3600.0)
	var minutes := int((total_secs % 3600) / 60.0)
	var secs := total_secs % 60
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, secs]
	return "%02d:%02d" % [minutes, secs]


# 刷新时间显示
func _update_time_labels() -> void:
	time_label.text = "[color=#8C5C33]总用时：[/color][color=#FFF8F0]%s[/color] | [color=#8C5C33]本关用时：[/color][color=#FFF8F0]%s[/color]" % [_format_time(total_game_time), _format_time(level_time)]
	compact_time_label.text = "[color=#8C5C33]本关用时：[/color][color=#FFF8F0]%s[/color]" % _format_time(level_time)


# 刷新分数显示
func _update_score_label() -> void:
	score_label.text = "[color=#8C5C33]分数：[/color][color=#E07A82]%d[/color]" % score
	compact_score_label.text = "[color=#8C5C33]分数：[/color][color=#E07A82]%d[/color]" % score


# 分数标签大小变化时同步缩放中心
func _on_score_label_resized() -> void:
	score_label.pivot_offset = score_label.size / 2.0


func _emphasize_score_label(points: int = 0) -> void:
	var tier_color := _get_score_tier_color(points)

	# 根据当前显示模式，脉冲对应的分数标签
	var visible_score_label: RichTextLabel = score_label if score_label.visible else compact_score_label
	visible_score_label.pivot_offset = visible_score_label.size / 2.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(visible_score_label, "scale", Vector2(1.4, 1.4), 0.12)
	tween.tween_property(visible_score_label, "modulate", tier_color, 0.12)

	var tween_back := create_tween()
	tween_back.tween_property(visible_score_label, "scale", Vector2(1.0, 1.0), 0.18).set_delay(0.12)
	tween_back.tween_property(visible_score_label, "modulate", Color(1, 1, 1), 0.18).set_delay(0.12)


# 根据分数返回对应等级颜色
func _get_score_tier_color(points: int) -> Color:
	match points:
		30:
			return Color(SCORE_COLOR_GOLD)
		20:
			return Color(SCORE_COLOR_SILVER)
		15:
			return Color(SCORE_COLOR_BRONZE)
		_:
			return Color(SCORE_COLOR_NORMAL)


# 显示加分反馈：方案 1（消除位置飘字）+ 方案 2（分数标签旁弹出 + 标签脉冲）
func _show_score_feedback(points: int, match_midpoint: Vector2) -> void:
	# 方案 1：在消除位置飘出带等级色的分数
	if SCHEME_1_FLOATING_TEXT_ENABLED:
		_spawn_floating_score(points, match_midpoint)

	# 方案 2：在可见的分数标签旁弹出“+N”，同时分数标签脉冲变色
	var color_hex := SCORE_COLOR_NORMAL
	match points:
		30: color_hex = SCORE_COLOR_GOLD
		20: color_hex = SCORE_COLOR_SILVER
		15: color_hex = SCORE_COLOR_BRONZE
	var target_score_label: RichTextLabel = score_label if score_label.visible else compact_score_label
	score_gain_label.text = "[color=%s][b]+%d[/b][/color]" % [color_hex, points]
	score_gain_label.global_position = target_score_label.global_position + Vector2(target_score_label.size.x + 8.0, 4.0)
	score_gain_label.show()
	score_gain_label.modulate = Color.WHITE
	var start_y := score_gain_label.position.y
	var tween := create_tween()
	tween.tween_property(score_gain_label, "position:y", start_y - 24.0, 0.5)
	tween.parallel().tween_property(score_gain_label, "modulate:a", 0.0, 0.5)
	tween.finished.connect(func() -> void:
		score_gain_label.hide()
		score_gain_label.modulate = Color.WHITE
	)


# 方案 1：在指定位置生成向上飘动并逐渐消失的分数飘字（连击快时自动延长停留）
func _spawn_floating_score(points: int, pos: Vector2) -> void:
	var idx := _score_popup_index
	var popup: Label = score_popups[idx]
	_score_popup_index = (_score_popup_index + 1) % score_popups.size()

	# 若该飘字实例仍在动画中，先终止旧动画
	if _score_popup_tweens[idx] != null:
		_score_popup_tweens[idx].kill()
		_score_popup_tweens[idx] = null

	popup.text = "+%d" % points
	popup.modulate = _get_score_tier_color(points)
	popup.global_position = pos - popup.size / 2.0
	popup.show()

	# 连击越高，飘字停留越久（整体都比原来减短 0.3 秒）：
	# 0-1 连击：停留 0.0 秒 + 淡出 0.7 秒
	# 2-3 连击：停留 0.3 秒 + 淡出 0.9 秒
	# 4+ 连击：停留 0.7 秒 + 淡出 1.0 秒
	var linger_time := 0.0
	var fade_time := 0.7
	if _combo_count >= 4:
		linger_time = 0.7
		fade_time = 1.0
	elif _combo_count >= 2:
		linger_time = 0.3
		fade_time = 0.9

	var tween := create_tween()
	tween.tween_property(popup, "position:y", popup.position.y - 50.0, linger_time + fade_time)
	tween.parallel().tween_property(popup, "modulate:a", 1.0, linger_time)
	tween.chain().tween_property(popup, "modulate:a", 0.0, fade_time)
	tween.finished.connect(func() -> void:
		popup.hide()
		popup.modulate = Color.WHITE
		_score_popup_tweens[idx] = null
	)
	_score_popup_tweens[idx] = tween


# 方案 3：刷新连击标签显示
func _update_combo_display() -> void:
	var text := ""
	if _combo_count > 1:
		text = "[color=%s][b]连击 x%d[/b][/color]" % [SCORE_COLOR_GOLD, _combo_count]
	combo_label.text = text
	compact_combo_label.text = text


# 索引与行列坐标互转
func _index_to_pos(index: int) -> Vector2i:
	return Vector2i(int(float(index) / _get_cols()), index % _get_cols())


func _pos_to_index(r: int, c: int) -> int:
	return r * _get_cols() + c


# 模块：消除逻辑 —— 处理格子点击、选中、判断并执行消除
func _on_cell_clicked(index: int) -> void:
	if game_state != GameState.PLAYING:
		return
	if _is_paused or _is_animating:
		return

	var pos := _index_to_pos(index)
	var r := pos.x
	var c := pos.y
	if board[r][c] == 0:
		return

	# 第一次点击：选中
	if selected_index == -1:
		selected_index = index
		_update_all_cells()
		_play_sound(CLICK_SOUND)
		return

	# 点击同一个格子：取消选中
	if selected_index == index:
		selected_index = -1
		_update_all_cells()
		return

	var pos1 := _index_to_pos(selected_index)
	var r1 := pos1.x
	var c1 := pos1.y

	# 图案不同：改选新格子（错误音效）
	if board[r][c] != board[r1][c1]:
		selected_index = index
		_update_all_cells()
		_play_sound(ERROR_SOUND)
		return

	# 无法连通：改选新格子（错误音效）
	if not _can_connect(r1, c1, r, c):
		selected_index = index
		_update_all_cells()
		_play_sound(ERROR_SOUND)
		return

	# 可以消除：先绘制连接路径，再播放消除动画，然后更新棋盘数据
	var path: Array[Vector2i] = _find_connection_path(r1, c1, r, c)
	var points: PackedVector2Array = PackedVector2Array()
	for ext_pos in path:
		points.append(_extended_to_screen(ext_pos))
	match_line.points = points

	var cell1: Cell = grid_container.get_child(selected_index)
	var cell2: Cell = grid_container.get_child(index)
	_is_animating = true
	selected_index = -1
	_update_all_cells()

	var tween1 := cell1.play_eliminate_animation()
	var tween2 := cell2.play_eliminate_animation()
	if tween1 != null:
		await tween1.finished
	if tween2 != null:
		await tween2.finished

	match_line.points = PackedVector2Array()

	# 动画结束后才真正消除并计分
	var time_since_last: float = _eliminate(r1, c1, r, c)

	# 方案 1/2：显示加分反馈（方案 1 可通过 SCHEME_1_FLOATING_TEXT_ENABLED 单独关闭）
	# 飘字显示在第二次点击的格子中心
	var popup_pos: Vector2 = cell2.global_position + cell2.size / 2.0
	_show_score_feedback(_last_points, popup_pos)

	if current_level == 2:
		match _level2_direction:
			Level2Dir.LEFT:
				_collapse_left()
			Level2Dir.RIGHT:
				_collapse_right()
	elif current_level == 3:
		_collapse_outward()
	elif current_level == 4:
		match _level4_direction:
			Level4Dir.UP:
				_collapse_up()
			Level4Dir.DOWN:
				_collapse_down()
	elif current_level == 5:
		_collapse_inward()
	elif current_level == 6:
		_collapse_horizontal_expand()
	elif current_level == 7:
		_collapse_vertical_expand()
	elif current_level == 8:
		_collapse_horizontal_converge()
	elif current_level == 9:
		_collapse_vertical_converge()
	elif current_level == 10:
		_collapse_quadrant_spread()
	_update_all_cells()
	_update_ui()
	_is_animating = false

	if time_since_last > 10.0:
		_play_sound(SUCCESS_SLOW_SOUND)
	else:
		_play_sound(SUCCESS_SOUND)

	if pairs_left == 0:
		_on_level_complete()
	elif not _has_any_match():
		_shuffle_remaining()
		_update_all_cells()


# 消除两个格子，并奖励额外时间；返回距离上次消除的秒数
func _eliminate(r1: int, c1: int, r2: int, c2: int) -> float:
	# 记录消除前的完整棋盘与分数/时间状态，用于撤销/重做
	var move := {
		"board_before": board.duplicate(true),
		"pairs_left_before": pairs_left,
		"level_before": current_level,
		"total_time_before": total_game_time,
		"level_time_before": level_time,
		"score_before": score,
		"last_eliminate_time_before": _last_eliminate_time
	}
	move_history.append(move)
	undo_history.clear()

	# 计算连续消除得分
	var time_since_last: float
	if _last_eliminate_time < 0:
		time_since_last = -1.0
	else:
		time_since_last = total_game_time - _last_eliminate_time

	var points: int
	if time_since_last < 0:
		points = 10
	elif time_since_last <= 3.0:
		points = 30
	elif time_since_last <= 5.0:
		points = 20
	elif time_since_last <= 10.0:
		points = 15
	elif time_since_last <= 20.0:
		points = 12
	else:
		points = 10

	score += points
	_last_points = points
	_last_eliminate_time = total_game_time

	# 更新连击计数：10 秒内消除连击 +1，否则从 1 开始新的连击
	if time_since_last >= 0 and time_since_last <= COMBO_FAST_THRESHOLD:
		_combo_count += 1
	else:
		_combo_count = 1
	_update_combo_display()

	_update_score_label()
	_emphasize_score_label(points)

	board[r1][c1] = 0
	board[r2][c2] = 0
	pairs_left -= 1
	_update_pairs_label()

	remaining_time = min(MAX_TIME, remaining_time + TIME_BONUS)
	_update_timer_bar()

	return time_since_last


# 判断两个格子能否连通
func _can_connect(r1: int, c1: int, r2: int, c2: int) -> bool:
	return not _find_connection_path(r1, c1, r2, c2).is_empty()


# 模块：路径查找 —— BFS 搜索可连通路径，扩展棋盘外圈为虚拟空白，限制转弯次数 ≤ 2
func _find_connection_path(r1: int, c1: int, r2: int, c2: int) -> Array[Vector2i]:
	if board[r1][c1] == 0 or board[r2][c2] == 0:
		return []
	if board[r1][c1] != board[r2][c2]:
		return []
	if r1 == r2 and c1 == c2:
		return []

	var start := Vector2i(r1 + 1, c1 + 1)
	var end := Vector2i(r2 + 1, c2 + 1)
	const INF := 999

	var visited: Array = []
	var came_from: Array = []
	for i in range(_get_rows() + 2):
		visited.append([])
		came_from.append([])
		for j in range(_get_cols() + 2):
			visited[i].append([INF, INF, INF, INF])
			came_from[i].append([null, null, null, null])

	var queue: Array = []
	for d in range(4):
		var next: Vector2i = start + DIRECTIONS[d]
		var prev_pos: Vector2i = start
		var first_step := true
		while _is_passable(next, end):
			if visited[next.x][next.y][d] > 0:
				visited[next.x][next.y][d] = 0
				var prev_dir: int = -1 if first_step else d
				came_from[next.x][next.y][d] = [prev_pos, prev_dir]
				queue.append([next, d, 0])
			prev_pos = next
			next += DIRECTIONS[d]
			first_step = false

	while queue.size() > 0:
		var item: Array = queue.pop_front()
		var pos: Vector2i = item[0]
		var dir: int = item[1]
		var turns: int = item[2]

		if pos == end:
			return _reconstruct_path(came_from, end, dir, start)

		for new_dir in range(4):
			if new_dir == dir:
				continue
			var new_turns := turns + 1
			if new_turns > 2:
				continue
			var next: Vector2i = pos + DIRECTIONS[new_dir]
			var prev_pos: Vector2i = pos
			var first_step := true
			while _is_passable(next, end):
				if visited[next.x][next.y][new_dir] > new_turns:
					visited[next.x][next.y][new_dir] = new_turns
					var prev_dir: int = dir if first_step else new_dir
					came_from[next.x][next.y][new_dir] = [prev_pos, prev_dir]
					queue.append([next, new_dir, new_turns])
				prev_pos = next
				next += DIRECTIONS[new_dir]
				first_step = false

	return []


# 根据 BFS 记录回溯出完整路径
func _reconstruct_path(came_from: Array, end_pos: Vector2i, end_dir: int, start_pos: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [end_pos]
	var cur_pos: Vector2i = end_pos
	var cur_dir: int = end_dir

	while cur_pos != start_pos:
		var cf = came_from[cur_pos.x][cur_pos.y][cur_dir]
		if cf == null or cf[0] == null:
			break
		var prev_pos: Vector2i = cf[0]
		var prev_dir: int = cf[1]
		var step: Vector2i = (cur_pos - prev_pos).sign()
		if step == Vector2i.ZERO:
			break
		var p: Vector2i = cur_pos - step
		while p != prev_pos:
			path.append(p)
			p -= step
		path.append(prev_pos)
		cur_pos = prev_pos
		cur_dir = prev_dir

	path.reverse()
	return path


# 将扩展棋盘坐标转换为全局屏幕坐标（CanvasLayer 中的 HintLine 使用全局坐标）
func _extended_to_screen(ext_pos: Vector2i) -> Vector2:
	var cell: Cell = grid_container.get_child(0)
	var cell_size: Vector2 = cell.size
	var h_sep: int = grid_container.get_theme_constant("h_separation")
	var v_sep: int = grid_container.get_theme_constant("v_separation")
	var base: Vector2 = cell.position + cell_size / 2.0
	var local_in_aspect := grid_container.position + Vector2(
		base.x + (ext_pos.y - 1) * (cell_size.x + h_sep),
		base.y + (ext_pos.x - 1) * (cell_size.y + v_sep)
	)
	return aspect_ratio_container.global_position + local_in_aspect


# 判断扩展坐标是否可通行（棋盘外圈视为空白）
func _is_passable(ext_pos: Vector2i, end: Vector2i) -> bool:
	if ext_pos == end:
		return true
	if ext_pos.x < 0 or ext_pos.x > _get_rows() + 1 or ext_pos.y < 0 or ext_pos.y > _get_cols() + 1:
		return false
	if ext_pos.x == 0 or ext_pos.x == _get_rows() + 1 or ext_pos.y == 0 or ext_pos.y == _get_cols() + 1:
		return true
	return board[ext_pos.x - 1][ext_pos.y - 1] == 0


# 检查剩余牌中是否存在至少一对可连通的牌
func _has_any_match() -> bool:
	var positions: Dictionary[int, Array] = {}
	for r in range(_get_rows()):
		for c in range(_get_cols()):
			var type :int = board[r][c]
			if type == 0:
				continue
			if not positions.has(type):
				positions[type] = []
			positions[type].append(Vector2i(r, c))

	for type: int in positions.keys():
		var arr: Array = positions[type]
		for i in range(arr.size()):
			for j in range(i + 1, arr.size()):
				var p1: Vector2i = arr[i]
				var p2: Vector2i = arr[j]
				if _can_connect(p1.x, p1.y, p2.x, p2.y):
					return true
	return false


# 统计当前棋盘里可以消除的对数，达到 max_count 后提前返回
func _count_matchable_pairs(max_count: int = 999) -> int:
	var positions: Dictionary[int, Array] = {}
	for r in range(_get_rows()):
		for c in range(_get_cols()):
			var type: int = board[r][c]
			if type == 0:
				continue
			if not positions.has(type):
				positions[type] = []
			positions[type].append(Vector2i(r, c))

	var count := 0
	for type: int in positions.keys():
		var arr: Array = positions[type]
		for i in range(arr.size()):
			for j in range(i + 1, arr.size()):
				var p1: Vector2i = arr[i]
				var p2: Vector2i = arr[j]
				if _can_connect(p1.x, p1.y, p2.x, p2.y):
					count += 1
					if count >= max_count:
						return count
	return count


# 查找一对可消除的图案，返回完整连接路径（扩展坐标）；找不到返回空数组
func _find_hint_pair() -> Array[Vector2i]:
	var positions: Dictionary[int, Array] = {}
	for r in range(_get_rows()):
		for c in range(_get_cols()):
			var type: int = board[r][c]
			if type == 0:
				continue
			if not positions.has(type):
				positions[type] = []
			positions[type].append(Vector2i(r, c))

	for type: int in positions.keys():
		var arr: Array = positions[type]
		for i in range(arr.size()):
			for j in range(i + 1, arr.size()):
				var p1: Vector2i = arr[i]
				var p2: Vector2i = arr[j]
				var path := _find_connection_path(p1.x, p1.y, p2.x, p2.y)
				if not path.is_empty():
					return path
	return []


# 模块：坍塌 —— 消除后整行向左靠拢
func _collapse_left() -> void:
	for r in range(_get_rows()):
		var new_row: Array[int] = []
		for c in range(_get_cols()):
			if board[r][c] != 0:
				new_row.append(board[r][c])
		while new_row.size() < _get_cols():
			new_row.append(0)
		board[r] = new_row


# 模块：坍塌 —— 消除后整行向右靠拢
func _collapse_right() -> void:
	for r in range(_get_rows()):
		var new_row: Array[int] = []
		for c in range(_get_cols()):
			if board[r][c] != 0:
				new_row.append(board[r][c])
		while new_row.size() < _get_cols():
			new_row.push_front(0)
		board[r] = new_row


# 模块：坍塌 —— 消除后整列向上靠拢
func _collapse_up() -> void:
	for c in range(_get_cols()):
		var new_col: Array[int] = []
		for r in range(_get_rows()):
			if board[r][c] != 0:
				new_col.append(board[r][c])
		while new_col.size() < _get_rows():
			new_col.append(0)
		for r in range(_get_rows()):
			board[r][c] = new_col[r]


# 模块：坍塌 —— 消除后整列向下靠拢
func _collapse_down() -> void:
	for c in range(_get_cols()):
		var new_col: Array[int] = []
		for r in range(_get_rows()):
			if board[r][c] != 0:
				new_col.append(board[r][c])
		while new_col.size() < _get_rows():
			new_col.push_front(0)
		for r in range(_get_rows()):
			board[r][c] = new_col[r]


# 模块：坍塌 —— 消除后向四周（从中心向外）扩散
func _collapse_outward() -> void:
	var center_r: int = int(_get_rows() / 2.0)
	var center_c: int = int(_get_cols() / 2.0)

	# 水平方向：中心左侧向左靠拢，中心右侧向右靠拢
	for r in range(_get_rows()):
		var left_part: Array[int] = []
		var right_part: Array[int] = []
		for c in range(center_c):
			if board[r][c] != 0:
				left_part.append(board[r][c])
		for c in range(center_c, _get_cols()):
			if board[r][c] != 0:
				right_part.append(board[r][c])

		var new_left: Array[int] = left_part.duplicate()
		while new_left.size() < center_c:
			new_left.append(0)

		var new_right: Array[int] = []
		for i in range(center_c - right_part.size()):
			new_right.append(0)
		new_right.append_array(right_part)

		for c in range(center_c):
			board[r][c] = new_left[c]
		for c in range(center_c, _get_cols()):
			board[r][c] = new_right[c - center_c]

	# 垂直方向：中心上侧向上靠拢，中心下侧向下靠拢
	for c in range(_get_cols()):
		var top_part: Array[int] = []
		var bottom_part: Array[int] = []
		for r in range(center_r):
			if board[r][c] != 0:
				top_part.append(board[r][c])
		for r in range(center_r, _get_rows()):
			if board[r][c] != 0:
				bottom_part.append(board[r][c])

		var new_top: Array[int] = top_part.duplicate()
		while new_top.size() < center_r:
			new_top.append(0)

		var new_bottom: Array[int] = []
		for i in range((_get_rows() - center_r) - bottom_part.size()):
			new_bottom.append(0)
		new_bottom.append_array(bottom_part)

		for r in range(center_r):
			board[r][c] = new_top[r]
		for r in range(center_r, _get_rows()):
			board[r][c] = new_bottom[r - center_r]


# 模块：坍塌 —— 消除后从四周向中心聚拢
func _collapse_inward() -> void:
	var center_r: int = int(_get_rows() / 2.0)
	var center_c: int = int(_get_cols() / 2.0)

	# 水平方向：中心左侧向右靠拢，中心右侧向左靠拢
	for r in range(_get_rows()):
		var left_part: Array[int] = []
		var right_part: Array[int] = []
		for c in range(center_c):
			if board[r][c] != 0:
				left_part.append(board[r][c])
		for c in range(center_c, _get_cols()):
			if board[r][c] != 0:
				right_part.append(board[r][c])

		var new_left: Array[int] = []
		for i in range(center_c - left_part.size()):
			new_left.append(0)
		new_left.append_array(left_part)

		var new_right: Array[int] = right_part.duplicate()
		while new_right.size() < (_get_cols() - center_c):
			new_right.append(0)

		for c in range(center_c):
			board[r][c] = new_left[c]
		for c in range(center_c, _get_cols()):
			board[r][c] = new_right[c - center_c]

	# 垂直方向：中心上侧向下靠拢，中心下侧向上靠拢
	for c in range(_get_cols()):
		var top_part: Array[int] = []
		var bottom_part: Array[int] = []
		for r in range(center_r):
			if board[r][c] != 0:
				top_part.append(board[r][c])
		for r in range(center_r, _get_rows()):
			if board[r][c] != 0:
				bottom_part.append(board[r][c])

		var new_top: Array[int] = []
		for i in range(center_r - top_part.size()):
			new_top.append(0)
		new_top.append_array(top_part)

		var new_bottom: Array[int] = bottom_part.duplicate()
		while new_bottom.size() < (_get_rows() - center_r):
			new_bottom.append(0)

		for r in range(center_r):
			board[r][c] = new_top[r]
		for r in range(center_r, _get_rows()):
			board[r][c] = new_bottom[r - center_r]


# 模块：坍塌 —— 消除后以垂直中线为基准向左右两边扩散
func _collapse_horizontal_expand() -> void:
	var center_c: int = int(_get_cols() / 2.0)
	for r in range(_get_rows()):
		var left_part: Array[int] = []
		var right_part: Array[int] = []
		for c in range(center_c):
			if board[r][c] != 0:
				left_part.append(board[r][c])
		for c in range(center_c, _get_cols()):
			if board[r][c] != 0:
				right_part.append(board[r][c])

		var new_left: Array[int] = left_part.duplicate()
		while new_left.size() < center_c:
			new_left.append(0)

		var new_right: Array[int] = []
		for i in range((_get_cols() - center_c) - right_part.size()):
			new_right.append(0)
		new_right.append_array(right_part)

		for c in range(center_c):
			board[r][c] = new_left[c]
		for c in range(center_c, _get_cols()):
			board[r][c] = new_right[c - center_c]


# 模块：坍塌 —— 消除后以水平中线为基准向上下两边扩散
func _collapse_vertical_expand() -> void:
	var center_r: int = int(_get_rows() / 2.0)
	for c in range(_get_cols()):
		var top_part: Array[int] = []
		var bottom_part: Array[int] = []
		for r in range(center_r):
			if board[r][c] != 0:
				top_part.append(board[r][c])
		for r in range(center_r, _get_rows()):
			if board[r][c] != 0:
				bottom_part.append(board[r][c])

		var new_top: Array[int] = top_part.duplicate()
		while new_top.size() < center_r:
			new_top.append(0)

		var new_bottom: Array[int] = []
		for i in range((_get_rows() - center_r) - bottom_part.size()):
			new_bottom.append(0)
		new_bottom.append_array(bottom_part)

		for r in range(center_r):
			board[r][c] = new_top[r]
		for r in range(center_r, _get_rows()):
			board[r][c] = new_bottom[r - center_r]


# 模块：坍塌 —— 消除后以垂直中线为基准向中心汇聚
func _collapse_horizontal_converge() -> void:
	var center_c: int = int(_get_cols() / 2.0)
	for r in range(_get_rows()):
		var left_part: Array[int] = []
		var right_part: Array[int] = []
		for c in range(center_c):
			if board[r][c] != 0:
				left_part.append(board[r][c])
		for c in range(center_c, _get_cols()):
			if board[r][c] != 0:
				right_part.append(board[r][c])

		var new_left: Array[int] = []
		for i in range(center_c - left_part.size()):
			new_left.append(0)
		new_left.append_array(left_part)

		var new_right: Array[int] = right_part.duplicate()
		while new_right.size() < (_get_cols() - center_c):
			new_right.append(0)

		for c in range(center_c):
			board[r][c] = new_left[c]
		for c in range(center_c, _get_cols()):
			board[r][c] = new_right[c - center_c]


# 模块：坍塌 —— 消除后以水平中线为基准向中心汇聚
func _collapse_vertical_converge() -> void:
	var center_r: int = int(_get_rows() / 2.0)
	for c in range(_get_cols()):
		var top_part: Array[int] = []
		var bottom_part: Array[int] = []
		for r in range(center_r):
			if board[r][c] != 0:
				top_part.append(board[r][c])
		for r in range(center_r, _get_rows()):
			if board[r][c] != 0:
				bottom_part.append(board[r][c])

		var new_top: Array[int] = []
		for i in range(center_r - top_part.size()):
			new_top.append(0)
		new_top.append_array(top_part)

		var new_bottom: Array[int] = bottom_part.duplicate()
		while new_bottom.size() < (_get_rows() - center_r):
			new_bottom.append(0)

		for r in range(center_r):
			board[r][c] = new_top[r]
		for r in range(center_r, _get_rows()):
			board[r][c] = new_bottom[r - center_r]


# 模块：坍塌 —— 消除后四个象限分别向东南西北扩散
func _collapse_quadrant_spread() -> void:
	var center_r: int = int(_get_rows() / 2.0)
	var center_c: int = int(_get_cols() / 2.0)

	# 第一象限（右上）：向下坍塌
	for c in range(center_c, _get_cols()):
		var part: Array[int] = []
		for r in range(center_r):
			if board[r][c] != 0:
				part.append(board[r][c])
		var new_part: Array[int] = []
		for i in range(center_r - part.size()):
			new_part.append(0)
		new_part.append_array(part)
		for r in range(center_r):
			board[r][c] = new_part[r]

	# 第二象限（左上）：向上坍塌
	for c in range(center_c):
		var part: Array[int] = []
		for r in range(center_r):
			if board[r][c] != 0:
				part.append(board[r][c])
		var new_part: Array[int] = part.duplicate()
		while new_part.size() < center_r:
			new_part.append(0)
		for r in range(center_r):
			board[r][c] = new_part[r]

	# 第三象限（左下）：向左坍塌
	for r in range(center_r, _get_rows()):
		var part: Array[int] = []
		for c in range(center_c):
			if board[r][c] != 0:
				part.append(board[r][c])
		var new_part: Array[int] = part.duplicate()
		while new_part.size() < center_c:
			new_part.append(0)
		for c in range(center_c):
			board[r][c] = new_part[c]

	# 第四象限（右下）：向右坍塌
	for r in range(center_r, _get_rows()):
		var part: Array[int] = []
		for c in range(center_c, _get_cols()):
			if board[r][c] != 0:
				part.append(board[r][c])
		var new_part: Array[int] = []
		for i in range((_get_cols() - center_c) - part.size()):
			new_part.append(0)
		new_part.append_array(part)
		for c in range(center_c, _get_cols()):
			board[r][c] = new_part[c - center_c]


func _shuffle_remaining() -> void:
	var remaining: Array[int] = []
	for r in range(_get_rows()):
		for c in range(_get_cols()):
			if board[r][c] != 0:
				remaining.append(board[r][c])

	if remaining.is_empty():
		return

	var required := mini(MIN_MATCHABLE_PAIRS, pairs_left)
	var attempts := 0
	while true:
		remaining.shuffle()
		var idx := 0
		for r in range(_get_rows()):
			for c in range(_get_cols()):
				if board[r][c] != 0:
					board[r][c] = remaining[idx]
					idx += 1

		if _count_matchable_pairs(required) >= required:
			break

		attempts += 1
		if attempts > 2000:
			push_warning("未能在 2000 次尝试内洗出含 %d 对可消除牌的棋盘" % required)
			break


# 模块：撤销 / 重做 —— 撤销上一步消除
func _on_undo_button_pressed() -> void:
	if move_history.is_empty() or _is_paused or _is_animating:
		return

	var last: Dictionary = move_history.pop_back()

	# 保存当前状态用于重做
	var redo_move := {
		"board_before": board.duplicate(true),
		"pairs_left_before": pairs_left,
		"level_before": current_level,
		"total_time_before": total_game_time,
		"level_time_before": level_time,
		"score_before": score,
		"last_eliminate_time_before": _last_eliminate_time
	}
	undo_history.append(redo_move)

	# 恢复到消除前的棋盘状态
	board = last["board_before"].duplicate(true)
	pairs_left = last["pairs_left_before"]
	current_level = last["level_before"]
	total_game_time = last["total_time_before"]
	level_time = last["level_time_before"]
	score = last["score_before"]
	_last_eliminate_time = last["last_eliminate_time_before"]
	selected_index = -1
	game_state = GameState.PLAYING
	game_over_panel.hide()
	_pending_next_level = -1
	custom_dialog.hide()
	_combo_count = 0
	_update_combo_display()
	_update_all_cells()
	_update_ui()
	_update_level_info()
	_update_time_labels()
	_update_score_label()


# 模块：撤销 / 重做 —— 重做一步被撤销的消除
func _on_redo_button_pressed() -> void:
	if undo_history.is_empty() or _is_paused or _is_animating:
		return

	var redo: Dictionary = undo_history.pop_back()

	# 保存当前状态用于撤销
	var move := {
		"board_before": board.duplicate(true),
		"pairs_left_before": pairs_left,
		"level_before": current_level,
		"total_time_before": total_game_time,
		"level_time_before": level_time,
		"score_before": score,
		"last_eliminate_time_before": _last_eliminate_time
	}
	move_history.append(move)

	# 恢复重做时的棋盘状态
	board = redo["board_before"].duplicate(true)
	pairs_left = redo["pairs_left_before"]
	current_level = redo["level_before"]
	total_game_time = redo["total_time_before"]
	level_time = redo["level_time_before"]
	score = redo["score_before"]
	_last_eliminate_time = redo["last_eliminate_time_before"]
	selected_index = -1
	_combo_count = 0
	_update_combo_display()
	_update_all_cells()
	_update_ui()
	_update_level_info()
	_update_time_labels()
	_update_score_label()

	if pairs_left == 0:
		_on_level_complete()
	elif not _has_any_match():
		_shuffle_remaining()
		_update_all_cells()


# 模块：提示与洗牌 —— 高亮一对可连通的图案并画线
func _on_hint_button_pressed() -> void:
	if game_state != GameState.PLAYING or _hint_active or _is_paused or _is_animating:
		return

	var path: Array[Vector2i] = _find_hint_pair()
	if path.is_empty():
		return

	_hint_active = true

	# 让两个目标格子的图片闪烁两下
	var start_ext: Vector2i = path[0]
	var end_ext: Vector2i = path[path.size() - 1]
	var start_board := Vector2i(start_ext.x - 1, start_ext.y - 1)
	var end_board := Vector2i(end_ext.x - 1, end_ext.y - 1)
	var start_cell: Cell = grid_container.get_child(_pos_to_index(start_board.x, start_board.y))
	var end_cell: Cell = grid_container.get_child(_pos_to_index(end_board.x, end_board.y))

	start_cell.flash()
	end_cell.flash()

	var points: PackedVector2Array = PackedVector2Array()
	for ext_pos in path:
		points.append(_extended_to_screen(ext_pos))

	hint_line.points = points
	await get_tree().create_timer(1.5).timeout
	hint_line.points = PackedVector2Array()
	_hint_active = false


# 模块：提示与洗牌 —— 手动重排剩余图案
func _on_shuffle_button_pressed() -> void:
	if game_state != GameState.PLAYING or _is_paused or _is_animating:
		return

	_shuffle_remaining()
	selected_index = -1
	_update_all_cells()
	_update_ui()


# 重新开始本局（保留总分与总用时）
func _on_restart_button_pressed() -> void:
	if _is_animating:
		return
	restart_game(false)
