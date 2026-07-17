extends Control

# 主游戏控制器：管理 UI 交互、菜单、弹窗、游戏流程与三个 Manager 的协作。

enum GameState {PLAYING, GAME_OVER}
enum GameMode {CASUAL, COMPETITIVE}

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

# 顶部 UI 自动隐藏相关常量
const AUTO_HIDE_DELAY := 5.0          # 游戏开始后多久自动隐藏顶部 UI
const TOP_TRIGGER_HEIGHT := 24.0      # 鼠标移到屏幕顶部多少像素内触发显示
const TOP_HIDE_DELAY := 1.5           # 鼠标离开顶部后多久恢复紧凑 UI

# 加分反馈相关常量
const SCHEME_1_FLOATING_TEXT_ENABLED := true  # 方案 1：消除位置飘字（可独立开关）
const AUTO_HIDE_HINT_MAX := 1           # 每局游戏最多显示几次恢复提示

# 自定义弹窗类型与回调
enum DialogType {WELCOME, RULES, ABOUT, SHORTCUTS, SCORE_RULES, MODE_RULES, LEVEL_COMPLETE, LEADERBOARD, NAME_INPUT}
var _current_dialog_type: DialogType = DialogType.WELCOME
var _dialog_callback: Callable = Callable()

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
var _auto_hide_hint_count: int = 0
var _hint_flash_tween: Tween = null

# 鼠标按键状态（用于左右键同时按下的洗牌快捷键）
var _left_mouse_pressed: bool = false
var _right_mouse_pressed: bool = false
var _left_press_time: int = 0
var _right_press_time: int = 0
const MOUSE_COMBO_WINDOW_MS := 150

# 当前难度：1=初级，2=中级，3=高级
var current_level: int = 1
var _level2_direction: Level2Dir = Level2Dir.LEFT
var _level4_direction: Level4Dir = Level4Dir.UP
var current_difficulty: int = 1

# 游戏模式与竞技模式剩余次数（休闲模式不消耗次数）
var current_mode: GameMode = GameMode.CASUAL
var hints_remaining: int = 0
var shuffles_remaining: int = 0

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
	# 为主题默认字体（NotoSerifSC）添加 Emoji 回退，确保按钮中的 emoji 正常显示
	var sc_font: FontFile = load("res://assets/fonts/NotoSerifSC-Regular.otf")
	if sc_font != null:
		sc_font.fallbacks = [EMOJI_FONT]

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
	# 播放胜利音效
	audio_manager.play_sound(AudioManager.GAME_WON_SOUND)
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


# 显示最终胜利标签
func _display_final_victory_label() -> void:
	if current_difficulty == 1:
		game_over_label.text = "初级通关！\n总分：%d\n总用时：%s" % [score_manager.score, ScoreManager.format_time(score_manager.total_game_time)]
	elif current_difficulty == 2:
		game_over_label.text = "中级通关！\n总分：%d\n总用时：%s" % [score_manager.score, ScoreManager.format_time(score_manager.total_game_time)]
	else:
		game_over_label.text = "高级通关！\n总分：%d\n总用时：%s" % [score_manager.score, ScoreManager.format_time(score_manager.total_game_time)]
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
		"time": ScoreManager.format_time(score_manager.total_game_time),
		"time_seconds": int(score_manager.total_game_time),
		"score": score_manager.score
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
	current_mode = GameMode.CASUAL if index == 0 else GameMode.COMPETITIVE
	_update_mode_menu_check()
	restart_game()


# 更新模式菜单勾选状态
func _update_mode_menu_check() -> void:
	var mode_popup := game_menu.get_popup().get_node("ModeMenu") as PopupMenu
	mode_popup.set_item_checked(0, current_mode == GameMode.CASUAL)
	mode_popup.set_item_checked(1, current_mode == GameMode.COMPETITIVE)


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
			var mode_rules := "【休闲模式】\n提示与洗牌可无限使用，适合轻松练习。\n\n【竞技模式】\n每关开始时分配固定次数的提示与洗牌：\n第 1–7 关：5 次提示、2 次洗牌\n第 8–10 关：8 次提示、3 次洗牌\n次数用尽后对应按钮将变灰且无法使用。"
			_show_custom_dialog(DialogType.MODE_RULES, "模式说明", mode_rules)
		2:
			var shortcuts := "T / 鼠标右键：提示（高亮显示一对可连通的图案）\nX / 鼠标左右键同时按下：洗牌（重新排列剩余图案）\n空格键 / 鼠标左键快速双击：暂停 / 继续游戏\n鼠标左键：点击选择或消除图案"
			_show_custom_dialog(DialogType.SHORTCUTS, "快捷键说明", shortcuts)
		3:
			var score_rules := "从上一次消除完成到下一次消除完成的时间间隔决定得分：\n3 秒内消除：30 分\n5 秒内消除：20 分\n10 秒内消除：15 分\n20 秒内消除：12 分\n超过 20 秒：10 分"
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


# 时间耗尽：显示结束语并播放失败音效
func _on_time_up() -> void:
	game_state = GameState.GAME_OVER
	game_over_label.text = "时间结束~欢迎游玩，下次再接再厉！"
	game_over_panel.show()
	audio_manager.play_sound(AudioManager.GAME_OVER_SOUND)
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
	compact_timer_bar.max_value = ScoreManager.MAX_TIME
	compact_timer_bar.value = score_manager.remaining_time
	compact_time_label.text = "[color=#8C5C33]本关用时：[/color][color=#FFF8F0]%s[/color]" % ScoreManager.format_time(score_manager.level_time)
	compact_score_label.text = "[color=#8C5C33]分数：[/color][color=#E07A82]%d[/color]" % score_manager.score


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
	_timer_running = true
	move_history.clear()
	undo_history.clear()
	_pending_next_level = -1
	_ui_hidden = false
	_top_leave_time = 0.0
	_auto_hide_hint_count = 0

	score_manager.reset(reset_progress)
	board_manager.generate_board()

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

	# 重置鼠标按键状态，避免跨关卡误触发左右键组合快捷键
	_left_mouse_pressed = false
	_right_mouse_pressed = false
	_left_press_time = 0
	_right_press_time = 0

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


