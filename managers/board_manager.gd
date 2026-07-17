extends Node
class_name BoardManager

# 棋盘管理器：负责棋盘尺寸、生成、洗牌、坍塌、路径查找与提示查找。

enum Level2Dir {LEFT, RIGHT}
enum Level4Dir {UP, DOWN}

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

const BOARD_SCALE := 0.95

# 运行时数据
var board: Array = []
var pairs_left: int = 0

var _grid_container: GridContainer = null
var _aspect_ratio_container: AspectRatioContainer = null
var _board_center: CenterContainer = null
var _cell_scene: PackedScene = null


# 初始化棋盘所需节点引用
func setup(grid_container: GridContainer, aspect_ratio_container: AspectRatioContainer, board_center: CenterContainer, cell_scene: PackedScene) -> void:
	_grid_container = grid_container
	_aspect_ratio_container = aspect_ratio_container
	_board_center = board_center
	_cell_scene = cell_scene
	_board_center.resized.connect(_on_grid_resized)


# 当前图版与难度下的行数
func get_rows(skin: Cell.TileSkin = Cell.current_skin, difficulty: int = Cell.current_level) -> int:
	match skin:
		Cell.TileSkin.CLASSIC:
			return CLASSIC_LEVELS[difficulty]["rows"]
		Cell.TileSkin.POKEMON:
			return POKEMON_LEVELS[difficulty]["rows"]
	return ROWS


# 当前图版与难度下的列数
func get_cols(skin: Cell.TileSkin = Cell.current_skin, difficulty: int = Cell.current_level) -> int:
	match skin:
		Cell.TileSkin.CLASSIC:
			return CLASSIC_LEVELS[difficulty]["cols"]
		Cell.TileSkin.POKEMON:
			return POKEMON_LEVELS[difficulty]["cols"]
	return COLS


# 当前棋盘应有的对数
func get_pairs(skin: Cell.TileSkin = Cell.current_skin, difficulty: int = Cell.current_level) -> int:
	return int((get_rows(skin, difficulty) * get_cols(skin, difficulty)) / 2.0)


# 读取当前图版对应难度下实际要使用的图块数量
func get_skin_tile_count(skin: Cell.TileSkin = Cell.current_skin, difficulty: int = Cell.current_level) -> int:
	match skin:
		Cell.TileSkin.CLASSIC:
			return Cell.get_texture_count(Cell.TileSkin.CLASSIC)
		Cell.TileSkin.POKEMON:
			return mini(POKEMON_LEVELS[difficulty]["tile_count"], Cell.get_texture_count(Cell.TileSkin.POKEMON))
	return get_pairs(skin, difficulty)


# 指定难度下完整棋盘应有的对数
func get_pairs_for_difficulty(difficulty: int, levels: Dictionary = CLASSIC_LEVELS) -> int:
	return int((levels[difficulty]["rows"] * levels[difficulty]["cols"]) / 2.0)


# 生成棋盘网格并绑定格子点击事件
func setup_grid(click_callback: Callable) -> void:
	var rows := get_rows()
	var cols := get_cols()
	_grid_container.columns = cols
	_aspect_ratio_container.ratio = float(cols) / float(rows)

	for child in _grid_container.get_children():
		_grid_container.remove_child(child)
		child.queue_free()

	for i in range(rows * cols):
		var cell: Cell = _cell_scene.instantiate()
		_grid_container.add_child(cell)
		# Cell 自身会通过 get_index() 发射正确的索引，无需额外 bind
		cell.cell_clicked.connect(click_callback)

	_on_grid_resized()


