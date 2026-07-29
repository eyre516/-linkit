extends Control

# 主游戏控制器：管理 UI 交互、菜单、弹窗、游戏流程与三个 Manager 的协作。

enum GameState {PLAYING, GAME_OVER}
enum GameMode {CASUAL, COMPETITIVE, CHALLENGE, ENDLESS, DAILY}

# ------------------------------
# 模块：游戏常量
# 说明：关卡名称、竞技模式限制、UI 自动隐藏与加分反馈常量
# ------------------------------
const LEVEL_NAMES := {
	1: "不变",
	2: "向左/右",
	3: "向外扩",
	4: "向上/下",
	5: "向内聚",
	6: "向左右扩",
	7: "向上下扩",
	8: "向竖中线聚",
	9: "向横中线聚",
	10: "左扩右聚"
}

enum Level2Dir {LEFT, RIGHT}
enum Level4Dir {UP, DOWN}

# 竞技模式每关可用的提示与洗牌次数
const COMPETITIVE_EARLY_LEVELS := 7
const COMPETITIVE_EARLY_HINTS := 5
const COMPETITIVE_EARLY_SHUFFLES := 2
const COMPETITIVE_LATE_HINTS := 8
const COMPETITIVE_LATE_SHUFFLES := 3

# 背景音乐相对主音量的缩放比例（0.5 表示背景音乐为主音量的一半）
const BGM_VOLUME_SCALE := 0.35

const FIREWORKS_SCENE := preload("res://fireworks.tscn")
const EMOJI_FONT := preload("res://assets/fonts/NotoColorEmoji.ttf")
var chinese_font: FontFile = preload("res://assets/fonts/NotoSerifSC-Regular.otf")

# 顶部 UI 自动隐藏相关常量
const AUTO_HIDE_DELAY := 5.0          # 游戏开始后多久自动隐藏顶部 UI
const TOP_TRIGGER_HEIGHT := 24.0      # 鼠标移到屏幕顶部多少像素内触发显示
const TOP_HIDE_DELAY := 1.5           # 鼠标离开顶部后多久恢复紧凑 UI

# 加分反馈相关常量
const SCHEME_1_FLOATING_TEXT_ENABLED := true  # 方案 1：消除位置飘字（可独立开关）

# 自定义弹窗类型与回调
enum DialogType {WELCOME, RULES, ABOUT, SHORTCUTS, SCORE_RULES, MODE_RULES, LEVEL_COMPLETE, LEADERBOARD, NAME_INPUT}
var _current_dialog_type: DialogType = DialogType.WELCOME
var _dialog_callback: Callable = Callable()

# 排行榜类型：总分榜按分数排序，速通榜按总用时排序
enum LeaderboardType {SCORE, SPEEDRUN}

# ------------------------------
# 模块：游戏状态与运行数据
# 说明：当前对局状态、选中索引、历史记录、竞技模式次数等
# ------------------------------
var game_state: GameState
var selected_index: int = -1

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

# 鼠标右键双击洗牌的判定窗口（秒），同时决定单次右键提示的延迟
const RIGHT_CLICK_DOUBLE_INTERVAL := 0.25
var _right_click_timer: Timer = null

# 当前难度：1=初级，2=中级，3=高级
var current_level: int = 1
var _level2_direction: Level2Dir = Level2Dir.LEFT
var _level4_direction: Level4Dir = Level4Dir.UP
var current_difficulty: int = 1

# 游戏模式与竞技模式剩余次数（休闲模式不消耗次数）
var current_mode: GameMode = GameMode.COMPETITIVE
var hints_remaining: int = 0
var shuffles_remaining: int = 0

# 排行榜数据：键为难度 "1"/"2"/"3"，值为记录数组
var _leaderboard_data: Dictionary = {}
const LEADERBOARD_FILE := "user://leaderboard.json"

# 排行榜弹窗当前查看的难度与页码（0 起始）
var _leaderboard_difficulty: int = 1
var _leaderboard_page: int = 0
var _leaderboard_type: LeaderboardType = LeaderboardType.SCORE
const LEADERBOARD_MAX_ENTRIES := 1000
const LEADERBOARD_ENTRIES_PER_PAGE := 10
const SETTINGS_FILE := "user://settings.json"

# 本次通关的每关统计：关卡、用时、提示次数、洗牌次数
var _session_level_stats: Array[Dictionary] = []
var _level_hints_used: int = 0
var _level_shuffles_used: int = 0

# 关卡完成弹窗待进入的下一关
var _pending_next_level: int = -1

# 从游戏结束面板打开排行榜后，关闭排行榜时是否返回游戏结束面板
var _return_to_game_over_panel: bool = false

# 菜单栏相关的弹出菜单列表，用于判断鼠标是否在菜单交互区域
var _popup_menus: Array[PopupMenu] = []

# 音量与开关（游戏主控保存真实值，AudioManager 执行）
var sound_effects_enabled: bool = true
var background_music_enabled: bool = true
var master_volume: float = 0.8
var sfx_volume: float = 0.8
var bgm_volume: float = 0.5

# ------------------------------
# 模块：Manager 引用
# ------------------------------
@onready var audio_manager: AudioManager = %AudioManager
@onready var board_manager: BoardManager = %BoardManager
@onready var score_manager: ScoreManager = %ScoreManager

# ------------------------------
# 模块：UI 节点引用
# 说明：按钮、标签、进度条、网格与提示线等场景节点
# ------------------------------
@onready var undo_button: Button = %UndoButton
@onready var redo_button: Button = %RedoButton
@onready var pause_button: Button = %PauseButton
@onready var restart_button: Button = %RestartButton
@onready var restart_button_2: Button = %RestartButton2
@onready var hint_button: Button = %HintButton
@onready var shuffle_button: Button = %ShuffleButton
@onready var time_label: RichTextLabel = %TimeLabel
@onready var mode_label: RichTextLabel = %ModeLabel
@onready var score_label: RichTextLabel = %ScoreLabel
@onready var difficulty_label: RichTextLabel = %DifficultyLabel
@onready var level_label: RichTextLabel = %LevelLabel
@onready var remaining_pairs_label: RichTextLabel = %RemainingPairsLabel
@onready var timer_bar: ProgressBar = %TimerBar
@onready var compact_timer_bar: ProgressBar = %CompactTimerBar
@onready var _timer_gradient: Gradient = %TimerBar.get_theme_stylebox("fill").texture.gradient
@onready var compact_time_label: RichTextLabel = %CompactTimeLabel
@onready var compact_score_label: RichTextLabel = %CompactScoreLabel
@onready var menu_bar: PanelContainer = %MenuBar
@onready var info_bar: PanelContainer = %InfoBar
@onready var toolbar: HBoxContainer = %HBoxContainer
@onready var compact_top_bar: PanelContainer = %CompactTopBar
@onready var ui_hide_timer: Timer = %UIHideTimer
@onready var menu_bar_tab: PanelContainer = %MenuBarTab
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
@onready var game_over_panel: PanelContainer = %GameOverPanel
@onready var game_over_label: Label = %GameOverLabel
@onready var game_over_stats_label: RichTextLabel = %GameOverStatsLabel
@onready var next_level_button: Button = %NextLevelButton
@onready var replay_level_button: Button = %ReplayLevelButton
@onready var view_leaderboard_button: Button = %ViewLeaderboardButton
@onready var return_to_menu_button: Button = %ReturnToMenuButton
@onready var auto_shuffle_hint: Label = %AutoShuffleHint
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
@onready var welcome_panel: HBoxContainer = %WelcomePanel
@onready var welcome_rule_label: RichTextLabel = %WelcomeRuleLabel
@onready var welcome_must_read_label: RichTextLabel = %WelcomeMustReadLabel
@onready var welcome_op_label: RichTextLabel = %WelcomeOpLabel

@onready var leaderboard_panel: VBoxContainer = %LeaderboardPanel
@onready var leaderboard_content: RichTextLabel = %LeaderboardContent
@onready var leaderboard_page_label: Label = %LeaderboardPageLabel
@onready var leaderboard_close_button: Button = %LeaderboardCloseButton
@onready var leaderboard_tab_buttons: Array[Button] = [%LeaderboardTab1, %LeaderboardTab2, %LeaderboardTab3]
@onready var leaderboard_prev_button: Button = %PrevPageButton
@onready var leaderboard_next_button: Button = %NextPageButton
@onready var leaderboard_type_score_button: Button = %LeaderboardTypeScore
@onready var leaderboard_type_speedrun_button: Button = %LeaderboardTypeSpeedrun
@onready var export_leaderboard_button: Button = %ExportLeaderboardButton
@onready var share_leaderboard_button: Button = %ShareLeaderboardButton


