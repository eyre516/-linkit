extends PanelContainer
class_name Cell

# 单个格子组件：显示图集图标、响应点击并反馈选中 / 提示状态。

signal cell_clicked(index: int)

# ------------------------------
# 模块：图版（皮肤）配置
# 说明：支持多版图切换；CLASSIC 图版按难度级别提供 14/28/42 张图标
# ------------------------------
enum TileSkin {POKEMON, CLASSIC}

# 通过 preload 显式声明所有图块纹理，确保导出时这些资源会被打包进 PCK。
# 动态 load(path) 不会被 Godot 的导出依赖扫描识别，导致导出后只加载到
# 已被其他场景引用的少量纹理（常见现象是图版只剩一个图案）。
const POKEMON_TEXTURES: Array[Texture2D] = [
	preload("res://assets/pokemon/normal/tile_01.png"),
	preload("res://assets/pokemon/normal/tile_02.png"),
	preload("res://assets/pokemon/normal/tile_03.png"),
	preload("res://assets/pokemon/normal/tile_04.png"),
	preload("res://assets/pokemon/normal/tile_05.png"),
	preload("res://assets/pokemon/normal/tile_06.png"),
	preload("res://assets/pokemon/normal/tile_07.png"),
	preload("res://assets/pokemon/normal/tile_08.png"),
	preload("res://assets/pokemon/normal/tile_09.png"),
	preload("res://assets/pokemon/normal/tile_10.png"),
	preload("res://assets/pokemon/normal/tile_11.png"),
	preload("res://assets/pokemon/normal/tile_12.png"),
	preload("res://assets/pokemon/normal/tile_13.png"),
	preload("res://assets/pokemon/normal/tile_14.png"),
	preload("res://assets/pokemon/normal/tile_15.png"),
	preload("res://assets/pokemon/normal/tile_16.png"),
	preload("res://assets/pokemon/normal/tile_17.png"),
	preload("res://assets/pokemon/normal/tile_18.png"),
	preload("res://assets/pokemon/normal/tile_19.png"),
	preload("res://assets/pokemon/normal/tile_20.png"),
	preload("res://assets/pokemon/normal/tile_21.png"),
	preload("res://assets/pokemon/normal/tile_22.png"),
	preload("res://assets/pokemon/normal/tile_23.png"),
	preload("res://assets/pokemon/normal/tile_24.png"),
	preload("res://assets/pokemon/normal/tile_25.png"),
	preload("res://assets/pokemon/normal/tile_26.png"),
	preload("res://assets/pokemon/normal/tile_27.png"),
	preload("res://assets/pokemon/normal/tile_28.png"),
	preload("res://assets/pokemon/normal/tile_29.png"),
	preload("res://assets/pokemon/normal/tile_30.png"),
	preload("res://assets/pokemon/normal/tile_31.png"),
	preload("res://assets/pokemon/normal/tile_32.png"),
	preload("res://assets/pokemon/normal/tile_33.png"),
	preload("res://assets/pokemon/normal/tile_34.png"),
	preload("res://assets/pokemon/normal/tile_35.png"),
	preload("res://assets/pokemon/normal/tile_36.png"),
	preload("res://assets/pokemon/normal/tile_37.png"),
	preload("res://assets/pokemon/normal/tile_38.png"),
	preload("res://assets/pokemon/normal/tile_39.png"),
	preload("res://assets/pokemon/normal/tile_40.png"),
	preload("res://assets/pokemon/normal/tile_41.png"),
	preload("res://assets/pokemon/normal/tile_42.png"),
]

const CLASSIC_TEXTURES: Array[Texture2D] = [
	preload("res://assets/classicPics/level3/normal/tile_01.png"),
	preload("res://assets/classicPics/level3/normal/tile_02.png"),
	preload("res://assets/classicPics/level3/normal/tile_03.png"),
	preload("res://assets/classicPics/level3/normal/tile_04.png"),
	preload("res://assets/classicPics/level3/normal/tile_05.png"),
	preload("res://assets/classicPics/level3/normal/tile_06.png"),
	preload("res://assets/classicPics/level3/normal/tile_07.png"),
	preload("res://assets/classicPics/level3/normal/tile_08.png"),
	preload("res://assets/classicPics/level3/normal/tile_09.png"),
	preload("res://assets/classicPics/level3/normal/tile_10.png"),
	preload("res://assets/classicPics/level3/normal/tile_11.png"),
	preload("res://assets/classicPics/level3/normal/tile_12.png"),
	preload("res://assets/classicPics/level3/normal/tile_13.png"),
	preload("res://assets/classicPics/level3/normal/tile_14.png"),
	preload("res://assets/classicPics/level3/normal/tile_15.png"),
	preload("res://assets/classicPics/level3/normal/tile_16.png"),
	preload("res://assets/classicPics/level3/normal/tile_17.png"),
	preload("res://assets/classicPics/level3/normal/tile_18.png"),
	preload("res://assets/classicPics/level3/normal/tile_19.png"),
	preload("res://assets/classicPics/level3/normal/tile_20.png"),
	preload("res://assets/classicPics/level3/normal/tile_21.png"),
	preload("res://assets/classicPics/level3/normal/tile_22.png"),
	preload("res://assets/classicPics/level3/normal/tile_23.png"),
	preload("res://assets/classicPics/level3/normal/tile_24.png"),
	preload("res://assets/classicPics/level3/normal/tile_25.png"),
	preload("res://assets/classicPics/level3/normal/tile_26.png"),
	preload("res://assets/classicPics/level3/normal/tile_27.png"),
	preload("res://assets/classicPics/level3/normal/tile_28.png"),
	preload("res://assets/classicPics/level3/normal/tile_29.png"),
	preload("res://assets/classicPics/level3/normal/tile_30.png"),
	preload("res://assets/classicPics/level3/normal/tile_31.png"),
	preload("res://assets/classicPics/level3/normal/tile_32.png"),
	preload("res://assets/classicPics/level3/normal/tile_33.png"),
	preload("res://assets/classicPics/level3/normal/tile_34.png"),
	preload("res://assets/classicPics/level3/normal/tile_35.png"),
	preload("res://assets/classicPics/level3/normal/tile_36.png"),
	preload("res://assets/classicPics/level3/normal/tile_37.png"),
	preload("res://assets/classicPics/level3/normal/tile_38.png"),
	preload("res://assets/classicPics/level3/normal/tile_39.png"),
	preload("res://assets/classicPics/level3/normal/tile_40.png"),
	preload("res://assets/classicPics/level3/normal/tile_41.png"),
	preload("res://assets/classicPics/level3/normal/tile_42.png"),
]