# 根据可用空间计算格子大小
func _on_grid_resized() -> void:
	if _board_center == null:
		return
	var available_size := _board_center.size
	if available_size.x <= 0 or available_size.y <= 0:
		return

	var rows := get_rows()
	var cols := get_cols()
	var h_sep: int = _grid_container.get_theme_constant("h_separation")
	var v_sep: int = _grid_container.get_theme_constant("v_separation")

	var target_size := available_size * BOARD_SCALE
	var cell_w: float = (target_size.x - (cols - 1) * h_sep) / cols
	var cell_h: float = (target_size.y - (rows - 1) * v_sep) / rows
	var cell_size: float = min(cell_w, cell_h)

	for child in _grid_container.get_children():
		child.custom_minimum_size = Vector2(cell_size, cell_size)

	_aspect_ratio_container.custom_minimum_size = Vector2(
		cols * cell_size + (cols - 1) * h_sep,
		rows * cell_size + (rows - 1) * v_sep
	)


# 生成随机棋盘，并确保至少存在指定数量可消除的对
func generate_board() -> void:
	var rows := get_rows()
	var cols := get_cols()
	var pairs := get_pairs()
	var tile_count := mini(get_skin_tile_count(), pairs)

	var tiles: Array[int] = []
	for type in range(1, tile_count + 1):
		tiles.append(type)
		tiles.append(type)

	var next_type := 1
	while tiles.size() < rows * cols:
		tiles.append(next_type)
		tiles.append(next_type)
		next_type = next_type % tile_count + 1

	var required := mini(MIN_MATCHABLE_PAIRS, pairs)
	var attempts := 0
	while true:
		tiles.shuffle()
		board.clear()
		for r in range(rows):
			board.append([])
			for c in range(cols):
				board[r].append(tiles[r * cols + c])

		if count_matchable_pairs(required) >= required:
			break

		attempts += 1
		if attempts > 2000:
			push_warning("未能在 2000 次尝试内生成含 %d 对可消除牌的棋盘" % required)
			break

	pairs_left = pairs


# 消除指定两个格子
func eliminate(r1: int, c1: int, r2: int, c2: int) -> void:
	board[r1][c1] = 0
	board[r2][c2] = 0
	pairs_left -= 1


# 获取棋盘与剩余对数状态，用于撤销/重做
func get_state() -> Dictionary:
	return {
		"board": board.duplicate(true),
		"pairs_left": pairs_left,
	}


# 恢复棋盘与剩余对数状态
func restore_state(state: Dictionary) -> void:
	board = state.get("board", board).duplicate(true)
	pairs_left = state.get("pairs_left", pairs_left)


# 刷新所有格子的图案与选中状态
func update_all_cells(selected_index: int = -1) -> void:
	var rows := get_rows()
	var cols := get_cols()
	for i in range(rows * cols):
		var cell: Cell = _grid_container.get_child(i)
		var r := int(float(i) / cols)
		var c := i % cols
		cell.tile_type = board[r][c]
		cell.selected = (i == selected_index)


# 索引与行列坐标互转
func index_to_pos(index: int) -> Vector2i:
	return Vector2i(int(float(index) / get_cols()), index % get_cols())


func pos_to_index(r: int, c: int) -> int:
	return r * get_cols() + c


# 判断两个格子能否连通
func can_connect(r1: int, c1: int, r2: int, c2: int) -> bool:
	return not find_connection_path(r1, c1, r2, c2).is_empty()


# BFS 搜索可连通路径，扩展棋盘外圈为虚拟空白，限制转弯次数 ≤ 2
func find_connection_path(r1: int, c1: int, r2: int, c2: int) -> Array[Vector2i]:
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
	for i in range(get_rows() + 2):
		visited.append([])
		came_from.append([])
		for j in range(get_cols() + 2):
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


# 将扩展棋盘坐标转换为全局屏幕坐标
func extended_to_screen(ext_pos: Vector2i) -> Vector2:
	var cell: Cell = _grid_container.get_child(0)
	var cell_size: Vector2 = cell.size
	var h_sep: int = _grid_container.get_theme_constant("h_separation")
	var v_sep: int = _grid_container.get_theme_constant("v_separation")
	var base: Vector2 = cell.position + cell_size / 2.0
	var local_in_aspect := _grid_container.position + Vector2(
		base.x + (ext_pos.y - 1) * (cell_size.x + h_sep),
		base.y + (ext_pos.x - 1) * (cell_size.y + v_sep)
	)
	return _aspect_ratio_container.global_position + local_in_aspect