# 模块：生命周期 —— 初始化音频、棋盘、菜单与游戏
func _ready() -> void:
	# 为主题默认字体（NotoSerifSC）添加 Emoji 回退，确保按钮中的 emoji 正常显示
	if chinese_font != null:
		chinese_font.fallbacks = [EMOJI_FONT]

	randomize()
	board_manager.setup(grid_container, aspect_ratio_container, board_center, cell_scene)
	Cell.set_level(current_difficulty)
	board_manager.setup_grid(_on_cell_clicked)
	_setup_menus()
	_load_leaderboard()
	restart_game()
	_show_welcome_dialog()

	hint_button.pressed.connect(_on_hint_button_pressed)
	dialog_name_input.text_submitted.connect(_on_name_input_submitted)
	shuffle_button.pressed.connect(_on_shuffle_button_pressed)
	pause_button.pressed.connect(_toggle_pause)
	# UIHideTimer / HintHideTimer 的 timeout 信号已在 game.tscn 中连接

	# 排行榜弹窗按钮
	leaderboard_tab_buttons[0].pressed.connect(_on_leaderboard_tab_pressed.bind(1))
	leaderboard_tab_buttons[1].pressed.connect(_on_leaderboard_tab_pressed.bind(2))
	leaderboard_tab_buttons[2].pressed.connect(_on_leaderboard_tab_pressed.bind(3))
	leaderboard_prev_button.pressed.connect(_on_leaderboard_prev_page_pressed)
	leaderboard_next_button.pressed.connect(_on_leaderboard_next_page_pressed)
	leaderboard_close_button.pressed.connect(_hide_custom_dialog)
	leaderboard_type_score_button.pressed.connect(_on_leaderboard_type_pressed.bind(LeaderboardType.SCORE))
	leaderboard_type_speedrun_button.pressed.connect(_on_leaderboard_type_pressed.bind(LeaderboardType.SPEEDRUN))
	export_leaderboard_button.pressed.connect(_on_export_leaderboard_pressed)
	share_leaderboard_button.pressed.connect(_on_share_leaderboard_pressed)

	# 暂停菜单按钮
	%ResumeButton.pressed.connect(_on_resume_button_pressed)
	%RestartButton2.pressed.connect(_on_restart_button_pressed)
	%SettingsButton.pressed.connect(_on_settings_button_pressed)
	%CloseSettingsButton.pressed.connect(_on_close_settings_button_pressed)

	# 游戏结束/关卡完成面板按钮
	next_level_button.pressed.connect(_on_next_level_button_pressed)
	replay_level_button.pressed.connect(_on_replay_level_button_pressed)
	view_leaderboard_button.pressed.connect(_on_view_leaderboard_button_pressed)
	return_to_menu_button.pressed.connect(_on_return_to_menu_button_pressed)
	# 禁止按钮获得焦点，避免空格/回车误触
	next_level_button.focus_mode = Control.FOCUS_NONE
	replay_level_button.focus_mode = Control.FOCUS_NONE
	view_leaderboard_button.focus_mode = Control.FOCUS_NONE
	return_to_menu_button.focus_mode = Control.FOCUS_NONE

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
	%LeaderboardTypeScore.focus_mode = Control.FOCUS_NONE
	%LeaderboardTypeSpeedrun.focus_mode = Control.FOCUS_NONE
	%ExportLeaderboardButton.focus_mode = Control.FOCUS_NONE
	%ShareLeaderboardButton.focus_mode = Control.FOCUS_NONE

	# 连击数变化时刷新连击显示（含超时自动清零）
	score_manager.combo_changed.connect(func(_count: int) -> void: _update_combo_display())

	# 加载持久化设置
	_load_settings()

	# 设置分数标签的缩放中心，便于加分动画
	score_label.resized.connect(_on_score_label_resized)
	_on_score_label_resized()

	# 初始化飘字动画 Tween 池
	_score_popup_tweens.resize(score_popups.size())
	for i in range(_score_popup_tweens.size()):
		_score_popup_tweens[i] = null

	# 初始化右键双击洗牌的判定计时器
	_right_click_timer = Timer.new()
	_right_click_timer.one_shot = true
	_right_click_timer.wait_time = RIGHT_CLICK_DOUBLE_INTERVAL
	_right_click_timer.timeout.connect(_on_right_click_timer_timeout)
	add_child(_right_click_timer)


# 最终关卡胜利
func _update_level_info() -> void:
	var difficulty_name := "初级"
	match current_difficulty:
		2: difficulty_name = "中级"
		3: difficulty_name = "高级"
	var level_total := 5 if current_difficulty == 1 else 10
	difficulty_label.text = "[color=#8C5C33]难度：[/color][color=#264D61]%s[/color]" % difficulty_name

	match current_mode:
		GameMode.CHALLENGE:
			level_label.text = "[color=#8C5C33]倒计时模式[/color]"
		GameMode.ENDLESS:
			level_label.text = "[color=#8C5C33]无尽模式[/color]"
		GameMode.DAILY:
			level_label.text = "[color=#8C5C33]每日挑战：[/color][color=#264D61]%s[/color]" % _get_level_name(current_level)
		_:
			level_label.text = "[color=#8C5C33]关卡 %d/%d：[/color][color=#264D61]%s[/color]" % [current_level, level_total, _get_level_name(current_level)]
	_update_pairs_label()


# 刷新剩余对数显示
func _update_pairs_label() -> void:
	remaining_pairs_label.text = "[color=#8C5C33]剩余：[/color][color=#264D61]%d[/color]" % board_manager.pairs_left


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
	# 根据剩余时间给予关卡完成奖励
	score_manager.add_level_completion_bonus()
	_update_score_label()
	_update_compact_ui()

	# 记录本关统计
	_commit_level_stat()

	# 播放胜利音效
	audio_manager.play_sound(AudioManager.GAME_WON_SOUND)
	_show_full_ui()
	if current_mode == GameMode.CHALLENGE:
		# 倒计时模式：清空棋盘后立即生成新棋盘，继续计时刷分
		board_manager.generate_board()
		board_manager.update_all_cells(selected_index)
		_update_pairs_label()
		_update_ui()
		return
	if _is_final_level():
		# 最终关卡胜利时播放烟花庆祝
		var fireworks := FIREWORKS_SCENE.instantiate()
		add_child(fireworks)
		_show_final_victory()
	else:
		_show_level_complete_dialog()


# 记录当前关卡统计并重置计数器
func _commit_level_stat() -> void:
	_session_level_stats.append({
		"level": current_level,
		"time_seconds": score_manager.level_time,
		"hints": _level_hints_used,
		"shuffles": _level_shuffles_used,
	})
	_level_hints_used = 0
	_level_shuffles_used = 0


func _show_final_victory() -> void:
	game_state = GameState.GAME_OVER
	_timer_running = false
	# 用背景音乐播放器播放通关庆祝音乐，避免覆盖胜利音效
	audio_manager.stop_bgm()
	audio_manager.play_bgm(AudioManager.LEVEL_COMPLETE_MUSIC)
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


# 显示最终胜利面板
func _display_final_victory_label() -> void:
	var diff_name := "初级" if current_difficulty == 1 else ("中级" if current_difficulty == 2 else "高级")
	game_over_label.text = "%s通关成功！" % diff_name
	game_over_stats_label.text = "[color=#FFF8F0]总分：[/color][color=#E07A82]%d[/color]\n[color=#FFF8F0]总用时：[/color][color=#5AB4E0]%s[/color]" % [score_manager.score, ScoreManager.format_time(score_manager.total_game_time)]
	next_level_button.text = "再玩一次"
	next_level_button.show()
	replay_level_button.show()
	view_leaderboard_button.show()
	return_to_menu_button.show()
	game_over_panel.show()


# 模块：排行榜 —— 加载本地排行榜数据
func _load_leaderboard() -> void:
	if not FileAccess.file_exists(LEADERBOARD_FILE):
		_leaderboard_data = {"1": {"score": [], "speedrun": []}, "2": {"score": [], "speedrun": []}, "3": {"score": [], "speedrun": []}}
		return
	var file := FileAccess.open(LEADERBOARD_FILE, FileAccess.READ)
	if file == null:
		_leaderboard_data = {"1": {"score": [], "speedrun": []}, "2": {"score": [], "speedrun": []}, "3": {"score": [], "speedrun": []}}
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		_leaderboard_data = {"1": {"score": [], "speedrun": []}, "2": {"score": [], "speedrun": []}, "3": {"score": [], "speedrun": []}}
		return
	var data = json.data
	if data is Dictionary:
		_leaderboard_data = data
		# 兼容旧格式：值为数组时自动转换为 {score: 旧数组, speedrun: []}
		for key in _leaderboard_data.keys():
			var value = _leaderboard_data[key]
			if value is Array:
				_leaderboard_data[key] = {"score": value, "speedrun": []}
			elif value is Dictionary:
				if not value.has("score") or not (value["score"] is Array):
					value["score"] = []
				if not value.has("speedrun") or not (value["speedrun"] is Array):
					value["speedrun"] = []
	else:
		_leaderboard_data = {"1": {"score": [], "speedrun": []}, "2": {"score": [], "speedrun": []}, "3": {"score": [], "speedrun": []}}


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
	if not _leaderboard_data.has(key) or not (_leaderboard_data[key] is Dictionary):
		_leaderboard_data[key] = {"score": [], "speedrun": []}
	var diff_data: Dictionary = _leaderboard_data[key]
	if not diff_data.has("score") or not (diff_data["score"] is Array):
		diff_data["score"] = []
	if not diff_data.has("speedrun") or not (diff_data["speedrun"] is Array):
		diff_data["speedrun"] = []

	var date_dict := Time.get_datetime_dict_from_system()
	var date_str := "%04d-%02d-%02d %02d:%02d" % [date_dict.year, date_dict.month, date_dict.day, date_dict.hour, date_dict.minute]
	var entry := {
		"name": player_name,
		"date": date_str,
		"time": ScoreManager.format_time(score_manager.total_game_time),
		"time_seconds": int(score_manager.total_game_time),
		"score": score_manager.score,
		"levels": _session_level_stats.duplicate(true)
	}

	# 总分榜：分数降序 -> 用时升序 -> 日期降序
	var score_entries: Array = diff_data["score"]
	score_entries.append(entry.duplicate(true))
	score_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		if a["time_seconds"] != b["time_seconds"]:
			return a["time_seconds"] < b["time_seconds"]
		return a["date"] > b["date"]
	)
	if score_entries.size() > LEADERBOARD_MAX_ENTRIES:
		score_entries.resize(LEADERBOARD_MAX_ENTRIES)

	# 速通榜：总用时升序 -> 分数降序 -> 日期降序
	var speedrun_entries: Array = diff_data["speedrun"]
	speedrun_entries.append(entry.duplicate(true))
	speedrun_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["time_seconds"] != b["time_seconds"]:
			return a["time_seconds"] < b["time_seconds"]
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return a["date"] > b["date"]
	)
	if speedrun_entries.size() > LEADERBOARD_MAX_ENTRIES:
		speedrun_entries.resize(LEADERBOARD_MAX_ENTRIES)


