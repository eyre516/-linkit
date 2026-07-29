extends Node
class_name ScoreManager

# 计分与计时管理器：维护分数、倒计时、本关/总用时、连击数。

const MAX_TIME := 60.0
const CHALLENGE_TIME := 120.0            # 挑战模式固定 2 分钟
const TIME_BONUS := 15.0
const COMBO_FAST_THRESHOLD := 10.0
const SCORE_COLOR_GOLD := "#FFD700"
const SCORE_COLOR_SILVER := "#E0E0E0"
const SCORE_COLOR_BRONZE := "#FF8C00"
const SCORE_COLOR_NORMAL := "#FFFFFF"

# 新计分方案系数
const BASE_BOARD_PAIRS := 42.0           # 默认 7×12 棋盘的对数，用于标准化棋盘大小分
const DIFFICULTY_FACTOR_STEP := 0.3      # 每提升一级难度，分数增加 30%
const LEVEL_MULTIPLIER_STEP := 0.15      # 每提升一关，分数增加 15%
const COMBO_MULTIPLIER_STEP := 0.2       # 连击每增加 1，额外增加 20%
const HINT_PENALTY_BASE := 30            # 提示基础扣分
const SHUFFLE_PENALTY_BASE := 80         # 洗牌基础扣分
const TIME_BONUS_PER_SECOND := 3.0       # 关卡完成时每剩余 1 秒奖励的分数

enum TimeUpReason {
	TIME_DEPLETED,    # 倒计时条耗尽（remaining_time <= 0）
	DURATION_LIMIT,   # 达到模式总时长上限（level_time >= max_time）
}

# 运行时数据
var score: int = 0
var max_time: float = MAX_TIME           # 当前模式的最大时间（挑战模式为 120 秒）
var remaining_time: float = MAX_TIME
var total_game_time: float = 0.0
var level_time: float = 0.0
var time_bonus_enabled: bool = true      # 消除后是否增加时间（挑战模式为 false）
var duration_limited: bool = false       # 是否为固定总时长模式（仅挑战模式启用时长上限判定）

var _last_eliminate_time: float = -1.0
var _combo_count: int = 0
var _last_points: int = 0
var _time_up_triggered: bool = false
var time_up_reason: TimeUpReason = TimeUpReason.TIME_DEPLETED

# 当前关卡参数（用于计分）
var _rows: int = 0
var _cols: int = 0
var _level: int = 1
var _difficulty: int = 1
var _pairs: int = 0

signal score_changed(score: int, points: int, combo: int)
signal time_changed(total: float, level: float, remaining: float)
signal combo_changed(count: int)
signal time_up


# 重置为新一局/新关卡状态
func reset(new_game: bool = true) -> void:
	score = 0 if new_game else score
	remaining_time = max_time
	level_time = 0.0
	_last_eliminate_time = -1.0
	_combo_count = 0
	_last_points = 0
	_time_up_triggered = false
	time_up_reason = TimeUpReason.TIME_DEPLETED
	duration_limited = false
	if new_game:
		total_game_time = 0.0
		_rows = 0
		_cols = 0
		_level = 1
		_difficulty = 1
		_pairs = 0


# 设置当前关卡参数，用于后续计分
func setup_level(rows: int, cols: int, level: int, difficulty: int) -> void:
	_rows = rows
	_cols = cols
	_level = level
	_difficulty = difficulty
	_pairs = int(rows * cols / 2.0)


# 棋盘大小系数：对数越多，单步基础分越高
func _get_board_factor() -> float:
	return _pairs / BASE_BOARD_PAIRS


# 难度系数：初级 1.0，中级 1.3，高级 1.6
func _get_difficulty_factor() -> float:
	return 1.0 + (_difficulty - 1) * DIFFICULTY_FACTOR_STEP


# 关卡系数：每关递增 15%
func _get_level_multiplier() -> float:
	return 1.0 + (_level - 1) * LEVEL_MULTIPLIER_STEP


# 连击系数：连击 1 为 1.0，之后每多 1 连击增加 0.2
func _get_combo_multiplier(combo: int) -> float:
	return 1.0 + maxi(0, combo - 1) * COMBO_MULTIPLIER_STEP


# 每帧更新计时，返回是否已时间到
func update(delta: float) -> bool:
	if _time_up_triggered:
		return true

	remaining_time -= delta
	total_game_time += delta
	level_time += delta

	# 达到模式总时长上限（仅用于挑战模式等固定时长场景），优先于倒计时条耗尽
	if duration_limited and level_time >= max_time:
		remaining_time = maxf(0.0, remaining_time)
		_time_up_triggered = true
		time_up_reason = TimeUpReason.DURATION_LIMIT
		time_changed.emit(total_game_time, level_time, remaining_time)
		time_up.emit()
		return true

	if remaining_time <= 0.0:
		remaining_time = 0.0
		_time_up_triggered = true
		time_up_reason = TimeUpReason.TIME_DEPLETED
		time_changed.emit(total_game_time, level_time, remaining_time)
		time_up.emit()
		return true

	# 超过 10 秒未消除，连击清零
	if _last_eliminate_time >= 0 and (total_game_time - _last_eliminate_time) > COMBO_FAST_THRESHOLD:
		if _combo_count != 0:
			_combo_count = 0
			combo_changed.emit(0)

	time_changed.emit(total_game_time, level_time, remaining_time)
	return false