# 判断扩展坐标是否可通行（棋盘外圈视为空白）
func _is_passable(ext_pos: Vector2i, end: Vector2i) -> bool:
	if ext_pos == end:
		return true
	if ext_pos.x < 0 or ext_pos.x > get_rows() + 1 or ext_pos.y < 0 or ext_pos.y > get_cols() + 1:
		return false
	if ext_pos.x == 0 or ext_pos.x == get_rows() + 1 or ext_pos.y == 0 or ext_pos.y == get_cols() + 1:
		return true
	return board[ext_pos.x - 1][ext_pos.y - 1] == 0


# 检查剩余牌中是否存在至少一对可连通的牌
func has_any_match() -> bool:
	var positions: Dictionary[int, Array] = {}
	for r in range(get_rows()):
		for c in range(get_cols()):
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
				if can_connect(p1.x, p1.y, p2.x, p2.y):
					return true
	return false


# 统计当前棋盘里可以消除的对数，达到 max_count 后提前返回
func count_matchable_pairs(max_count: int = 999) -> int:
	var positions: Dictionary[int, Array] = {}
	for r in range(get_rows()):
		for c in range(get_cols()):
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
				if can_connect(p1.x, p1.y, p2.x, p2.y):
					count += 1
					if count >= max_count:
						return count
	return count


# 查找一对可消除的图案，返回完整连接路径（扩展坐标）；找不到返回空数组
func find_hint_pair() -> Array[Vector2i]:
	var positions: Dictionary[int, Array] = {}
	for r in range(get_rows()):
		for c in range(get_cols()):
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
				var path := find_connection_path(p1.x, p1.y, p2.x, p2.y)
				if not path.is_empty():
					return path
	return []


# 根据关卡规则应用坍塌（方向以 int 传入，避免不同脚本枚举类型冲突）
func apply_collapse(level: int, level2_dir: int, level4_dir: int) -> void:
	match level:
		2:
			match level2_dir:
				Level2Dir.LEFT:
					_collapse_left()
				Level2Dir.RIGHT:
					_collapse_right()
		3:
			_collapse_outward()
		4:
			match level4_dir:
				Level4Dir.UP:
					_collapse_up()
				Level4Dir.DOWN:
					_collapse_down()
		5:
			_collapse_inward()
		6:
			_collapse_horizontal_expand()
		7:
			_collapse_vertical_expand()
		8:
			_collapse_horizontal_converge()
		9:
			_collapse_vertical_converge()
		10:
			_collapse_quadrant_spread()


# 手动重排剩余图案，确保洗牌后仍有足够可消除对
func shuffle_remaining() -> void:
	var remaining: Array[int] = []
	for r in range(get_rows()):
		for c in range(get_cols()):
			if board[r][c] != 0:
				remaining.append(board[r][c])

	if remaining.is_empty():
		return

	var required := mini(MIN_MATCHABLE_PAIRS, int(remaining.size() / 2.0))
	var attempts := 0
	while true:
		remaining.shuffle()
		var idx := 0
		for r in range(get_rows()):
			for c in range(get_cols()):
				if board[r][c] != 0:
					board[r][c] = remaining[idx]
					idx += 1

		if count_matchable_pairs(required) >= required:
			break

		attempts += 1
		if attempts > 2000:
			push_warning("未能在 2000 次尝试内洗出含 %d 对可消除牌的棋盘" % required)
			break


# ---------- 坍塌实现 ----------

func _collapse_left() -> void:
	for r in range(get_rows()):
		var new_row: Array[int] = []
		for c in range(get_cols()):
			if board[r][c] != 0:
				new_row.append(board[r][c])
		while new_row.size() < get_cols():
			new_row.append(0)
		board[r] = new_row


func _collapse_right() -> void:
	for r in range(get_rows()):
		var new_row: Array[int] = []
		for c in range(get_cols()):
			if board[r][c] != 0:
				new_row.append(board[r][c])
		while new_row.size() < get_cols():
			new_row.push_front(0)
		board[r] = new_row