# 模块：排行榜 —— 格式化指定难度、榜单类型与页码的排行榜字符串
func _get_leaderboard_page_text(difficulty: int, page: int, board_type: LeaderboardType = LeaderboardType.SCORE) -> String:
	var key := str(difficulty)
	var diff_data = _leaderboard_data.get(key, {"score": [], "speedrun": []})
	if not (diff_data is Dictionary):
		diff_data = {"score": [], "speedrun": []}
	var board_key := "score" if board_type == LeaderboardType.SCORE else "speedrun"
	var raw_entries = diff_data.get(board_key, [])
	var entries: Array = raw_entries if raw_entries is Array else []
	var diff_name := "初级" if difficulty == 1 else ("中级" if difficulty == 2 else "高级")
	var type_name := "总分榜" if board_type == LeaderboardType.SCORE else "速通榜"
	var content := "[center][color=#E0B45A][b]%s（%d 关）—— %s[/b][/color][/center]\n\n" % [diff_name, _get_max_level_for_difficulty(difficulty), type_name]
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
	if board_type == LeaderboardType.SCORE:
		table += "[cell][color=%s][b]用时[/b][/color][/cell]" % HEADER_COLOR
		table += "[cell][color=%s][b]分数[/b][/color][/cell]" % HEADER_COLOR
	else:
		table += "[cell][color=%s][b]总用时[/b][/color][/cell]" % HEADER_COLOR
		table += "[cell][color=%s][b]分数[/b][/color][/cell]" % HEADER_COLOR
	for i in range(start_index, end_index):
		var entry: Dictionary = entries[i]
		table += "[cell]%d[/cell][cell]%s[/cell][cell]%s[/cell][cell]%s[/cell][cell]%d[/cell]" % [i + 1, entry["name"], entry["date"], entry["time"], entry["score"]]
	table += "[/table][/center]\n"
	content += table

	# 每关明细：用时 / 提示 / 洗牌
	for i in range(start_index, end_index):
		var entry: Dictionary = entries[i]
		if entry.has("levels"):
			var details := _format_level_details(entry["levels"])
			if not details.is_empty():
				content += "\n[center][font_size=22][color=#B0B0B0]%d. %s[/color][/font_size][/center]" % [i + 1, details]

	return content


# 将每关明细格式化为 "关1 0:12·0·0 | 关2 0:09·1·0 | ..."
func _format_level_details(levels: Array) -> String:
	var parts: Array[String] = []
	for level_data in levels:
		if level_data is Dictionary:
			var level_num: int = level_data.get("level", 0)
			var time_sec: float = level_data.get("time_seconds", 0.0)
			var hints: int = level_data.get("hints", 0)
			var shuffles: int = level_data.get("shuffles", 0)
			parts.append("关%d %s·%d·%d" % [level_num, ScoreManager.format_time(time_sec), hints, shuffles])
	return " | ".join(parts)


# 模块：排行榜 —— 显示带标签页与分页的排行榜弹窗
func _show_leaderboard_dialog() -> void:
	_leaderboard_difficulty = 1
	_leaderboard_page = 0
	_leaderboard_type = LeaderboardType.SCORE
	_update_leaderboard_view()
	_show_custom_dialog(DialogType.LEADERBOARD, "排行榜", "")


# 模块：排行榜 —— 刷新当前难度/榜单类型/页码的视图与按钮状态
func _update_leaderboard_view() -> void:
	var key := str(_leaderboard_difficulty)
	var diff_data = _leaderboard_data.get(key, {"score": [], "speedrun": []})
	if not (diff_data is Dictionary):
		diff_data = {"score": [], "speedrun": []}
	var board_key := "score" if _leaderboard_type == LeaderboardType.SCORE else "speedrun"
	var raw_entries = diff_data.get(board_key, [])
	var entries: Array = raw_entries if raw_entries is Array else []
	var total_pages := maxi(1, ceili(float(entries.size()) / LEADERBOARD_ENTRIES_PER_PAGE))
	_leaderboard_page = clampi(_leaderboard_page, 0, total_pages - 1)

	leaderboard_content.text = _get_leaderboard_page_text(_leaderboard_difficulty, _leaderboard_page, _leaderboard_type)
	leaderboard_page_label.text = "第 %d 页 / 共 %d 页" % [_leaderboard_page + 1, total_pages]

	for i in range(leaderboard_tab_buttons.size()):
		leaderboard_tab_buttons[i].disabled = (i + 1 == _leaderboard_difficulty)

	leaderboard_type_score_button.disabled = (_leaderboard_type == LeaderboardType.SCORE)
	leaderboard_type_speedrun_button.disabled = (_leaderboard_type == LeaderboardType.SPEEDRUN)

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
	var diff_data = _leaderboard_data.get(key, {"score": [], "speedrun": []})
	if not (diff_data is Dictionary):
		diff_data = {"score": [], "speedrun": []}
	var board_key := "score" if _leaderboard_type == LeaderboardType.SCORE else "speedrun"
	var raw_entries = diff_data.get(board_key, [])
	var entries: Array = raw_entries if raw_entries is Array else []
	var total_pages := maxi(1, ceili(float(entries.size()) / LEADERBOARD_ENTRIES_PER_PAGE))
	if _leaderboard_page < total_pages - 1:
		_leaderboard_page += 1
		_update_leaderboard_view()


# 模块：排行榜 —— 切换总分榜 / 速通榜
func _on_leaderboard_type_pressed(type: LeaderboardType) -> void:
	if _leaderboard_type == type:
		return
	_leaderboard_type = type
	_leaderboard_page = 0
	_update_leaderboard_view()


# 模块：排行榜 —— 获取当前榜单的记录数组
func _get_current_leaderboard_entries() -> Array:
	var key := str(_leaderboard_difficulty)
	var diff_data = _leaderboard_data.get(key, {"score": [], "speedrun": []})
	if not (diff_data is Dictionary):
		return []
	var board_key := "score" if _leaderboard_type == LeaderboardType.SCORE else "speedrun"
	var raw_entries = diff_data.get(board_key, [])
	return raw_entries if raw_entries is Array else []


# 模块：排行榜 —— 导出榜单到文件并复制到剪贴板
func _on_export_leaderboard_pressed() -> void:
	var entries := _get_current_leaderboard_entries()
	var diff_name := "初级" if _leaderboard_difficulty == 1 else ("中级" if _leaderboard_difficulty == 2 else "高级")
	var type_name := "总分榜" if _leaderboard_type == LeaderboardType.SCORE else "速通榜"

	var lines: Array[String] = []
	lines.append("连连看排行榜 — %s — %s" % [diff_name, type_name])
	lines.append("")
	lines.append("排名\t姓名\t日期\t\t用时\t分数")
	if entries.is_empty():
		lines.append("暂无记录")
	else:
		for i in range(entries.size()):
			var entry: Dictionary = entries[i]
			lines.append("%d\t%s\t%s\t%s\t%d" % [i + 1, entry["name"], entry["date"], entry["time"], entry["score"]])
			if entry.has("levels"):
				lines.append("  每关明细: %s" % _format_level_details(entry["levels"]))

	var full_text := "\n".join(lines)

	# 复制到剪贴板
	DisplayServer.clipboard_set(full_text)

	# 同时写入用户目录文件
	var date_dict := Time.get_datetime_dict_from_system()
	var timestamp := "%04d%02d%02d_%02d%02d" % [date_dict.year, date_dict.month, date_dict.day, date_dict.hour, date_dict.minute]
	var file_name := "leaderboard_export_%s_%s_%s.txt" % [diff_name, type_name, timestamp]
	var file_path := "user://" + file_name
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(full_text)
		file.close()

	# 用临时提示标签反馈结果
	_show_toast("榜单已导出并复制到剪贴板\n文件：%s" % file_path)


# 模块：排行榜 —— 分享当前榜单的第一条记录到剪贴板
func _on_share_leaderboard_pressed() -> void:
	var entries := _get_current_leaderboard_entries()
	if entries.is_empty():
		_show_toast("当前榜单暂无记录")
		return

	var entry: Dictionary = entries[0]
	var diff_name := "初级" if _leaderboard_difficulty == 1 else ("中级" if _leaderboard_difficulty == 2 else "高级")
	var type_name := "总分榜" if _leaderboard_type == LeaderboardType.SCORE else "速通榜"
	var share_text := "【连连看 %s %s 第1名】\n玩家：%s\n分数：%d\n用时：%s\n日期：%s" % [diff_name, type_name, entry["name"], entry["score"], entry["time"], entry["date"]]
	if entry.has("levels"):
		share_text += "\n每关明细：%s" % _format_level_details(entry["levels"])
	DisplayServer.clipboard_set(share_text)
	_show_toast("已复制榜首成绩到剪贴板")


# 在屏幕中央显示一个临时提示（toast）
func _show_toast(message: String) -> void:
	var toast := Label.new()
	toast.text = message
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.add_theme_font_override("font", chinese_font)
	toast.add_theme_font_size_override("font_size", 28)
	toast.add_theme_color_override("font_outline_color", Color.BLACK)
	toast.add_theme_constant_override("outline_size", 5)
	toast.anchors_preset = Control.PRESET_CENTER
	toast.offset_left = -300
	toast.offset_top = -60
	toast.offset_right = 300
	toast.offset_bottom = 60
	add_child(toast)

	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 0.0, 2.0).set_delay(0.5)
	tween.finished.connect(func() -> void:
		toast.queue_free()
	)


# 获取指定难度下的最大关卡数
func _get_max_level_for_difficulty(difficulty: int) -> int:
	return 5 if difficulty == 1 else 10


# 获取今日日期对应的 Seed（用于每日挑战）
func _get_daily_seed() -> int:
	var date := Time.get_date_dict_from_system()
	return date.year * 10000 + date.month * 100 + date.day


