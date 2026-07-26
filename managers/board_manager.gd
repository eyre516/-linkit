extends Node
class_name BoardManager

# 棋盘管理器：负责棋盘尺寸、生成、洗牌、坍塌、路径查找与提示查找。

enum Level2Dir {LEFT, RIGHT}
enum Level4Dir {UP, DOWN}

# 默认棋盘尺寸（宝可梦图版 / 经典高级难度使用）
const ROWS := 7
const COLS := 12
const PAIRS := 42
const MIN_MATCHABLE_PAIRS := 3
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

	var tiles_by_type := _build_tiles_by_type_for_generate(rows, cols, tile_count)

	# 清空棋盘
	board.clear()
	for r in range(rows):
		board.append([])
		for c in range(cols):
			board[r].append(0)

	var available_positions: Array[Vector2i] = []
	for r in range(rows):
		for c in range(cols):
			available_positions.append(Vector2i(r, c))

	var required := mini(MIN_MATCHABLE_PAIRS, pairs)
	_place_guaranteed_pairs(available_positions, tiles_by_type, required)
	_fill_remaining(available_positions, tiles_by_type)

	pairs_left = pairs


# 按原有规则构造生成所需的图案数量表：每种图案均为偶数个
func _build_tiles_by_type_for_generate(rows: int, cols: int, tile_count: int) -> Dictionary[int, int]:
	var tiles_by_type: Dictionary[int, int] = {}
	for type in range(1, tile_count + 1):
		tiles_by_type[type] = 2

	var next_type := 1
	var total_tiles := tile_count * 2
	while total_tiles < rows * cols:
		tiles_by_type[next_type] += 2
		total_tiles += 2
		next_type = next_type % tile_count + 1

	return tiles_by_type


# 贪心随机放置 required 对图块，优先相邻（保证 0 转弯可连通），
# 不足时再尝试同行/同列（在稀疏棋盘上仍有较高概率可连通）。
# 返回实际放置的对数，并将用过的位置从 available_positions 中移除。
func _place_guaranteed_pairs(available_positions: Array[Vector2i], tiles_by_type: Dictionary[int, int], required: int) -> int:
	var pairable_set: Dictionary[Vector2i, bool] = {}
	for pos in available_positions:
		pairable_set[pos] = true

	var placed := 0
	var used_positions: Dictionary[Vector2i, bool] = {}

	# 阶段 1：相邻对
	while placed < required and not pairable_set.is_empty():
		var keys: Array = pairable_set.keys()
		var pos: Vector2i = keys[randi() % keys.size()]

		var neighbors: Array[Vector2i] = []
		for dir in DIRECTIONS:
			var neighbor: Vector2i = pos + dir
			if pairable_set.has(neighbor):
				neighbors.append(neighbor)

		if neighbors.is_empty():
			pairable_set.erase(pos)
			continue

		var neighbor: Vector2i = neighbors[randi() % neighbors.size()]
		var type := _find_type_with_min_count(tiles_by_type, 2)
		if type == -1:
			break

		tiles_by_type[type] -= 2
		if tiles_by_type[type] == 0:
			tiles_by_type.erase(type)

		board[pos.x][pos.y] = type
		board[neighbor.x][neighbor.y] = type
		used_positions[pos] = true
		used_positions[neighbor] = true
		pairable_set.erase(pos)
		pairable_set.erase(neighbor)
		placed += 1

	# 阶段 2：同行/同列对（稀疏时仍可较大概率连通）
	if placed < required:
		var row_groups: Dictionary[int, Array] = {}
		var col_groups: Dictionary[int, Array] = {}
		for pos in pairable_set.keys():
			if not row_groups.has(pos.x):
				row_groups[pos.x] = []
			row_groups[pos.x].append(pos)
			if not col_groups.has(pos.y):
				col_groups[pos.y] = []
			col_groups[pos.y].append(pos)

		var candidates: Array[Vector2i] = []
		for positions in row_groups.values():
			for i in range(positions.size()):
				for j in range(i + 1, positions.size()):
					candidates.append(positions[i])
					candidates.append(positions[j])
		for positions in col_groups.values():
			for i in range(positions.size()):
				for j in range(i + 1, positions.size()):
					candidates.append(positions[i])
					candidates.append(positions[j])

		# 候选对每两个 Vector2i 为一组，打乱后依次尝试
		var pair_count := int(candidates.size() / 2.0)
		var order: Array[int] = []
		for i in range(pair_count):
			order.append(i)
		order.shuffle()

		for idx in order:
			if placed >= required:
				break
			var p1: Vector2i = candidates[idx * 2]
			var p2: Vector2i = candidates[idx * 2 + 1]
			if used_positions.has(p1) or used_positions.has(p2):
				continue
			var type := _find_type_with_min_count(tiles_by_type, 2)
			if type == -1:
				break

			tiles_by_type[type] -= 2
			if tiles_by_type[type] == 0:
				tiles_by_type.erase(type)

			board[p1.x][p1.y] = type
			board[p2.x][p2.y] = type
			used_positions[p1] = true
			used_positions[p2] = true
			pairable_set.erase(p1)
			pairable_set.erase(p2)
			placed += 1

	# 将未使用的可用位置保留下来，供后续随机填充
	var remaining: Array[Vector2i] = []
	for pos in available_positions:
		if not used_positions.has(pos):
			remaining.append(pos)
	available_positions.clear()
	available_positions.append_array(remaining)

	return placed