func _collapse_up() -> void:
	for c in range(get_cols()):
		var new_col: Array[int] = []
		for r in range(get_rows()):
			if board[r][c] != 0:
				new_col.append(board[r][c])
		while new_col.size() < get_rows():
			new_col.append(0)
		for r in range(get_rows()):
			board[r][c] = new_col[r]


func _collapse_down() -> void:
	for c in range(get_cols()):
		var new_col: Array[int] = []
		for r in range(get_rows()):
			if board[r][c] != 0:
				new_col.append(board[r][c])
		while new_col.size() < get_rows():
			new_col.push_front(0)
		for r in range(get_rows()):
			board[r][c] = new_col[r]


func _collapse_outward() -> void:
	var center_r: int = int(get_rows() / 2.0)
	var center_c: int = int(get_cols() / 2.0)

	for r in range(get_rows()):
		var left_part: Array[int] = []
		var right_part: Array[int] = []
		for c in range(center_c):
			if board[r][c] != 0:
				left_part.append(board[r][c])
		for c in range(center_c, get_cols()):
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
		for c in range(center_c, get_cols()):
			board[r][c] = new_right[c - center_c]

	for c in range(get_cols()):
		var top_part: Array[int] = []
		var bottom_part: Array[int] = []
		for r in range(center_r):
			if board[r][c] != 0:
				top_part.append(board[r][c])
		for r in range(center_r, get_rows()):
			if board[r][c] != 0:
				bottom_part.append(board[r][c])

		var new_top: Array[int] = top_part.duplicate()
		while new_top.size() < center_r:
			new_top.append(0)

		var new_bottom: Array[int] = []
		for i in range((get_rows() - center_r) - bottom_part.size()):
			new_bottom.append(0)
		new_bottom.append_array(bottom_part)

		for r in range(center_r):
			board[r][c] = new_top[r]
		for r in range(center_r, get_rows()):
			board[r][c] = new_bottom[r - center_r]


func _collapse_inward() -> void:
	var center_r: int = int(get_rows() / 2.0)
	var center_c: int = int(get_cols() / 2.0)

	for r in range(get_rows()):
		var left_part: Array[int] = []
		var right_part: Array[int] = []
		for c in range(center_c):
			if board[r][c] != 0:
				left_part.append(board[r][c])
		for c in range(center_c, get_cols()):
			if board[r][c] != 0:
				right_part.append(board[r][c])

		var new_left: Array[int] = []
		for i in range(center_c - left_part.size()):
			new_left.append(0)
		new_left.append_array(left_part)

		var new_right: Array[int] = right_part.duplicate()
		while new_right.size() < (get_cols() - center_c):
			new_right.append(0)

		for c in range(center_c):
			board[r][c] = new_left[c]
		for c in range(center_c, get_cols()):
			board[r][c] = new_right[c - center_c]

	for c in range(get_cols()):
		var top_part: Array[int] = []
		var bottom_part: Array[int] = []
		for r in range(center_r):
			if board[r][c] != 0:
				top_part.append(board[r][c])
		for r in range(center_r, get_rows()):
			if board[r][c] != 0:
				bottom_part.append(board[r][c])

		var new_top: Array[int] = []
		for i in range(center_r - top_part.size()):
			new_top.append(0)
		new_top.append_array(top_part)

		var new_bottom: Array[int] = bottom_part.duplicate()
		while new_bottom.size() < (get_rows() - center_r):
			new_bottom.append(0)

		for r in range(center_r):
			board[r][c] = new_top[r]
		for r in range(center_r, get_rows()):
			board[r][c] = new_bottom[r - center_r]


