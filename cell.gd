extends PanelContainer
class_name Cell

# 单个格子组件：显示图集图标、响应点击并反馈选中 / 提示状态。

signal cell_clicked(index: int)

# ------------------------------
# 模块：图版（皮肤）配置
# 说明：支持多版图切换；CLASSIC 图版按难度级别提供 14/28/42 张图标
# ------------------------------
enum TileSkin {POKEMON, CLASSIC}

const SKIN_PATHS := {
	TileSkin.POKEMON: "res://assets/pokemon/normal/tile_%02d.png",
	TileSkin.CLASSIC: "res://assets/classicPics/level3/normal/tile_%02d.png",
}

# 当前全局图版，所有格子共用
static var current_skin: TileSkin = TileSkin.POKEMON
# classicPics 难度级别（保留接口，但素材已统一集中到 level3）
static var current_level: int = 3

# 纹理缓存：键为 skin*1000 + type，避免重复加载
static var _texture_cache: Dictionary[int, Texture2D] = {}

# 模块：格子状态
# 当前格子显示的图案类型（0 表示空白）
var tile_type: int = 0:
	set = _set_tile_type

# 是否被选中
var selected: bool = false:
	set = _set_selected

@onready var texture_rect: TextureRect = $MarginContainer/TextureRect

# 当前正在运行的提示闪烁动画，避免与消除状态冲突
var _flash_tween: Tween = null


# 模块：图标渲染 —— 初始化时显示对应图标
func _ready() -> void:
	update_icon()
	_set_selected(selected)


# 切换全局图版，切换后需要调用方刷新棋盘并清空缓存
static func set_skin(skin: TileSkin) -> void:
	if current_skin == skin:
		return
	current_skin = skin
	clear_texture_cache()


# 切换 CLASSIC 图版的难度级别，切换后需要调用方刷新棋盘并清空缓存
static func set_level(level: int) -> void:
	if level < 1 or level > 3:
		push_warning("Cell.set_level: level must be 1, 2 or 3")
		return
	if current_level == level:
		return
	current_level = level
	clear_texture_cache()


# 清空纹理缓存，用于图版切换后强制重新加载
static func clear_texture_cache() -> void:
	_texture_cache.clear()


# 根据 tile_type 刷新图标显示
func update_icon() -> void:
	if tile_type == 0:
		texture_rect.texture = null
		return
	texture_rect.texture = _get_texture(tile_type)


# 从缓存中获取对应类型与图版的纹理
func _get_texture(type: int) -> Texture2D:
	var cache_key := int(current_skin) * 1000 + type
	if not _texture_cache.has(cache_key):
		var path: String = SKIN_PATHS[current_skin] % type
		var tex := load(path) as Texture2D
		_texture_cache[cache_key] = tex

	return _texture_cache[cache_key]


# 设置图案类型：空白格完全隐藏，否则显示
func _set_tile_type(value: int) -> void:
	# 停止可能正在进行的闪烁动画，防止它覆盖消除后的透明状态
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
		_flash_tween = null

	tile_type = value
	modulate = Color(1, 1, 1, 0) if tile_type == 0 else Color.WHITE
	if texture_rect:
		update_icon()


# 设置选中状态：选中时高亮
func _set_selected(value: bool) -> void:
	selected = value
	if texture_rect:
		# 选中时提亮，未选中时恢复
		texture_rect.modulate = Color(1.4, 1.4, 1.4) if selected else Color.WHITE


# 提示闪烁动画
func flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate:a", 0.2, 0.25)
	_flash_tween.tween_property(self, "modulate:a", 1.0, 0.25)
	_flash_tween.tween_property(self, "modulate:a", 0.2, 0.25)
	_flash_tween.tween_property(self, "modulate:a", 1.0, 0.25)


# 模块：交互反馈 —— 左键点击时通知父节点
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.is_pressed():
		cell_clicked.emit(get_index())