# 显示欢迎弹窗
func _show_welcome_dialog() -> void:
	var rule_text := "[center][color=#E0B45A][font_size=28][b]【游戏规则】[/b][/font_size][/color]\n\n"
	rule_text += "[color=#FFF8F0][font_size=22]点击两个 [color=#E08787]相同图案[/color] 的格子，\n"
	rule_text += "若能用不超过 [color=#66ff66][b]2 个转弯[/b][/color] 的直线连接，则消除。\n"
	rule_text += "消除所有图案即可获胜。[/font_size][/color][/center]"

	var must_read_text := "[center][color=#8B0000][font_size=30]【必看】[/font_size][/color]\n\n"
	must_read_text += "[color=#660000][font_size=22]本游戏含”休闲、竞技、倒计时、无尽、每日挑战“\n五种模式；[/font_size][/color]\n"
	must_read_text += "[color=#8B0000][font_size=24]鼠标双击暂停；右键单击提示，右键双击洗牌。[/font_size][/color][/center]"

	var op_text := "[center][color=#E0B45A][font_size=28][b]【操作说明】[/b][/font_size][/color]\n\n"
	op_text += "[color=#FFF8F0][font_size=22][color=#5AB4E0][b]T / 鼠标右键单击[/b][/color]：提示\n"
	op_text += "[color=#5AB4E0][b]X / 鼠标右键双击[/b][/color]：洗牌\n"
	op_text += "[color=#5AB4E0][b]双击 / 空格键 [/b][/color]：暂停 / 继续\n"
	op_text += "[color=#5AB4E0][b]鼠标左键[/b][/color]：选择 / 消除[/font_size][/color][/center]"

	welcome_rule_label.text = rule_text
	welcome_must_read_label.text = must_read_text
	welcome_op_label.text = op_text
	_show_custom_dialog(DialogType.WELCOME, "欢迎游玩连连看", "", "(点击任意位置或按任意键开始)")
	welcome_panel.show()
	dialog_content.hide()
	_flash_dialog_hint()


# 普通关卡完成面板
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
	game_over_label.text = "关卡完成"
	game_over_stats_label.text = "[color=#FFF8F0]第 %d 关已完成\n下一关：[/color][color=#66ff66]%s[/color]\n[color=#FFF8F0]分数：[/color][color=#E07A82]%d[/color]\n[color=#FFF8F0]本关用时：[/color][color=#5AB4E0]%s[/color]" % [current_level, next_name, score_manager.score, ScoreManager.format_time(score_manager.level_time)]
	next_level_button.text = "下一关"
	next_level_button.show()
	replay_level_button.show()
	view_leaderboard_button.show()
	return_to_menu_button.show()
	game_over_panel.show()


# 进入下一关
func _on_level_complete_confirmed() -> void:
	if _pending_next_level < 0:
		return
	current_level = _pending_next_level
	_pending_next_level = -1
	_update_level_info()
	restart_game(false)


# 游戏结束/关卡完成面板：下一关 / 再玩一次
func _on_next_level_button_pressed() -> void:
	game_over_panel.hide()
	if _is_final_level() or _pending_next_level < 0:
		# 最终通关后“再玩一次”：从第 1 关重新开始
		restart_game(true)
	else:
		_on_level_complete_confirmed()


# 游戏结束/关卡完成面板：重玩本关
func _on_replay_level_button_pressed() -> void:
	game_over_panel.hide()
	restart_game(false)


# 游戏结束/关卡完成面板：查看排行榜
func _on_view_leaderboard_button_pressed() -> void:
	_return_to_game_over_panel = true
	game_over_panel.hide()
	_show_leaderboard_dialog()


# 游戏结束/关卡完成面板：返回主菜单（显示欢迎弹窗）
func _on_return_to_menu_button_pressed() -> void:
	game_over_panel.hide()
	restart_game(true)
	_show_welcome_dialog()


# 模块：设置 —— 从文件加载音量与开关状态
func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE):
		_apply_settings_to_ui()
		audio_manager.configure(master_volume, sfx_volume, bgm_volume, sound_effects_enabled, background_music_enabled)
		return
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if file == null:
		_apply_settings_to_ui()
		audio_manager.configure(master_volume, sfx_volume, bgm_volume, sound_effects_enabled, background_music_enabled)
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		_apply_settings_to_ui()
		audio_manager.configure(master_volume, sfx_volume, bgm_volume, sound_effects_enabled, background_music_enabled)
		return
	var data = json.data
	if data is Dictionary:
		master_volume = clampf(data.get("master_volume", master_volume), 0.0, 1.0)
		sfx_volume = clampf(data.get("sfx_volume", sfx_volume), 0.0, 1.0)
		bgm_volume = clampf(data.get("bgm_volume", bgm_volume), 0.0, 1.0)
		sound_effects_enabled = data.get("sound_effects_enabled", sound_effects_enabled)
		background_music_enabled = data.get("background_music_enabled", background_music_enabled)
	_apply_settings_to_ui()
	audio_manager.configure(master_volume, sfx_volume, bgm_volume, sound_effects_enabled, background_music_enabled)


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
	audio_manager.set_volumes(master_volume, sfx_volume, bgm_volume)
	_save_settings()


# 模块：设置 —— 音效音量滑块变化
func _on_sfx_volume_slider_changed(value: float) -> void:
	sfx_volume = value
	sfx_value_label.text = "%d%%" % int(value * 100)
	audio_manager.set_volumes(master_volume, sfx_volume, bgm_volume)
	_save_settings()


# 模块：设置 —— 背景音乐音量滑块变化
func _on_bgm_volume_slider_changed(value: float) -> void:
	bgm_volume = value
	bgm_value_label.text = "%d%%" % int(value * 100)
	audio_manager.set_volumes(master_volume, sfx_volume, bgm_volume)
	_save_settings()


# 模块：设置 —— 音效开关变化
func _on_sfx_mute_toggled(pressed: bool) -> void:
	sound_effects_enabled = pressed
	audio_manager.set_sfx_enabled(sound_effects_enabled)
	_save_settings()


# 模块：设置 —— 背景音乐开关变化
func _on_bgm_mute_toggled(pressed: bool) -> void:
	background_music_enabled = pressed
	audio_manager.set_bgm_enabled(background_music_enabled)
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


# 模块：菜单栏 —— 配置游戏、选项、帮助三个下拉菜单
func _setup_menus() -> void:
	var game_popup := game_menu.get_popup()

	# 模式子菜单放在最上方
	var mode_popup := PopupMenu.new()
	mode_popup.name = "ModeMenu"
	mode_popup.add_check_item("休闲模式", 0)
	mode_popup.add_check_item("竞技模式", 1)
	mode_popup.add_check_item("倒计时模式", 2)
	mode_popup.add_check_item("无尽模式", 3)
	mode_popup.add_check_item("每日挑战", 4)
	mode_popup.index_pressed.connect(_on_mode_menu_item_pressed)
	game_popup.add_child(mode_popup)
	game_popup.add_submenu_item("模式", "ModeMenu", 0)
	game_popup.add_separator()

	game_popup.add_item("初级", 1)
	game_popup.add_item("中级", 2)
	game_popup.add_item("高级", 3)

	var level_popup := PopupMenu.new()
	level_popup.name = "LevelMenu"
	for i in range(1, 11):
		level_popup.add_item("第 %d 关 %s" % [i, LEVEL_NAMES.get(i, "")], i - 1)
	level_popup.index_pressed.connect(_on_level_menu_item_pressed)
	game_popup.add_child(level_popup)
	game_popup.add_submenu_item("选择关卡", "LevelMenu", 4)

	game_popup.index_pressed.connect(_on_game_menu_item_pressed)
	_update_mode_menu_check()

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
	help_popup.add_item("模式说明", 4)
	help_popup.add_item("快捷键说明", 2)
	help_popup.add_item("积分规则", 3)
	help_popup.add_item("关于", 1)
	help_popup.index_pressed.connect(_on_help_menu_item_pressed)

	var skin_popup := skin_menu.get_popup()
	skin_popup.add_check_item("新版宝可梦", 0)
	skin_popup.add_check_item("经典图案", 1)
	skin_popup.index_pressed.connect(_on_skin_menu_item_pressed)
	_update_skin_menu_check()

	# 记录所有弹出菜单，供顶部 UI 自动隐藏时判断是否在菜单交互区域
	_popup_menus.assign([
		game_popup,
		mode_popup,
		level_popup,
		options_popup,
		master_volume_popup,
		sfx_volume_popup,
		bgm_volume_popup,
		help_popup,
		skin_popup,
	])


# 判断鼠标是否位于菜单栏、菜单栏小标签或任意已打开的弹出菜单上
func _is_mouse_over_menu() -> bool:
	var mouse_pos := get_global_mouse_position()

	# 菜单栏区域
	if menu_bar.get_global_rect().has_point(mouse_pos):
		return true

	# 隐藏时露出的菜单栏小标签
	if menu_bar_tab.visible and menu_bar_tab.get_global_rect().has_point(mouse_pos):
		return true

	# 任意弹出菜单可见时保持完整 UI（Godot 4 中 PopupMenu 继承 Window，无 get_global_rect）
	for popup in _popup_menus:
		if popup == null:
			continue
		if popup.visible:
			return true

	return false


# 处理游戏菜单：切换难度并重新开始
func _on_game_menu_item_pressed(index: int) -> void:
	# 菜单顺序：模式子菜单(0)、分隔线(1)、初级(2)、中级(3)、高级(4)、选择关卡子菜单(5)
	current_difficulty = index - 1
	Cell.set_level(current_difficulty)
	Cell.clear_texture_cache()
	board_manager.setup_grid(_on_cell_clicked)
	restart_game()


# 处理模式选择子菜单
func _on_mode_menu_item_pressed(index: int) -> void:
	match index:
		0: current_mode = GameMode.CASUAL
		1: current_mode = GameMode.COMPETITIVE
		2: current_mode = GameMode.CHALLENGE
		3: current_mode = GameMode.ENDLESS
		4: current_mode = GameMode.DAILY
	_update_mode_menu_check()
	match current_mode:
		GameMode.CASUAL:
			_show_casual_intro_dialog()
		GameMode.COMPETITIVE:
			_show_competitive_intro_dialog()
		GameMode.CHALLENGE:
			_show_challenge_intro_dialog()
		GameMode.ENDLESS:
			_show_endless_intro_dialog()
		GameMode.DAILY:
			_show_daily_intro_dialog()