# 记录一次消除，返回 {points, time_since_last, combo, ...}
func record_elimination() -> Dictionary:
	var time_since_last: float
	if _last_eliminate_time < 0:
		time_since_last = -1.0
	else:
		time_since_last = total_game_time - _last_eliminate_time

	var speed_points: int
	if time_since_last < 0:
		speed_points = 10
	elif time_since_last <= 3.0:
		speed_points = 30
	elif time_since_last <= 5.0:
		speed_points = 20
	elif time_since_last <= 10.0:
		speed_points = 15
	elif time_since_last <= 20.0:
		speed_points = 12
	else:
		speed_points = 10

	# 更新连击计数：10 秒内消除连击 +1，否则从 1 开始新的连击
	if time_since_last >= 0 and time_since_last <= COMBO_FAST_THRESHOLD:
		_combo_count += 1
	else:
		_combo_count = 1

	var board_factor := _get_board_factor()
	var difficulty_factor := _get_difficulty_factor()
	var level_multiplier := _get_level_multiplier()
	var combo_multiplier := _get_combo_multiplier(_combo_count)

	var raw_points := speed_points * board_factor * difficulty_factor * level_multiplier * combo_multiplier
	var points := maxi(1, int(raw_points))

	score += points
	_last_points = points
	_last_eliminate_time = total_game_time

	if time_bonus_enabled:
		remaining_time = min(max_time, remaining_time + TIME_BONUS)

	score_changed.emit(score, points, _combo_count)
	combo_changed.emit(_combo_count)
	time_changed.emit(total_game_time, level_time, remaining_time)

	return {
		"points": points,
		"time_since_last": time_since_last,
		"combo": _combo_count,
		"board_factor": board_factor,
		"difficulty_factor": difficulty_factor,
		"level_multiplier": level_multiplier,
		"combo_multiplier": combo_multiplier,
	}


# 使用提示扣分
func apply_hint_penalty() -> int:
	var penalty := int(HINT_PENALTY_BASE * _get_difficulty_factor() * _get_level_multiplier())
	score = maxi(0, score - penalty)
	score_changed.emit(score, -penalty, _combo_count)
	return penalty


# 使用洗牌扣分
func apply_shuffle_penalty() -> int:
	var penalty := int(SHUFFLE_PENALTY_BASE * _get_difficulty_factor() * _get_level_multiplier())
	score = maxi(0, score - penalty)
	score_changed.emit(score, -penalty, _combo_count)
	return penalty


# 关卡完成时根据剩余时间给予奖励
func add_level_completion_bonus() -> int:
	var bonus := int(remaining_time * TIME_BONUS_PER_SECOND * _get_difficulty_factor() * _get_level_multiplier())
	score += bonus
	score_changed.emit(score, bonus, _combo_count)
	return bonus


# 撤销/重做时恢复计时与分数状态
func restore_state(state: Dictionary) -> void:
	score = state.get("score", score)
	max_time = state.get("max_time", max_time)
	time_bonus_enabled = state.get("time_bonus_enabled", time_bonus_enabled)
	duration_limited = state.get("duration_limited", duration_limited)
	total_game_time = state.get("total_game_time", total_game_time)
	level_time = state.get("level_time", level_time)
	remaining_time = state.get("remaining_time", remaining_time)
	_last_eliminate_time = state.get("last_eliminate_time", _last_eliminate_time)
	_combo_count = state.get("combo_count", _combo_count)
	_rows = state.get("rows", _rows)
	_cols = state.get("cols", _cols)
	_level = state.get("level", _level)
	_difficulty = state.get("difficulty", _difficulty)
	_pairs = state.get("pairs", _pairs)
	score_changed.emit(score, 0, _combo_count)
	combo_changed.emit(_combo_count)
	time_changed.emit(total_game_time, level_time, remaining_time)


# 获取当前状态字典，用于撤销/重做
func get_state() -> Dictionary:
	return {
		"score": score,
		"max_time": max_time,
		"time_bonus_enabled": time_bonus_enabled,
		"duration_limited": duration_limited,
		"total_game_time": total_game_time,
		"level_time": level_time,
		"remaining_time": remaining_time,
		"last_eliminate_time": _last_eliminate_time,
		"combo_count": _combo_count,
		"rows": _rows,
		"cols": _cols,
		"level": _level,
		"difficulty": _difficulty,
		"pairs": _pairs,
	}


# 获取最后一次消除得到的分数
func get_last_points() -> int:
	return _last_points


# 获取当前连击数
func get_combo_count() -> int:
	return _combo_count


# 强制重置连击数（用于撤销/重做后打断连击连续性）
func reset_combo() -> void:
	_combo_count = 0
	combo_changed.emit(0)


# 将秒数格式化为 MM:SS 或 HH:MM:SS
static func format_time(seconds: float) -> String:
	var total_secs := int(seconds)
	var hours := int(total_secs / 3600.0)
	var minutes := int((total_secs % 3600) / 60.0)
	var secs := total_secs % 60
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, secs]
	return "%02d:%02d" % [minutes, secs]


# 根据两次消除间隔返回对应等级颜色（分数受多种系数影响，按速度分级更稳定）
static func get_score_tier_color(time_since_last: float) -> Color:
	if time_since_last < 0:
		return Color(SCORE_COLOR_NORMAL)
	elif time_since_last <= 3.0:
		return Color(SCORE_COLOR_GOLD)
	elif time_since_last <= 5.0:
		return Color(SCORE_COLOR_SILVER)
	elif time_since_last <= 10.0:
		return Color(SCORE_COLOR_BRONZE)
	else:
		return Color(SCORE_COLOR_NORMAL)