const SKIN_TEXTURES := {
	TileSkin.POKEMON: POKEMON_TEXTURES,
	TileSkin.CLASSIC: CLASSIC_TEXTURES,
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
@onready var selection_highlight: ColorRect = $SelectionHighlight

# 当前正在运行的提示闪烁动画，避免与消除状态冲突
var _flash_tween: Tween = null
# 选中状态的缩放补间
var _selection_tween: Tween = null
# 消除动画补间
var _eliminate_tween: Tween = null


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


# 获取指定图版当前可用的纹理数量
static func get_texture_count(skin: TileSkin = current_skin) -> int:
	return SKIN_TEXTURES[skin].size()


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
		var textures: Array[Texture2D] = SKIN_TEXTURES[current_skin]
		if type < 1 or type > textures.size():
			_texture_cache[cache_key] = null
		else:
			_texture_cache[cache_key] = textures[type - 1]

	return _texture_cache[cache_key]


# 设置图案类型：空白格完全隐藏，否则显示
func _set_tile_type(value: int) -> void:
	# 停止可能正在进行的闪烁动画，防止它覆盖消除后的透明状态
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
		_flash_tween = null
	# 停止正在进行的消除动画，避免状态冲突
	if _eliminate_tween != null and _eliminate_tween.is_valid():
		_eliminate_tween.kill()
		_eliminate_tween = null

	tile_type = value
	modulate = Color(1, 1, 1, 0) if tile_type == 0 else Color.WHITE
	if texture_rect:
		# 重置缩放和透明度，避免残留动画状态
		texture_rect.scale = Vector2.ONE
		texture_rect.modulate = Color.WHITE
		update_icon()
	if selection_highlight:
		selection_highlight.visible = false


# 设置选中状态：选中时显示高亮层并轻微放大图标
func _set_selected(value: bool) -> void:
	selected = value
	if selection_highlight:
		selection_highlight.visible = selected
	if texture_rect:
		# 选中时轻微放大图标，未选中时恢复
		if _selection_tween != null and _selection_tween.is_valid():
			_selection_tween.kill()
		_selection_tween = create_tween()
		_selection_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var target_scale := Vector2(1.12, 1.12) if selected else Vector2.ONE
		# 确保缩放中心为图标中心
		texture_rect.pivot_offset = texture_rect.size / 2.0
		_selection_tween.tween_property(texture_rect, "scale", target_scale, 0.12)


# 提示闪烁动画
func flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate:a", 0.2, 0.25)
	_flash_tween.tween_property(self, "modulate:a", 1.0, 0.25)
	_flash_tween.tween_property(self, "modulate:a", 0.2, 0.25)
	_flash_tween.tween_property(self, "modulate:a", 1.0, 0.25)


# 消除动画：图标缩小并淡出，返回 Tween 供外部 await
func play_eliminate_animation() -> Tween:
	if _eliminate_tween != null and _eliminate_tween.is_valid():
		_eliminate_tween.kill()
	if _selection_tween != null and _selection_tween.is_valid():
		_selection_tween.kill()
	if texture_rect:
		texture_rect.pivot_offset = texture_rect.size / 2.0
		_eliminate_tween = create_tween()
		_eliminate_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_eliminate_tween.set_parallel(true)
		_eliminate_tween.tween_property(texture_rect, "scale", Vector2.ZERO, 0.15)
		_eliminate_tween.tween_property(texture_rect, "modulate:a", 0.0, 0.15)
		return _eliminate_tween
	return null


# 模块：交互反馈 —— 左键点击时通知父节点
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.is_pressed():
		cell_clicked.emit(get_index())