# 从 tiles_by_type 中找出剩余数量不少于 min_count 的随机一种图案
func _find_type_with_min_count(tiles_by_type: Dictionary[int, int], min_count: int) -> int:
	var candidates: Array[int] = []
	for type: int in tiles_by_type.keys():
		if tiles_by_type[type] >= min_count:
			candidates.append(type)
	if candidates.is_empty():
		return -1
	return candidates[randi() % candidates.size()]


# 将剩余图块随机填入剩余位置
func _fill_remaining(available_positions: Array[Vector2i], tiles_by_type: Dictionary[int, int]) -> void:
	var remaining_tiles: Array[int] = []
	for type: int in tiles_by_type.keys():
		for i in range(tiles_by_type[type]):
			remaining_tiles.append(type)
	remaining_tiles.shuffle()

	for i in range(available_positions.size()):
		var pos: Vector2i = available_positions[i]
		board[pos.x][pos.y] = remaining_tiles[i]


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


# 根据关卡规则应用坍塌（方向以 int 传入，避免不同脚本枚举类型冲突）。
# 返回用于播放坍塌动画的 Tween；若无需动画则返回 null。
func apply_collapse(level: int, level2_dir: int, level4_dir: int, duration: float = 0.15) -> Tween:
	if level <= 1:
		return null

	var old_board := board.duplicate(true)
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

	return _animate_collapse(old_board, duration)


# 对比坍塌前后的棋盘，按图案值匹配旧位置与新位置，生成移动列表
func _build_movement_map(old_board: Array, new_board: Array) -> Array[Dictionary]:
	var movements: Array[Dictionary] = []
	var old_positions_by_type: Dictionary[int, Array] = {}
	var new_positions_by_type: Dictionary[int, Array] = {}

	for r in range(get_rows()):
		for c in range(get_cols()):
			var old_type: int = old_board[r][c]
			if old_type != 0:
				if not old_positions_by_type.has(old_type):
					old_positions_by_type[old_type] = []
				old_positions_by_type[old_type].append(Vector2i(r, c))

			var new_type: int = new_board[r][c]
			if new_type != 0:
				if not new_positions_by_type.has(new_type):
					new_positions_by_type[new_type] = []
				new_positions_by_type[new_type].append(Vector2i(r, c))

	for type: int in old_positions_by_type.keys():
		var old_positions: Array = old_positions_by_type[type]
		var new_positions: Array = new_positions_by_type.get(type, [])
		# 坍塌不改变非空图案总数，因此 old/new 数量应相同
		var count := mini(old_positions.size(), new_positions.size())
		for i in range(count):
			var old_pos: Vector2i = old_positions[i]
			var new_pos: Vector2i = new_positions[i]
			if old_pos != new_pos:
				movements.append({
					"old_pos": old_pos,
					"new_pos": new_pos,
					"tile_type": type,
				})

	return movements


# 获取指定棋盘格子的全局位置
func _get_cell_global_position(r: int, c: int) -> Vector2:
	var idx := pos_to_index(r, c)
	if idx < 0 or idx >= _grid_container.get_child_count():
		return Vector2.ZERO
	return _grid_container.get_child(idx).global_position