# 显示挑战模式介绍弹窗，关闭后再开始游戏
func _show_challenge_intro_dialog() -> void:
	var content := "[center]\n\n"
	content += "[color=#FFF8F0][font_size=24]• 固定 [color=#E07A82][b]2 分钟[/b][/color] 倒计时[/font_size][/color]\n"
	content += "[color=#FFF8F0][font_size=24]• 消除 [color=#E07A82][b]不会恢复[/b][/color] 时间[/font_size][/color]\n"
	content += "[color=#FFF8F0][font_size=24]• 清空后立即生成 [color=#66ff66][b]新棋盘[/b][/color]，无限续关[/font_size][/color]\n"
	content += "[color=#FFF8F0][font_size=24]• 目标：在限制时间内挑战获得高分！[/font_size][/color][/center]"
	_show_custom_dialog(DialogType.RULES, "挑战模式", content, "(点击任意位置或按任意键开始)", restart_game)


# 显示无尽模式介绍弹窗，关闭后再开始游戏
func _show_endless_intro_dialog() -> void:
	var content := "[center]\n\n"
	content += "[color=#FFF8F0][font_size=24]• 每消除一对，上方会 [color=#66ff66][b]下落新牌[/b][/color] 补充空位[/font_size][/color]\n"
	content += "[color=#FFF8F0][font_size=24]• 棋盘 [color=#66ff66][b]始终充满[/b][/color]，不会出现死局[/font_size][/color]\n"
	content += "[color=#FFF8F0][font_size=24]• 倒计时耗尽即结束[/font_size][/color]\n"
	content += "[color=#FFF8F0][font_size=24]• 目标：在倒计时结束前挑战最高分！[/font_size][/color][/center]"
	_show_custom_dialog(DialogType.RULES, "无尽模式", content, "(点击任意位置或按任意键开始)", restart_game)


# 显示每日挑战模式介绍弹窗，关闭后再开始游戏
func _show_daily_intro_dialog() -> void:
	var content := "[center]\n\n"
	content += "[color=#FFF8F0][font_size=24]• 使用 [color=#5AB4E0][b]当日日期[/b][/color] 作为固定 Seed[/font_size][/color]\n"
	content += "[color=#FFF8F0][font_size=24]• 所有玩家当天面对 [color=#5AB4E0][b]完全相同[/b][/color] 的棋盘[/font_size][/color]\n"
	content += "[color=#FFF8F0][font_size=24]• 通关后可比拼分数与用时[/font_size][/color]\n"
	content += "[color=#FFF8F0][font_size=24]• 每天只有一次机会，尽情挑战吧！[/font_size][/color][/center]"
	_show_custom_dialog(DialogType.RULES, "每日挑战", content, "(点击任意位置或按任意键开始)", restart_game)


# 显示休闲模式介绍弹窗，关闭后再开始游戏
func _show_casual_intro_dialog() -> void:
	var content := "[center]\n\n"
	content += "[color=#FFF8F0][font_size=24]• 提示与洗牌 [color=#66ff66][b]无限使用[/b][/color][/font_size][/color]\n"
	content += "[color=#FFF8F0][font_size=24]• 无分数压力，轻松练习[/font_size][/color]\n"
	content += "[color=#FFF8F0][font_size=24]• 适合熟悉规则与图案[/font_size][/color]\n"
	content += "[color=#FFF8F0][font_size=24]• 尽情享受消除乐趣！[/font_size][/color][/center]"
	_show_custom_dialog(DialogType.RULES, "休闲模式", content, "(点击任意位置或按任意键开始)", restart_game)


# 显示竞技模式介绍弹窗，关闭后再开始游戏
func _show_competitive_intro_dialog() -> void:
	var content := "[center]\n\n"
	content += "[color=#FFF8F0][font_size=24]• 每关提示与洗牌次数 [color=#E07A82][b]有限[/b][/color][/font_size][/color]\n"
	content += "[color=#FFF8F0][font_size=24]• 第 1–7 关：5 次提示、2 次洗牌[/font_size][/color]\n"
	content += "[color=#FFF8F0][font_size=24]• 第 8–10 关：8 次提示、3 次洗牌[/font_size][/color]\n"
	content += "[color=#FFF8F0][font_size=24]• 次数用尽后对应按钮变灰，谨慎使用！[/font_size][/color][/center]"
	_show_custom_dialog(DialogType.RULES, "竞技模式", content, "(点击任意位置或按任意键开始)", restart_game)


# 更新模式菜单勾选状态
func _update_mode_menu_check() -> void:
	var mode_popup := game_menu.get_popup().get_node("ModeMenu") as PopupMenu
	mode_popup.set_item_checked(0, current_mode == GameMode.CASUAL)
	mode_popup.set_item_checked(1, current_mode == GameMode.COMPETITIVE)
	mode_popup.set_item_checked(2, current_mode == GameMode.CHALLENGE)
	mode_popup.set_item_checked(3, current_mode == GameMode.ENDLESS)
	mode_popup.set_item_checked(4, current_mode == GameMode.DAILY)


# 处理关卡选择子菜单
func _on_level_menu_item_pressed(index: int) -> void:
	current_level = index + 1
	# 若选择超出初级上限，自动提升到中级以便测试
	if current_level > 5 and current_difficulty == 1:
		current_difficulty = 2
	# 难度变化时重新设置棋盘网格
	Cell.set_level(current_difficulty)
	Cell.clear_texture_cache()
	board_manager.setup_grid(_on_cell_clicked)
	# 跳转到指定关卡，重置本局分数与时间，但保留选中的关卡编号
	score_manager.reset(true)
	restart_game(false)


# 处理选项菜单：音效、背景音乐、排行榜
func _on_options_menu_item_pressed(index: int) -> void:
	var popup := options_menu.get_popup()
	match index:
		0:
			sound_effects_enabled = not sound_effects_enabled
			popup.set_item_checked(0, sound_effects_enabled)
			audio_manager.set_sfx_enabled(sound_effects_enabled)
			_apply_settings_to_ui()
			_save_settings()
		1:
			background_music_enabled = not background_music_enabled
			popup.set_item_checked(1, background_music_enabled)
			audio_manager.set_bgm_enabled(background_music_enabled)
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
	audio_manager.set_volumes(master_volume, sfx_volume, bgm_volume)
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
	audio_manager.set_volumes(master_volume, sfx_volume, bgm_volume)
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
	audio_manager.set_volumes(master_volume, sfx_volume, bgm_volume)
	_apply_settings_to_ui()
	_save_settings()


# 处理帮助菜单：打开连连看规则、模式说明、快捷键说明、积分规则或关于弹窗
# 注意：菜单项按当前显示顺序（连连看规则、模式说明、快捷键说明、积分规则、关于）处理
func _on_help_menu_item_pressed(index: int) -> void:
	match index:
		0:
			var rules := "点击两个相同图案的格子。\n若能用不超过 2 个转弯的直线连接，则消除。\n消除所有图案即可获胜。\n\n提示：路径可以经过棋盘外圈的虚拟空白区域。"
			_show_custom_dialog(DialogType.RULES, "连连看规则", rules)
		1:
			var mode_rules := "[table=2]"
			mode_rules += "[cell padding=0,0,30,0]"
			mode_rules += "[color=#5AB4E0][b]休闲模式[/b][/color]\n"
			mode_rules += "提示与洗牌无限使用，无分数压力，适合轻松练习。"
			mode_rules += "[/cell]"
			mode_rules += "[cell padding=30,0,0,0]"
			mode_rules += "[color=#5AB4E0][b]无尽模式[/b][/color]\n"
			mode_rules += "每消除一对，上方会下落新牌补充空位，棋盘始终充满。在倒计时结束前挑战自己的最高分数。"
			mode_rules += "[/cell]"
			mode_rules += "[cell padding=0,0,30,0]"
			mode_rules += "[color=#5AB4E0][b]竞技模式[/b][/color]\n"
			mode_rules += "每关提示与洗牌次数有限：\n"
			mode_rules += "• 第 1–7 关：5 次提示、2 次洗牌\n"
			mode_rules += "• 第 8–10 关：8 次提示、3 次洗牌\n"
			mode_rules += "次数用尽后对应按钮变灰。"
			mode_rules += "[/cell]"
			mode_rules += "[cell padding=30,0,0,0]"
			mode_rules += "[color=#5AB4E0][b]每日挑战[/b][/color]\n"
			mode_rules += "使用当日日期作为固定 Seed，所有玩家当天面对完全相同的棋盘，通关后可比拼分数与用时。"
			mode_rules += "[/cell]"
			mode_rules += "[cell padding=0,0,30,0]"
			mode_rules += "[color=#5AB4E0][b]倒计时模式[/b][/color]\n"
			mode_rules += "固定 [color=#E07A82]2 分钟[/color] 倒计时，消除不会恢复时间。清空棋盘后立即生成新棋盘继续刷分。"
			mode_rules += "[/cell]"
			mode_rules += "[cell][/cell]"
			mode_rules += "[/table]"
			_show_custom_dialog(DialogType.MODE_RULES, "模式说明", mode_rules)
		2:
			var shortcuts := "T / 鼠标右键单击：提示（高亮显示一对可连通的图案）\nX / 鼠标右键双击：洗牌（重新排列剩余图案）\n 鼠标左键快速双击 / 空格键：暂停 / 继续游戏\n鼠标左键：点击选择或消除图案"
			_show_custom_dialog(DialogType.SHORTCUTS, "快捷键说明", shortcuts)
		3:
			var score_rules := "每次消除得分 = 速度基础分 × 棋盘大小系数 × 难度系数 × 关卡系数 × 连击系数\n\n"
			score_rules += "[color=#E0B45A]速度基础分[/color]（两次消除间隔）：\n"
			score_rules += "3 秒内：30 分 | 5 秒内：20 分 | 10 秒内：15 分 | 20 秒内：12 分 | 超过 20 秒：10 分\n\n"
			score_rules += "[color=#E0B45A]棋盘大小系数[/color]：当前对数 ÷ 42（以 7×12 为基准）\n"
			score_rules += "[color=#E0B45A]难度系数[/color]：初级 1.0 | 中级 1.3 | 高级 1.6\n"
			score_rules += "[color=#E0B45A]关卡系数[/color]：1 + (关卡 - 1) × 0.15\n"
			score_rules += "[color=#E0B45A]连击系数[/color]：1 + (连击数 - 1) × 0.2\n\n"
			score_rules += "[color=#E0B45A]额外规则[/color]：\n"
			score_rules += "关卡完成奖励 = 剩余时间 × 3 × 难度系数 × 关卡系数\n"
			score_rules += "使用提示扣分 = 30 × 难度系数 × 关卡系数\n"
			score_rules += "使用洗牌扣分 = 80 × 难度系数 × 关卡系数"
			_show_custom_dialog(DialogType.SCORE_RULES, "积分规则", score_rules)
		4:
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
	board_manager.setup_grid(_on_cell_clicked)
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