# 同步倒计时进度条的最大值与当前值，最后 10 秒触发脉冲闪烁
func _update_timer_bar() -> void:
	timer_bar.max_value = ScoreManager.MAX_TIME
	timer_bar.value = score_manager.remaining_time
	compact_timer_bar.max_value = ScoreManager.MAX_TIME
	compact_timer_bar.value = score_manager.remaining_time

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
	time_label.text = "[color=#8C5C33]总用时：[/color][color=#FFF8F0]%s[/color] | [color=#8C5C33]本关用时：[/color][color=#FFF8F0]%s[/color]" % [ScoreManager.format_time(score_manager.total_game_time), ScoreManager.format_time(score_manager.level_time)]
	compact_time_label.text = "[color=#8C5C33]本关用时：[/color][color=#FFF8F0]%s[/color]" % ScoreManager.format_time(score_manager.level_time)


# 刷新分数显示
func _update_score_label() -> void:
	score_label.text = "[color=#8C5C33]分数：[/color][color=#E07A82]%d[/color]" % score_manager.score
	compact_score_label.text = "[color=#8C5C33]分数：[/color][color=#E07A82]%d[/color]" % score_manager.score


# 分数标签大小变化时同步缩放中心
func _on_score_label_resized() -> void:
	score_label.pivot_offset = score_label.size / 2.0


func _emphasize_score_label(points: int = 0) -> void:
	var tier_color := ScoreManager.get_score_tier_color(points)

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
func _show_score_feedback(points: int, match_midpoint: Vector2) -> void:
	# 方案 1：在消除位置飘出带等级色的分数
	if SCHEME_1_FLOATING_TEXT_ENABLED:
		_spawn_floating_score(points, match_midpoint)

	# 方案 2：在可见的分数标签旁弹出“+N”，同时分数标签脉冲变色
	var color_hex := ScoreManager.SCORE_COLOR_NORMAL
	match points:
		30: color_hex = ScoreManager.SCORE_COLOR_GOLD
		20: color_hex = ScoreManager.SCORE_COLOR_SILVER
		15: color_hex = ScoreManager.SCORE_COLOR_BRONZE
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
	popup.modulate = ScoreManager.get_score_tier_color(points)
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

	match_line.points = PackedVector2Array()

	# 动画结束后才真正消除并计分
	var time_since_last: float = _eliminate(r1, c1, r, c)

	# 方案 1/2：显示加分反馈（方案 1 可通过 SCHEME_1_FLOATING_TEXT_ENABLED 单独关闭）
	# 飘字显示在第二次点击的格子中心
	var popup_pos: Vector2 = cell2.global_position + cell2.size / 2.0
	_show_score_feedback(score_manager.get_last_points(), popup_pos)

	board_manager.apply_collapse(current_level, _level2_direction, _level4_direction)
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
		board_manager.shuffle_remaining()
		board_manager.update_all_cells(selected_index)


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
	if move_history.is_empty() or _is_paused or _is_animating:
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
	board_manager.update_all_cells(selected_index)
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
		board_manager.shuffle_remaining()
		board_manager.update_all_cells(selected_index)


# 模块：提示与洗牌 —— 高亮一对可连通的图案并画线
func _on_hint_button_pressed() -> void:
	if game_state != GameState.PLAYING or _hint_active or _is_paused or _is_animating:
		return

	if current_mode == GameMode.COMPETITIVE and hints_remaining <= 0:
		return

	var path: Array[Vector2i] = board_manager.find_hint_pair()
	if path.is_empty():
		return

	if current_mode == GameMode.COMPETITIVE:
		hints_remaining -= 1
		_update_button_texts()
		_update_ui()

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

	if current_mode == GameMode.COMPETITIVE:
		shuffles_remaining -= 1
		_update_button_texts()

	board_manager.shuffle_remaining()
	selected_index = -1
	board_manager.update_all_cells(selected_index)
	_update_ui()


# 重新开始本局（保留总分与总用时）
func _on_restart_button_pressed() -> void:
	if _is_animating:
		return
	restart_game(false)


# 刷新按钮可用状态
func _update_ui() -> void:
	undo_button.disabled = move_history.is_empty()
	redo_button.disabled = undo_history.is_empty()
	var can_hint := current_mode == GameMode.CASUAL or hints_remaining > 0
	var can_shuffle := current_mode == GameMode.CASUAL or shuffles_remaining > 0
	hint_button.disabled = not can_hint
	shuffle_button.disabled = not can_shuffle
	_update_mode_label()
	_update_button_texts()


# 刷新模式标签显示
func _update_mode_label() -> void:
	var mode_name := "休闲" if current_mode == GameMode.CASUAL else "竞技"
	mode_label.text = "[color=#8C5C33]模式：[/color][color=#FFF8F0]%s[/color]" % mode_name


# 刷新提示与洗牌按钮文本（竞技模式显示剩余次数）
func _update_button_texts() -> void:
	if current_mode == GameMode.CASUAL:
		hint_button.text = "💡 提示"
		shuffle_button.text = "🔀 洗牌"
	else:
		hint_button.text = "💡 提示(%d)" % hints_remaining
		shuffle_button.text = "🔀 洗牌(%d)" % shuffles_remaining
