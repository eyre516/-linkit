extends Node
class_name ScoreManager

# 计分与计时管理器：维护分数、倒计时、本关/总用时、连击数。

const MAX_TIME := 60.0
const TIME_BONUS := 15.0
const COMBO_FAST_THRESHOLD := 10.0
const SCORE_COLOR_GOLD := "#FFD700"
const SCORE_COLOR_SILVER := "#E0E0E0"
const SCORE_COLOR_BRONZE := "#FF8C00"
const SCORE_COLOR_NORMAL := "#FFFFFF"

# 运行时数据
var score: int = 0
var remaining_time: float = MAX_TIME
var total_game_time: float = 0.0
var level_time: float = 0.0

var _last_eliminate_time: float = -1.0
var _combo_count: int = 0
var _last_points: int = 0
var _time_up_triggered: bool = false

signal score_changed(score: int, points: int, combo: int)
signal time_changed(total: float, level: float, remaining: float)
signal combo_changed(count: int)
signal time_up


# 重置为新一局/新关卡状态
func reset(new_game: bool = true) -> void:
	score = 0 if new_game else score
	remaining_time = MAX_TIME
	level_time = 0.0
	_last_eliminate_time = -1.0
	_combo_count = 0
	_last_points = 0
	_time_up_triggered = false
	if new_game:
		total_game_time = 0.0


# 每帧更新计时，返回是否已时间到
func update(delta: float) -> bool:
	if _time_up_triggered:
		return true

	remaining_time -= delta
	total_game_time += delta
	level_time += delta

	if remaining_time <= 0.0:
		remaining_time = 0.0
		_time_up_triggered = true
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


# 记录一次消除，返回 {points, time_since_last, combo}
func record_elimination() -> Dictionary:
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

	remaining_time = min(MAX_TIME, remaining_time + TIME_BONUS)

	score_changed.emit(score, points, _combo_count)
	combo_changed.emit(_combo_count)
	time_changed.emit(total_game_time, level_time, remaining_time)

	return {
		"points": points,
		"time_since_last": time_since_last,
		"combo": _combo_count,
	}


# 撤销/重做时恢复计时与分数状态
func restore_state(state: Dictionary) -> void:
	score = state.get("score", score)
	total_game_time = state.get("total_game_time", total_game_time)
	level_time = state.get("level_time", level_time)
	remaining_time = state.get("remaining_time", remaining_time)
	_last_eliminate_time = state.get("last_eliminate_time", _last_eliminate_time)
	_combo_count = state.get("combo_count", _combo_count)
	score_changed.emit(score, 0, _combo_count)
	combo_changed.emit(_combo_count)
	time_changed.emit(total_game_time, level_time, remaining_time)


# 获取当前状态字典，用于撤销/重做
func get_state() -> Dictionary:
	return {
		"score": score,
		"total_game_time": total_game_time,
		"level_time": level_time,
		"remaining_time": remaining_time,
		"last_eliminate_time": _last_eliminate_time,
		"combo_count": _combo_count,
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


# 根据分数返回对应等级颜色
static func get_score_tier_color(points: int) -> Color:
	match points:
		30:
			return Color(SCORE_COLOR_GOLD)
		20:
			return Color(SCORE_COLOR_SILVER)
		15:
			return Color(SCORE_COLOR_BRONZE)
		_:
			return Color(SCORE_COLOR_NORMAL)