# 显示自定义弹窗（居中的欢迎面板样式）
func _show_custom_dialog(type: DialogType, title: String, content: String, hint: String = "点击任意位置或按任意键继续", callback: Callable = Callable()) -> void:
	_current_dialog_type = type
	_dialog_callback = callback
	dialog_title.text = title

	if type == DialogType.LEADERBOARD:
		dialog_content.hide()
		dialog_hint.hide()
		leaderboard_panel.show()
		welcome_panel.hide()
	elif type == DialogType.WELCOME:
		dialog_content.hide()
		dialog_hint.show()
		dialog_hint.text = hint
		dialog_hint.modulate = Color.WHITE
		leaderboard_panel.hide()
		welcome_panel.show()
	else:
		dialog_content.show()
		dialog_content.text = content
		# 模式说明使用两列表格并带较大内边距，需要更宽的弹窗才不易裁切
		dialog_content.custom_minimum_size.x = 1600 if type == DialogType.MODE_RULES else 1200
		dialog_hint.show()
		dialog_hint.text = hint
		dialog_hint.modulate = Color.WHITE
		leaderboard_panel.hide()
		welcome_panel.hide()

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
	welcome_panel.hide()
	_set_paused(false)
	match _current_dialog_type:
		DialogType.LEVEL_COMPLETE:
			_on_level_complete_confirmed()
	if _dialog_callback.is_valid():
		_dialog_callback.call()
	_dialog_callback = Callable()

	# 若从游戏结束面板打开排行榜，关闭后返回游戏结束面板
	if _return_to_game_over_panel:
		_return_to_game_over_panel = false
		game_over_panel.show()


# 右键单击延迟到期后执行提示
func _on_right_click_timer_timeout() -> void:
	_on_hint_button_pressed()


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
				# 左键点击时取消待触发的右键提示，避免与正常选牌冲突
				if event.pressed and _right_click_timer != null and not _right_click_timer.is_stopped():
					_right_click_timer.stop()
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					# 右键双击：洗牌；右键单击：延迟触发提示
					if _right_click_timer != null and not _right_click_timer.is_stopped():
						_right_click_timer.stop()
						_on_shuffle_button_pressed()
					else:
						_right_click_timer.start()
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
	var can_hint := current_mode == GameMode.CASUAL or hints_remaining > 0
	var can_shuffle := current_mode == GameMode.CASUAL or shuffles_remaining > 0
	hint_button.disabled = paused or not can_hint
	shuffle_button.disabled = paused or not can_shuffle
	_update_timer_bar()


# 模块：游戏流程 —— 倒计时、胜负判定
func _process(delta: float) -> void:
	if _is_paused or not _timer_running or game_state != GameState.PLAYING:
		return

	var time_up := score_manager.update(delta)

	_update_timer_bar()
	_update_time_labels()
	_update_ui_visibility(delta)

	if time_up:
		_timer_running = false
		_on_time_up()


# 时间耗尽：显示结束面板并播放失败音效
func _on_time_up() -> void:
	game_state = GameState.GAME_OVER
	if current_mode == GameMode.CHALLENGE:
		# 倒计时模式：区分“倒计时条耗尽”与“两分钟总时长到限”两种失败描述
		if score_manager.time_up_reason == ScoreManager.TimeUpReason.DURATION_LIMIT:
			game_over_label.text = "挑战时间到"
			game_over_stats_label.text = "[color=#FFF8F0]两分钟挑战已结束\n最终得分：[/color][color=#E07A82]%d[/color]" % score_manager.score
		else:
			game_over_label.text = "时间耗尽"
			game_over_stats_label.text = "[color=#FFF8F0]倒计时已见底，挑战失败\n最终得分：[/color][color=#E07A82]%d[/color]" % score_manager.score
		next_level_button.text = "再玩一次"
		next_level_button.show()
	else:
		game_over_label.text = "时间结束"
		game_over_stats_label.text = "[color=#FFF8F0]欢迎游玩，下次再接再厉！\n分数：[/color][color=#E07A82]%d[/color]" % score_manager.score
		next_level_button.hide()
	replay_level_button.show()
	view_leaderboard_button.show()
	return_to_menu_button.show()
	game_over_panel.show()
	audio_manager.play_sound(AudioManager.GAME_OVER_SOUND)
	_show_full_ui()


# 顶部 UI 自动隐藏/显示：游戏开始 5 秒后进入紧凑模式，鼠标移到屏幕顶部恢复完整 UI
func _update_ui_visibility(delta: float) -> void:
	if game_state != GameState.PLAYING or _is_paused:
		return

	var mouse_y := get_global_mouse_position().y
	if mouse_y <= TOP_TRIGGER_HEIGHT or _is_mouse_over_menu():
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
	menu_bar_tab.show()
	_update_compact_ui()


# 恢复完整顶部 UI（菜单栏、信息栏、工具栏）
func _show_full_ui() -> void:
	_ui_hidden = false
	_top_leave_time = 0.0
	menu_bar.show()
	info_bar.show()
	toolbar.show()
	compact_top_bar.hide()
	menu_bar_tab.hide()


# 刷新紧凑顶部 UI 的倒计时条、本关用时与分数
func _update_compact_ui() -> void:
	compact_timer_bar.max_value = score_manager.max_time
	compact_timer_bar.value = score_manager.remaining_time
	if current_mode == GameMode.CHALLENGE:
		compact_time_label.text = "[color=#8C5C33]倒计时：[/color][color=#FFF8F0]%s[/color]" % ScoreManager.format_time(score_manager.remaining_time)
	else:
		compact_time_label.text = "[color=#8C5C33]本关用时：[/color][color=#FFF8F0]%s[/color]" % ScoreManager.format_time(score_manager.level_time)
	compact_score_label.text = "[color=#8C5C33]分数：[/color][color=#E07A82]%d[/color]" % score_manager.score


# 游戏开始 5 秒后尝试切换到紧凑 UI；若鼠标正在屏幕顶部或菜单区域则保持完整 UI
func _on_ui_hide_timer_timeout() -> void:
	if game_state != GameState.PLAYING or _is_paused:
		return
	if get_global_mouse_position().y <= TOP_TRIGGER_HEIGHT or _is_mouse_over_menu():
		return
	_show_compact_ui()


# 重置游戏状态、棋盘与倒计时
func restart_game(reset_progress: bool = true) -> void:
	if reset_progress:
		current_level = 1

	# 模式特定初始化
	match current_mode:
		GameMode.CHALLENGE:
			score_manager.max_time = ScoreManager.CHALLENGE_TIME
			score_manager.time_bonus_enabled = false
			score_manager.duration_limited = true
			board_manager.randomize_seed()
			if reset_progress:
				current_level = 1
		GameMode.ENDLESS:
			score_manager.max_time = ScoreManager.MAX_TIME
			score_manager.time_bonus_enabled = true
			score_manager.duration_limited = false
			board_manager.randomize_seed()
			current_level = 1
		GameMode.DAILY:
			score_manager.max_time = ScoreManager.MAX_TIME
			score_manager.time_bonus_enabled = true
			score_manager.duration_limited = false
			board_manager.set_seed(_get_daily_seed() + current_level)
		_:
			score_manager.max_time = ScoreManager.MAX_TIME
			score_manager.time_bonus_enabled = true
			score_manager.duration_limited = false
			board_manager.randomize_seed()

	if current_level > _get_max_level():
		current_level = 1

	game_state = GameState.PLAYING
	game_over_panel.hide()
	custom_dialog.hide()
	welcome_panel.hide()
	selected_index = -1
	_timer_running = true
	move_history.clear()
	undo_history.clear()
	_pending_next_level = -1
	_ui_hidden = false
	_top_leave_time = 0.0

	score_manager.reset(reset_progress)
	if reset_progress:
		_session_level_stats.clear()
	_level_hints_used = 0
	_level_shuffles_used = 0
	board_manager.generate_board()
	score_manager.setup_level(board_manager.get_rows(), board_manager.get_cols(), current_level, current_difficulty)

	# 根据当前模式设置提示与洗牌次数
	if current_mode == GameMode.COMPETITIVE:
		if current_level <= COMPETITIVE_EARLY_LEVELS:
			hints_remaining = COMPETITIVE_EARLY_HINTS
			shuffles_remaining = COMPETITIVE_EARLY_SHUFFLES
		else:
			hints_remaining = COMPETITIVE_LATE_HINTS
			shuffles_remaining = COMPETITIVE_LATE_SHUFFLES
	else:
		hints_remaining = 0
		shuffles_remaining = 0

	# 每次重新开始后恢复完整 UI，并在 5 秒后尝试自动隐藏
	_show_full_ui()
	ui_hide_timer.stop()
	ui_hide_timer.start(AUTO_HIDE_DELAY)

	if current_level == 2:
		_roll_level2_direction()
	if current_level == 4:
		_roll_level4_direction()

	board_manager.update_all_cells(selected_index)
	_update_ui()
	_update_timer_bar()
	_set_paused(false)
	_update_level_info()
	_update_time_labels()
	_update_score_label()
	audio_manager.play_random_bgm()
	print("game started!")