# 根据源格子创建一个轻量“幽灵”：底色与图标均保持原样，图标使用普通视觉大小、scale 为 1.0
func _create_ghost_from_cell(source_cell: Cell) -> Control:
	var ghost := Control.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.size = source_cell.size

	# 复制源格子的面板样式作为底色（不存放子节点，避免边距影响位置）
	var bg := PanelContainer.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.size = source_cell.size
	var stylebox := source_cell.get_theme_stylebox("panel")
	if stylebox != null:
		bg.add_theme_stylebox_override("panel", stylebox)
	ghost.add_child(bg)

	# 创建图标，使用普通情况下的视觉大小，scale 固定为 1.0，移动过程中绝不变化
	var source_icon: TextureRect = source_cell.get_node_or_null("MarginContainer/TextureRect")
	if source_icon != null and source_icon.texture != null:
		var icon := TextureRect.new()
		icon.texture = source_icon.texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var base_scale := Cell.POKEMON_ICON_SCALE if Cell.current_skin == Cell.TileSkin.POKEMON else Vector2.ONE
		var icon_size := source_icon.size * base_scale
		icon.size = icon_size
		icon.position = (source_cell.size - icon_size) / 2.0
		icon.scale = Vector2.ONE
		icon.modulate = Color.WHITE
		ghost.add_child(icon)

	return ghost


# 执行坍塌位移动画：源格子和目标格子暂时隐藏，由幽灵代替平移，图案大小始终不变
func _animate_collapse(old_board: Array, duration: float) -> Tween:
	var movements := _build_movement_map(old_board, board)
	if movements.is_empty():
		return null

	var source_indices: Array[int] = []
	var destination_indices: Array[int] = []
	for movement in movements:
		var old_idx := pos_to_index(movement.old_pos.x, movement.old_pos.y)
		var new_idx := pos_to_index(movement.new_pos.x, movement.new_pos.y)
		if not source_indices.has(old_idx):
			source_indices.append(old_idx)
		if not destination_indices.has(new_idx):
			destination_indices.append(new_idx)

	var affected_indices: Array[int] = []
	for idx in source_indices:
		if not affected_indices.has(idx):
			affected_indices.append(idx)
	for idx in destination_indices:
		if not affected_indices.has(idx):
			affected_indices.append(idx)

	# 立即把实际棋盘更新到坍塌后的状态：目标位置写入新图案并隐藏，源格子也隐藏，由幽灵完成移动动画
	for idx in destination_indices:
		var cell: Cell = _grid_container.get_child(idx)
		var pos := index_to_pos(idx)
		cell.tile_type = board[pos.x][pos.y]
		cell.modulate.a = 0.0

	for idx in source_indices:
		var cell: Cell = _grid_container.get_child(idx)
		cell.reset_icon_scale_to_base()
		cell.modulate.a = 0.0

	# 创建幽灵层，使用 top_level 避免受 GridContainer 重新布局影响
	var ghost_parent := Control.new()
	ghost_parent.name = "CollapseGhosts"
	ghost_parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost_parent.top_level = true
	_grid_container.add_child(ghost_parent)

	# 线性、迅速地平移到目标位置
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)

	for movement in movements:
		var source_idx := pos_to_index(movement.old_pos.x, movement.old_pos.y)
		var source_cell: Cell = _grid_container.get_child(source_idx)
		var ghost := _create_ghost_from_cell(source_cell)
		ghost.global_position = source_cell.global_position
		ghost_parent.add_child(ghost)
		var target_pos := _get_cell_global_position(movement.new_pos.x, movement.new_pos.y)
		tween.tween_property(ghost, "global_position", target_pos, duration)

	# 动画结束后立即清理幽灵并恢复实际格子可见，避免闪烁
	tween.finished.connect(func() -> void:
		ghost_parent.queue_free()
		for idx in affected_indices:
			var cell: Cell = _grid_container.get_child(idx)
			cell.modulate.a = 1.0
	)

	return tween


# 手动重排剩余图案，确保洗牌后仍有足够可消除对
func shuffle_remaining() -> void:
	var tiles_by_type: Dictionary[int, int] = {}
	var available_positions: Array[Vector2i] = []

	for r in range(get_rows()):
		for c in range(get_cols()):
			var type: int = board[r][c]
			if type == 0:
				continue
			tiles_by_type[type] = tiles_by_type.get(type, 0) + 1
			available_positions.append(Vector2i(r, c))
			board[r][c] = 0

	if available_positions.is_empty():
		return

	var pairs_left := int(available_positions.size() / 2.0)
	# 根据剩余对数动态决定需要保证的可连通对数：
	# 对数较多时保证 MIN_MATCHABLE_PAIRS 对；对数较少时保证至少一半，
	# 避免大棋盘后期或棋盘碎片化时无法找到足够相邻空位。
	var required := mini(MIN_MATCHABLE_PAIRS, maxi(1, int(pairs_left / 2.0)))

	_place_guaranteed_pairs(available_positions, tiles_by_type, required)
	_fill_remaining(available_positions, tiles_by_type)


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