func _collapse_horizontal_expand() -> void:
	var center_c: int = int(get_cols() / 2.0)
	for r in range(get_rows()):
		var left_part: Array[int] = []
		var right_part: Array[int] = []
		for c in range(center_c):
			if board[r][c] != 0:
				left_part.append(board[r][c])
		for c in range(center_c, get_cols()):
			if board[r][c] != 0:
				right_part.append(board[r][c])

		var new_left: Array[int] = left_part.duplicate()
		while new_left.size() < center_c:
			new_left.append(0)

		var new_right: Array[int] = []
		for i in range((get_cols() - center_c) - right_part.size()):
			new_right.append(0)
		new_right.append_array(right_part)

		for c in range(center_c):
			board[r][c] = new_left[c]
		for c in range(center_c, get_cols()):
			board[r][c] = new_right[c - center_c]


func _collapse_vertical_expand() -> void:
	var center_r: int = int(get_rows() / 2.0)
	for c in range(get_cols()):
		var top_part: Array[int] = []
		var bottom_part: Array[int] = []
		for r in range(center_r):
			if board[r][c] != 0:
				top_part.append(board[r][c])
		for r in range(center_r, get_rows()):
			if board[r][c] != 0:
				bottom_part.append(board[r][c])

		var new_top: Array[int] = top_part.duplicate()
		while new_top.size() < center_r:
			new_top.append(0)

		var new_bottom: Array[int] = []
		for i in range((get_rows() - center_r) - bottom_part.size()):
			new_bottom.append(0)
		new_bottom.append_array(bottom_part)

		for r in range(center_r):
			board[r][c] = new_top[r]
		for r in range(center_r, get_rows()):
			board[r][c] = new_bottom[r - center_r]


func _collapse_horizontal_converge() -> void:
	var center_c: int = int(get_cols() / 2.0)
	for r in range(get_rows()):
		var left_part: Array[int] = []
		var right_part: Array[int] = []
		for c in range(center_c):
			if board[r][c] != 0:
				left_part.append(board[r][c])
		for c in range(center_c, get_cols()):
			if board[r][c] != 0:
				right_part.append(board[r][c])

		var new_left: Array[int] = []
		for i in range(center_c - left_part.size()):
			new_left.append(0)
		new_left.append_array(left_part)

		var new_right: Array[int] = right_part.duplicate()
		while new_right.size() < (get_cols() - center_c):
			new_right.append(0)

		for c in range(center_c):
			board[r][c] = new_left[c]
		for c in range(center_c, get_cols()):
			board[r][c] = new_right[c - center_c]


func _collapse_vertical_converge() -> void:
	var center_r: int = int(get_rows() / 2.0)
	for c in range(get_cols()):
		var top_part: Array[int] = []
		var bottom_part: Array[int] = []
		for r in range(center_r):
			if board[r][c] != 0:
				top_part.append(board[r][c])
		for r in range(center_r, get_rows()):
			if board[r][c] != 0:
				bottom_part.append(board[r][c])

		var new_top: Array[int] = []
		for i in range(center_r - top_part.size()):
			new_top.append(0)
		new_top.append_array(top_part)

		var new_bottom: Array[int] = bottom_part.duplicate()
		while new_bottom.size() < (get_rows() - center_r):
			new_bottom.append(0)

		for r in range(center_r):
			board[r][c] = new_top[r]
		for r in range(center_r, get_rows()):
			board[r][c] = new_bottom[r - center_r]


func _collapse_quadrant_spread() -> void:
	var center_r: int = int(get_rows() / 2.0)
	var center_c: int = int(get_cols() / 2.0)

	for c in range(center_c, get_cols()):
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

	for r in range(center_r, get_rows()):
		var part: Array[int] = []
		for c in range(center_c):
			if board[r][c] != 0:
				part.append(board[r][c])
		var new_part: Array[int] = part.duplicate()
		while new_part.size() < center_c:
			new_part.append(0)
		for c in range(center_c):
			board[r][c] = new_part[c]

	for r in range(center_r, get_rows()):
		var part: Array[int] = []
		for c in range(center_c, get_cols()):
			if board[r][c] != 0:
				part.append(board[r][c])
		var new_part: Array[int] = []
		for i in range((get_cols() - center_c) - part.size()):
			new_part.append(0)
		new_part.append_array(part)
		for c in range(center_c, get_cols()):
			board[r][c] = new_part[c - center_c]