# 同步倒计时进度条的最大值与当前值，并按剩余比例切换红/橙/绿渐变，最后 10 秒触发脉冲闪烁
func _update_timer_bar() -> void:
	timer_bar.max_value = score_manager.max_time
	timer_bar.value = score_manager.remaining_time
	compact_timer_bar.max_value = score_manager.max_time
	compact_timer_bar.value = score_manager.remaining_time

	# 根据剩余时间比例切换进度条渐变颜色
	var ratio := score_manager.remaining_time / score_manager.max_time
	if ratio < 0.3:
		_timer_gradient.colors = PackedColorArray([
			Color(0.88, 0.12, 0.12),
			Color(0.98, 0.22, 0.18),
			Color(1.0, 0.28, 0.22),
		])
	elif ratio < 0.5:
		_timer_gradient.colors = PackedColorArray([
			Color(0.92, 0.48, 0.06),
			Color(1.0, 0.62, 0.12),
			Color(0.96, 0.55, 0.08),
		])
	else:
		_timer_gradient.colors = PackedColorArray([
			Color(0.12, 0.68, 0.36),
			Color(0.2, 0.8, 0.42),
			Color(0.16, 0.74, 0.38),
		])

	var should_pulse := score_manager.remaining_time <= 10.0 and score_manager.remaining_time > 0.0 \
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


# 刷新时间显示
func _update_time_labels() -> void:
	if current_mode == GameMode.CHALLENGE:
		var countdown_text := ScoreManager.format_time(score_manager.remaining_time)
		time_label.text = "[color=#8C5C33]倒计时：[/color][color=#FFF8F0]%s[/color]" % countdown_text
		compact_time_label.text = "[color=#8C5C33]倒计时：[/color][color=#FFF8F0]%s[/color]" % countdown_text
	else:
		time_label.text = "[color=#8C5C33]总用时：[/color][color=#FFF8F0]%s[/color] | [color=#8C5C33]本关用时：[/color][color=#FFF8F0]%s[/color]" % [ScoreManager.format_time(score_manager.total_game_time), ScoreManager.format_time(score_manager.level_time)]
		compact_time_label.text = "[color=#8C5C33]本关用时：[/color][color=#FFF8F0]%s[/color]" % ScoreManager.format_time(score_manager.level_time)


# 刷新分数显示
func _update_score_label() -> void:
	score_label.text = "[color=#8C5C33]分数：[/color][color=#E07A82]%d[/color]" % score_manager.score
	compact_score_label.text = "[color=#8C5C33]分数：[/color][color=#E07A82]%d[/color]" % score_manager.score


# 分数标签大小变化时同步缩放中心
func _on_score_label_resized() -> void:
	score_label.pivot_offset = score_label.size / 2.0


func _emphasize_score_label(time_since_last: float = -1.0) -> void:
	var tier_color := ScoreManager.get_score_tier_color(time_since_last)

	# 根据当前显示模式，脉冲对应的分数标签
	var visible_score_label: RichTextLabel = score_label if score_label.visible else compact_score_label
	visible_score_label.pivot_offset = visible_score_label.size / 2.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(visible_score_label, "scale", Vector2(1.4, 1.4), 0.12)
	tween.tween_property(visible_score_label, "modulate", tier_color, 0.12)

	var tween_back := create_tween()
	tween_back.tween_property(visible_score_label, "scale", Vector2(1.0, 1.0), 0.18).set_delay(0.12)
	tween_back.tween_property(visible_score_label, "modulate", Color(1, 1, 1), 0.18).set_delay(0.12)


# 显示加分反馈：方案 1（消除位置飘字）+ 方案 2（分数标签旁弹出 + 标签脉冲）
func _show_score_feedback(points: int, time_since_last: float, match_midpoint: Vector2) -> void:
	# 方案 1：在消除位置飘出带等级色的分数
	if SCHEME_1_FLOATING_TEXT_ENABLED:
		_spawn_floating_score(points, time_since_last, match_midpoint)

	# 方案 2：在可见的分数标签旁弹出“+N”，同时分数标签脉冲变色
	var color_hex := ScoreManager.SCORE_COLOR_NORMAL
	if time_since_last < 0:
		color_hex = ScoreManager.SCORE_COLOR_NORMAL
	elif time_since_last <= 3.0:
		color_hex = ScoreManager.SCORE_COLOR_GOLD
	elif time_since_last <= 5.0:
		color_hex = ScoreManager.SCORE_COLOR_SILVER
	elif time_since_last <= 10.0:
		color_hex = ScoreManager.SCORE_COLOR_BRONZE
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

	# 同时让分数标签脉冲变色（函数当前未被外部单独调用，保留备用）
	_emphasize_score_label(time_since_last)


# 方案 1：在指定位置生成向上飘动并逐渐消失的分数飘字（连击快时自动延长停留）
func _spawn_floating_score(points: int, time_since_last: float, pos: Vector2) -> void:
	var idx := _score_popup_index
	var popup: Label = score_popups[idx]
	_score_popup_index = (_score_popup_index + 1) % score_popups.size()

	# 若该飘字实例仍在动画中，先终止旧动画
	if _score_popup_tweens[idx] != null:
		_score_popup_tweens[idx].kill()
		_score_popup_tweens[idx] = null

	popup.text = "+%d" % points
	popup.modulate = ScoreManager.get_score_tier_color(time_since_last)
	popup.global_position = pos - popup.size / 2.0
	popup.show()

	# 连击越高，飘字停留越久（整体都比原来减短 0.3 秒）：
	# 0-1 连击：停留 0.0 秒 + 淡出 0.7 秒
	# 2-3 连击：停留 0.3 秒 + 淡出 0.9 秒
	# 4+ 连击：停留 0.7 秒 + 淡出 1.0 秒
	var combo := score_manager.get_combo_count()
	var linger_time := 0.0
	var fade_time := 0.7
	if combo >= 4:
		linger_time = 0.7
		fade_time = 1.0
	elif combo >= 2:
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
	var combo := score_manager.get_combo_count()
	if combo > 1:
		text = "[color=%s][b]连击 x%d[/b][/color]" % [ScoreManager.SCORE_COLOR_GOLD, combo]
	combo_label.text = text
	compact_combo_label.text = text


# 模块：消除逻辑 —— 处理格子点击、选中、判断并执行消除
func _on_cell_clicked(index: int) -> void:
	if game_state != GameState.PLAYING:
		return
	if _is_paused or _is_animating:
		return

	var pos := board_manager.index_to_pos(index)
	var r := pos.x
	var c := pos.y
	if board_manager.board[r][c] == 0:
		return

	# 第一次点击：选中
	if selected_index == -1:
		selected_index = index
		board_manager.update_all_cells(selected_index)
		audio_manager.play_sound(AudioManager.CLICK_SOUND)
		return

	# 点击同一个格子：取消选中
	if selected_index == index:
		selected_index = -1
		board_manager.update_all_cells(selected_index)
		return

	var pos1 := board_manager.index_to_pos(selected_index)
	var r1 := pos1.x
	var c1 := pos1.y

	# 图案不同：改选新格子（错误音效）
	if board_manager.board[r][c] != board_manager.board[r1][c1]:
		selected_index = index
		board_manager.update_all_cells(selected_index)
		audio_manager.play_sound(AudioManager.ERROR_SOUND)
		return

	# 无法连通：改选新格子（错误音效）
	if not board_manager.can_connect(r1, c1, r, c):
		selected_index = index
		board_manager.update_all_cells(selected_index)
		audio_manager.play_sound(AudioManager.ERROR_SOUND)
		return

	# 可以消除：先绘制连接路径，再播放消除动画，然后更新棋盘数据
	var path: Array[Vector2i] = board_manager.find_connection_path(r1, c1, r, c)
	var points: PackedVector2Array = PackedVector2Array()
	for ext_pos in path:
		points.append(board_manager.extended_to_screen(ext_pos))
	match_line.points = points

	var cell1: Cell = grid_container.get_child(selected_index)
	var cell2: Cell = grid_container.get_child(index)
	_is_animating = true
	selected_index = -1
	board_manager.update_all_cells(selected_index)

	var tween1 := cell1.play_eliminate_animation()
	var tween2 := cell2.play_eliminate_animation()
	if tween1 != null:
		await tween1.finished
	if tween2 != null:
		await tween2.finished

	# 动画结束后立即把两个格子设为空白，彻底移除残影并同步状态
	cell1.tile_type = 0
	cell2.tile_type = 0
	match_line.points = PackedVector2Array()

	# 动画结束后才真正消除并计分
	var time_since_last: float = _eliminate(r1, c1, r, c)

	# 方案 1/2：显示加分反馈（方案 1 可通过 SCHEME_1_FLOATING_TEXT_ENABLED 单独关闭）
	# 飘字显示在第二次点击的格子中心
	var popup_pos: Vector2 = cell2.global_position + cell2.size / 2.0
	_show_score_feedback(score_manager.get_last_points(), time_since_last, popup_pos)

	var collapse_tween := board_manager.apply_collapse(current_level, _level2_direction, _level4_direction)
	if collapse_tween != null:
		await collapse_tween.finished

	# 无尽模式：坍塌后上方下落新牌，保持棋盘始终充满
	if current_mode == GameMode.ENDLESS:
		board_manager.drop_tiles(board_manager.get_skin_tile_count())

	board_manager.update_all_cells(selected_index)
	_update_ui()
	_is_animating = false

	if time_since_last > 10.0:
		audio_manager.play_sound(AudioManager.SUCCESS_SLOW_SOUND)
	else:
		audio_manager.play_sound(AudioManager.SUCCESS_SOUND)

	if board_manager.pairs_left == 0:
		_on_level_complete()
	elif not board_manager.has_any_match():
		await _auto_shuffle_with_feedback()


# 消除两个格子，并奖励额外时间；返回距离上次消除的秒数
func _eliminate(r1: int, c1: int, r2: int, c2: int) -> float:
	# 记录消除前的完整棋盘与分数/时间状态，用于撤销/重做
	var move := {
		"board_state": board_manager.get_state(),
		"score_state": score_manager.get_state(),
		"level_before": current_level,
	}
	move_history.append(move)
	undo_history.clear()

	board_manager.eliminate(r1, c1, r2, c2)
	var result := score_manager.record_elimination()

	_update_pairs_label()
	_update_score_label()
	_update_timer_bar()

	return result["time_since_last"]


# 模块：撤销 / 重做 —— 撤销上一步消除
func _on_undo_button_pressed() -> void:
	if current_mode == GameMode.COMPETITIVE or move_history.is_empty() or _is_paused or _is_animating:
		return

	var last: Dictionary = move_history.pop_back()

	# 保存当前状态用于重做
	var redo_move := {
		"board_state": board_manager.get_state(),
		"score_state": score_manager.get_state(),
		"level_before": current_level,
	}
	undo_history.append(redo_move)

	# 恢复到消除前的棋盘状态
	board_manager.restore_state(last["board_state"])
	score_manager.restore_state(last["score_state"])
	score_manager.reset_combo()
	current_level = last["level_before"]
	selected_index = -1
	game_state = GameState.PLAYING
	game_over_panel.hide()
	_pending_next_level = -1
	custom_dialog.hide()
	welcome_panel.hide()
	board_manager.update_all_cells(selected_index)
	_update_ui()
	_update_level_info()
	_update_time_labels()
	_update_score_label()


# 模块：撤销 / 重做 —— 重做一步被撤销的消除
func _on_redo_button_pressed() -> void:
	if current_mode == GameMode.COMPETITIVE or undo_history.is_empty() or _is_paused or _is_animating:
		return

	var redo: Dictionary = undo_history.pop_back()

	# 保存当前状态用于撤销
	var move := {
		"board_state": board_manager.get_state(),
		"score_state": score_manager.get_state(),
		"level_before": current_level,
	}
	move_history.append(move)

	# 恢复重做时的棋盘状态
	board_manager.restore_state(redo["board_state"])
	score_manager.restore_state(redo["score_state"])
	score_manager.reset_combo()
	current_level = redo["level_before"]
	selected_index = -1
	board_manager.update_all_cells(selected_index)
	_update_ui()
	_update_level_info()
	_update_time_labels()
	_update_score_label()

	if board_manager.pairs_left == 0:
		_on_level_complete()
	elif not board_manager.has_any_match():
		await _auto_shuffle_with_feedback()


# 模块：提示与洗牌 —— 高亮一对可连通的图案并画线
func _on_hint_button_pressed() -> void:
	if game_state != GameState.PLAYING or _hint_active or _is_paused or _is_animating:
		return

	if current_mode == GameMode.COMPETITIVE and hints_remaining <= 0:
		return

	# 取消待触发的右键单击提示，避免与 T 键/按钮重复触发
	if _right_click_timer != null and not _right_click_timer.is_stopped():
		_right_click_timer.stop()

	var path: Array[Vector2i] = board_manager.find_hint_pair()
	if path.is_empty():
		return

	if current_mode == GameMode.COMPETITIVE:
		hints_remaining -= 1
		_update_button_texts()
		_update_ui()

	# 记录本关提示次数（所有模式都统计，便于排行榜展示）
	_level_hints_used += 1

	# 提示扣分（休闲模式也扣，保证排行榜可比性）
	score_manager.apply_hint_penalty()
	_update_score_label()
	_update_compact_ui()

	_hint_active = true

	# 让两个目标格子的图片闪烁两下
	var start_ext: Vector2i = path[0]
	var end_ext: Vector2i = path[path.size() - 1]
	var start_board := Vector2i(start_ext.x - 1, start_ext.y - 1)
	var end_board := Vector2i(end_ext.x - 1, end_ext.y - 1)
	var start_cell: Cell = grid_container.get_child(board_manager.pos_to_index(start_board.x, start_board.y))
	var end_cell: Cell = grid_container.get_child(board_manager.pos_to_index(end_board.x, end_board.y))

	start_cell.flash()
	end_cell.flash()

	var line_points: PackedVector2Array = PackedVector2Array()
	for ext_pos in path:
		line_points.append(board_manager.extended_to_screen(ext_pos))

	hint_line.points = line_points
	await get_tree().create_timer(1.5).timeout
	hint_line.points = PackedVector2Array()
	_hint_active = false


# 模块：提示与洗牌 —— 手动重排剩余图案
func _on_shuffle_button_pressed() -> void:
	if game_state != GameState.PLAYING or _is_paused or _is_animating:
		return

	if current_mode == GameMode.COMPETITIVE and shuffles_remaining <= 0:
		return

	# 取消待触发的右键单击提示，避免与 X 键/按钮重复触发
	if _right_click_timer != null and not _right_click_timer.is_stopped():
		_right_click_timer.stop()

	if current_mode == GameMode.COMPETITIVE:
		shuffles_remaining -= 1
		_update_button_texts()

	# 记录本关洗牌次数（所有模式都统计，便于排行榜展示）
	_level_shuffles_used += 1

	# 洗牌扣分（休闲模式也扣，保证排行榜可比性）
	score_manager.apply_shuffle_penalty()
	_update_score_label()
	_update_compact_ui()

	audio_manager.play_sound(AudioManager.SHUFFLE_SOUND)
	board_manager.shuffle_remaining()
	selected_index = -1
	board_manager.update_all_cells(selected_index)
	_update_ui()


# 死局自动洗牌：带文字提示与缩放动画，避免玩家察觉不到
func _auto_shuffle_with_feedback() -> void:
	_is_animating = true
	var was_timer_running := _timer_running
	_timer_running = false
	auto_shuffle_hint.show()

	# 短暂停留让玩家读到提示
	await get_tree().create_timer(0.5).timeout

	var cells: Array[Cell] = []
	for i in range(board_manager.get_rows() * board_manager.get_cols()):
		var cell: Cell = grid_container.get_child(i)
		if cell.tile_type != 0:
			cells.append(cell)
			cell.pivot_offset = cell.size / 2.0

	# 缩放淡出，同时播放洗牌音效
	var fade_out := create_tween()
	fade_out.set_parallel(true)
	fade_out.set_trans(Tween.TRANS_LINEAR)
	audio_manager.play_sound(AudioManager.SHUFFLE_SOUND)
	for cell in cells:
		fade_out.tween_property(cell, "scale", Vector2(0.7, 0.7), 0.1)
		fade_out.tween_property(cell, "modulate:a", 0.3, 0.1)
	await fade_out.finished

	# 执行洗牌并刷新棋盘
	board_manager.shuffle_remaining()
	selected_index = -1
	board_manager.update_all_cells(selected_index)

	# 重新收集洗牌后的非空格子，设置为缩放淡入初始状态
	cells.clear()
	for i in range(board_manager.get_rows() * board_manager.get_cols()):
		var cell: Cell = grid_container.get_child(i)
		if cell.tile_type != 0:
			cells.append(cell)
			cell.pivot_offset = cell.size / 2.0
			cell.scale = Vector2(0.7, 0.7)
			cell.modulate.a = 0.3

	# 缩放淡入
	var fade_in := create_tween()
	fade_in.set_parallel(true)
	fade_in.set_trans(Tween.TRANS_LINEAR)
	for cell in cells:
		fade_in.tween_property(cell, "scale", Vector2.ONE, 0.15)
		fade_in.tween_property(cell, "modulate:a", 1.0, 0.15)
	await fade_in.finished

	auto_shuffle_hint.hide()
	_is_animating = false
	_timer_running = was_timer_running


# 重新开始本局（保留总分与总用时）
func _on_restart_button_pressed() -> void:
	if current_mode == GameMode.COMPETITIVE or _is_animating:
		return
	restart_game(false)


# 刷新按钮可用状态
func _update_ui() -> void:
	var is_casual := current_mode == GameMode.CASUAL
	# 回退、前进、重开仅在休闲模式可见与可用
	undo_button.visible = is_casual
	redo_button.visible = is_casual
	restart_button.visible = is_casual
	restart_button_2.visible = is_casual

	undo_button.disabled = move_history.is_empty()
	redo_button.disabled = undo_history.is_empty()
	# 竞技模式消耗次数；其余模式（含挑战/无尽/每日）不限制次数，仅扣分数
	var is_limited_mode := current_mode == GameMode.COMPETITIVE
	var can_hint := not is_limited_mode or hints_remaining > 0
	var can_shuffle := not is_limited_mode or shuffles_remaining > 0
	hint_button.disabled = not can_hint
	shuffle_button.disabled = not can_shuffle
	_update_mode_label()
	_update_button_texts()


# 刷新模式标签显示
func _update_mode_label() -> void:
	var mode_name: String
	match current_mode:
		GameMode.CASUAL: mode_name = "休闲"
		GameMode.COMPETITIVE: mode_name = "竞技"
		GameMode.CHALLENGE: mode_name = "挑战"
		GameMode.ENDLESS: mode_name = "无尽"
		GameMode.DAILY: mode_name = "每日"
	mode_label.text = "[color=#8C5C33]模式：[/color][color=#FFF8F0]%s[/color]" % mode_name


# 刷新提示与洗牌按钮文本（竞技模式显示剩余次数）
func _update_button_texts() -> void:
	if current_mode == GameMode.COMPETITIVE:
		hint_button.text = "💡 提示(%d)" % hints_remaining
		shuffle_button.text = "🔀 洗牌(%d)" % shuffles_remaining
	else:
		hint_button.text = "💡 提示"
		shuffle_button.text = "🔀 洗牌"
