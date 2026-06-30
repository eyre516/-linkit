# 连连看开发日志

本文件记录项目从原始状态到当前版本的主要修改与开发决策，便于后续维护与回溯。

---

## 项目概述

- **引擎**：Godot 4.5
- **语言**：GDScript
- **类型**：经典连连看（Tile Matching）
- **原始状态**：7×12 固定棋盘、42 对图块、支持撤销/重做/提示/洗牌

---

## 开发记录

### 1. 项目结构梳理

**时间**：2026-06-30  
**说明**：整理并输出项目文件结构，确认资源、代码、配置的分布。

```
.
├── project.godot          # Godot 项目配置
├── game.gd / game.tscn    # 主游戏逻辑与场景
├── cell.gd / cell.tscn    # 格子组件
├── assets/
│   ├── classicPics/       # 经典图版图块（按 level1/2/3 分级）
│   ├── pokemon/           # 宝可梦图版图块
│   └── 连连看例子/        # 旧版连连看资源包
└── extract_tiles.py       # 图块提取脚本
```

---

### 2. 从旧版资源提取经典图块

**时间**：2026-06-30  
**涉及文件**：`assets/连连看例子/extract_tiles.py`

- 从 `extracted_bmp/bitmap_129.bmp` 提取 42 个 39×39 图块（normal + selected 两版）。
- 图块按难度分级存放：
  - `assets/classicPics/level1/`：初级 14 种
  - `assets/classicPics/level2/`：中级 28 种
  - `assets/classicPics/level3/`：高级 42 种
- 旧版关卡背景图按编号分组复制到 `assets/classicPics/backgrounds/level1~3/`。

> 注意：旧版资源中只有 `bitmap_129.bmp` 是完整的小图块精灵表，因此经典图版最终可用的图块种类为 42 种。

---

### 3. 修复提取图块偏蓝问题

**时间**：2026-06-30  
**涉及文件**：`assets/连连看例子/extract_tiles.py`

**原因**：脚本使用 PIL 读取 BMP（PIL 内部已完成 BGR→RGB 转换），但代码又手动交换了一次红蓝通道，导致颜色偏蓝。

**修复**：将颜色写入从 `(b, g, r)` 改回 `(r, g, b)`。

---

### 4. 经典图案模式：按难度使用对应素材 + 动态棋盘

**时间**：2026-06-30  
**涉及文件**：`game.gd`、`cell.gd`

- `cell.gd`：
  - CLASSIC 皮肤路径改为 `res://assets/classicPics/level%d/normal/tile_%02d.png`
  - 新增 `current_level` 与 `set_level()`，用于选择初/中/高级文件夹
- `game.gd`：
  - 新增 `CLASSIC_LEVELS` 配置，经典图案各难度棋盘尺寸如下：
	- 初级：7×12 = 84 格
	- 中级：8×14 = 112 格
	- 高级：9×16 = 144 格
  - 新增 `_get_rows()` / `_get_cols()` / `_get_pairs()`，根据当前皮肤和难度动态计算棋盘尺寸
  - 新增 `_get_skin_tile_count()`，读取对应难度文件夹中的实际图块数量
  - `_generate_board()` 根据实际图块数量生成棋盘，图块不足时循环成对补充
  - 切换难度/图版/关卡时重新 `_setup_grid()`，同步更新 `GridContainer.columns` 与 `AspectRatioContainer.ratio`

---

### 5. 宝可梦图版：同样按难度分级 + 棋盘变大 + 棋子变大

**时间**：2026-06-30  
**涉及文件**：`game.gd`

- 新增 `POKEMON_LEVELS` 配置：
  - 初级：6×10 = 60 格，使用 14 种图块
  - 中级：8×12 = 96 格，使用 28 种图块
  - 高级：8×14 = 112 格，使用 42 种图块
- `_get_rows()` / `_get_cols()` 同时处理 CLASSIC 与 POKEMON 两种皮肤
- `_get_skin_tile_count()` 对宝可梦返回配置数量（因为所有 42 种图块都在同一目录，需要按难度限制使用数量）
- `BOARD_SCALE` 从 `0.8` 提升到 `0.95`，使各难度棋子均比原来更大

---

### 6. 修复运行时 Dictionary 越界错误

**时间**：2026-06-30  
**涉及文件**：`game.gd`

**现象**：运行时报错 `Out of bounds get index '0' (on base: 'Dictionary')`。

**原因**：成员变量 `pairs_left` 的初始化 `= _get_pairs()` 发生在 `current_difficulty` 初始化之前，导致访问 `CLASSIC_LEVELS[0]` / `POKEMON_LEVELS[0]`。

**修复**：将 `pairs_left` 初始值改为 `0`，因为 `_ready()` 会调用 `restart_game()`，而 `restart_game()` 内部会正确设置 `pairs_left = _get_pairs()`。

---

### 7. 经典图案 UI 美化：去边框 + 浅黄底色 + 背景图

**时间**：2026-06-30  
**涉及文件**：`cell.tscn`、`game.tscn`、`game.gd`

- `cell.tscn`：
  - `StyleBoxFlat` 四边 `border_width` 设为 `0`，去掉浅色边框
  - 底色改为 `Color(1, 0.95, 0.7, 1)`（浅黄色）
- `game.tscn`：
  - 在 `Background` ColorRect 下新增 `BackgroundImage` TextureRect
  - 设置 `expand_mode = 1`、`stretch_mode = 5`（`KEEP_ASPECT_CENTERED`），保持原始比例居中显示，不铺满屏幕
- `game.gd`：
  - 新增 `_load_background_image()`，根据当前难度与关卡从 `assets/classicPics/backgrounds/levelX/` 加载背景图
  - 宝可梦模式下自动隐藏背景图
  - 在 `_ready()`、切换难度、切换图版、选择关卡、进入下一关时调用

---

## 当前各难度棋盘与图块配置

### 经典图案

| 难度 | 棋盘 | 图块种类 | 背景图 |
|------|------|----------|--------|
| 初级 | 7×12 = 84 格 | `classicPics/level1/` 14 种 | `backgrounds/level1/` |
| 中级 | 8×14 = 112 格 | `classicPics/level2/` 28 种 | `backgrounds/level2/` |
| 高级 | 9×16 = 144 格 | `classicPics/level3/` 42 种 | `backgrounds/level3/` |

### 宝可梦

| 难度 | 棋盘 | 图块种类 |
|------|------|----------|
| 初级 | 6×10 = 60 格 | 14 种 |
| 中级 | 8×12 = 96 格 | 28 种 |
| 高级 | 8×14 = 112 格 | 42 种 |

---

## 常用脚本

### 重新提取并整理经典图块

```bash
cd assets/连连看例子
../../.venv/Scripts/python.exe extract_tiles.py
```

运行后会：
- 从 `extracted_bmp/bitmap_129.bmp` 提取全部图块
- 按 14 / 28 / 42 的数量分到 `assets/classicPics/level1~3/`
- 复制背景图到 `assets/classicPics/backgrounds/level1~3/`

---

## 注意事项

1. **Godot 导入缓存**：修改或新增图片后，首次在 Godot 编辑器打开时可能需要等待 `.godot/imported/` 重新生成缓存。
2. **背景图路径**：背景图实际存放在 `assets/classicPics/backgrounds/levelX/`，而非 `assets/backgrounds/`。
3. **图块数量限制**：当前经典图版最多 42 种图块，全部来自旧版 `bitmap_129.bmp`；如需更多图块，需要新的精灵表资源。
4. **宝可梦图块目录**：`assets/pokemon/normal/` 下固定有 42 张图，游戏通过配置数量按难度限制实际使用的种类数。
5. **棋盘动态变化**：切换难度或图版时会重新创建棋盘格子（`_setup_grid()`），历史记录会清空。

---

### 8. UI 颜色调整：难度/关卡/时间标签分色显示

**时间**：2026-06-30  
**涉及文件**：`game.tscn`、`game.gd`

- 将 `DifficultyLabel`、`LevelLabel`、`TimeLabel` 从 `Label` 改为 `RichTextLabel`，并启用 `bbcode_enabled`。
- 颜色规范：
  - 标签前缀（难度、关卡、总用时、本关用时）使用黄色 `#FFFF00`
  - 难度与关卡后面的内容使用紫蓝色 `#7B68EE`
  - 总用时与本关用时后面的时间使用绿色 `#32CD32`
- 修改 `_update_level_info()` 与 `_update_time_labels()`，使运行时文本也带 BBCode 颜色标签。

### 9. 修复胜利音乐播放

**时间**：2026-06-30  
**涉及文件**：`game.gd`

**问题**：胜利时胜利音乐没有成功播放。原因包括：
- 原本中间关卡胜利播放的是 `LEVEL_VICTORY_SOUND`（短音效），最终关卡又立即用同一个音效播放器播放 `LEVEL_COMPLETE_MUSIC`，导致前者被截断。
- `GAME_WON_SOUND`（`game-won.mp3`）预加载后从未被使用。

**修复**：
- `_on_level_complete()` 中统一使用 `_audio_player` 播放 `GAME_WON_SOUND`。
- `_show_final_victory()` 中停止 `_bgm_player`，并改用 `_bgm_player` 播放 `LEVEL_COMPLETE_MUSIC`，避免与 `_audio_player` 的胜利音效互相覆盖。

### 10. 精简 classicPics：初中高级共用 level3 素材

**时间**：2026-06-30  
**涉及文件**：`assets/连连看例子/extract_tiles.py`、`cell.gd`、`game.gd`、`DEVELOPMENT_LOG.md`

**原因**：`classicPics/level1/` 和 `level2/` 的图块都是 `level3/` 的子集，存在大量重复素材。

**改动**：
- `extract_tiles.py`：不再生成 `level1/` 和 `level2/`，所有经典图块只复制到 `level3/`。
- 删除 `assets/classicPics/level1/` 和 `level2/` 目录。
- `cell.gd`：CLASSIC 皮肤路径固定为 `res://assets/classicPics/level3/normal/tile_%02d.png`，纹理缓存键不再包含 level。
- `game.gd`：`_get_skin_tile_count()` 中 CLASSIC 分支固定读取 `level3/normal/`。
- 背景图仍按难度保留在 `backgrounds/level1~3/`。

### 11. 修复 RichTextLabel 导致的棋盘不显示问题

**时间**：2026-06-30  
**涉及文件**：`game.tscn`

**现象**：打开项目后棋盘不显示，只有菜单和变形的按钮。

**原因**：把 `DifficultyLabel`、`LevelLabel`、`TimeLabel` 改为 `RichTextLabel` 后，默认的 `size_flags` 会让它们过度扩展，挤压甚至挤占棋盘区域，同时把按钮拉成异常形状。

**修复**：为三个 `RichTextLabel` 设置：
- `custom_minimum_size = Vector2(0, 34)`
- `size_flags_horizontal = 0`
- `size_flags_vertical = 0`

使它们只占用必要空间，不再挤压棋盘和按钮。

### 12. 修复欢迎弹窗/结算标签导致的界面卡死问题

**时间**：2026-06-30  
**涉及文件**：`game.tscn`、`game.gd`

**现象**：删除 `.godot/` 重新导入后，屏幕上只显示顶部按钮栏（含「回退」），棋盘不显示，且所有按钮无法点击。

**原因**：
1. `MarginContainer` 下同时存在 `VBoxContainer` 和 `PanelContainer`（GameOverLabel）两个子节点。`MarginContainer` 只应管理一个子节点，第二个子节点的排布行为不稳定，可能挤压或覆盖主界面。
2. `CanvasLayer/CustomDialog` 的背景 `ColorRect` 和内容 `CenterContainer` 使用 `layout_mode = 2` + `size_flags` 进行容器内排布，在某些情况下可能导致弹窗内容不可见，但弹窗本身仍作为全屏控件拦截输入，造成「看得到按钮却点不了」的卡死感。

**修复**：
- 将 `GameOverLabel` 及其外层 `PanelContainer` 从 `MarginContainer` 移出，作为 `CanvasLayer/GameOverPanel` 直接挂在 `CanvasLayer` 下，确保 `MarginContainer` 只包含 `VBoxContainer`。
- `game.gd` 中新增 `game_over_panel` 引用，所有 `game_over_label.show()/hide()` 改为 `game_over_panel.show()/hide()`，文本设置仍保留在 `game_over_label` 上。
- 补充 `GameOverPanel` 的 `unique_name_in_owner = true`，避免 `%GameOverPanel` 引用为空导致运行时报 `Cannot call method 'hide' on a null value`。
- 恢复 `CustomDialog` 原有的 `layout_mode = 2` + `size_flags` 容器排布，避免 anchors 与 PanelContainer 组合可能带来的输入/显示异常。
- 恢复 `HBoxContainer` 中按钮的默认 `size_flags`，移除显式设置为 0 的改动。
- 将 `game.gd` 中所有会被视为错误的整数除法改为显式处理：
  - `_get_pairs()`、`_get_pairs_for_difficulty()` 以及各坍塌函数中的 `/ 2` 改为 `int(x / 2.0)`。
  - `_update_all_cells()` 和 `_index_to_pos()` 中的 `i / cols`、`index / _get_cols()` 改为 `int(float(x) / y)`。
  - `_format_time()` 中的 `/ 3600`、`/ 60` 改为 `/ 3600.0`、`/ 60.0` 后再 `int()`。
  - 这样可兼容「把 INTEGER_DIVISION 警告视为错误」的项目设置，避免脚本加载失败导致点击/按键无响应。
- 在 `project.godot` 的 `[debug]` 段添加 `gdscript/warnings/integer_division=0` 和 `gdscript/warnings/narrowing_conversion=0`，从项目层面忽略这两类不可避免的警告，避免它们被当作错误阻止脚本加载。
- 为 `HBoxContainer` 中的六个按钮和 `ScoreLabel` 添加 `size_flags_vertical = 0`，避免它们在容器中被纵向拉得过高。
- 将 `CanvasLayer/CustomDialog` 的 `Background` 和 `CenterContainer` 从 `layout_mode = 2` + `size_flags` 改为 `layout_mode = 1` + `anchors_preset = 15` 全屏锚定，确保弹窗背景和内容正确铺满视口，避免弹窗内容不可见但拦截输入的情况。
- 为 `MenuBar` 和 `HBoxContainer` 显式设置 `size_flags_vertical = 0` 并添加最小高度，防止它们异常拉伸或把 `BoardCenter` 挤掉。
- 为 `BoardCenter` 添加 `custom_minimum_size = Vector2(0, 100)`，确保棋盘区域至少保留一定高度。
- 移除 `MarginContainer` 中间层，将 `VBoxContainer` 直接挂在 `Game` 下并使用全屏锚定 + offset 实现边距，避免 `MarginContainer` 可能导致的布局异常（菜单栏/棋盘消失）。
- 删除背景图片加载功能：移除 `BackgroundImage` 节点、`background_image` 引用及 `_load_background_image()` 函数和所有调用，保留 `assets/classicPics/backgrounds/` 素材文件不动。

### 13. 修复 RichTextLabel 塌陷导致文字消失与棋盘被挤掉

**时间**：2026-06-30  
**涉及文件**：`game.tscn`

**现象**：菜单栏与按钮仍可点击，但所有文字标签不显示，棋盘区域也未出现。

**原因**：`DifficultyLabel`、`LevelLabel`、`TimeLabel` 使用 `RichTextLabel` 并开启 `fit_content = true`，但未关闭自动换行与滚动。容器布局把它们横向压缩到约 1px 宽，文字被迫纵向换行，导致标签高度异常膨胀（如 `TimeLabel` 高达 1015px）。按钮所在的 `HBoxContainer` 因此被拉得极高，把下方的 `BoardCenter` 棋盘区域挤出可视范围。

**修复**：为三个 `RichTextLabel` 显式添加：
- `autowrap_mode = 0`（关闭自动换行，让 `fit_content` 按单行内容计算宽度）
- `scroll_active = false`（关闭滚动条，避免影响内容尺寸计算）

修复后 `HBoxContainer` 恢复为正常高度（约 55px），文字标签显示正常，棋盘区域重新可见。

---

## 待后续考虑

- [ ] 增加自动测试或启动后的 smoke test
- [ ] 优化高级难度棋盘时间 `MAX_TIME`（当前固定 60 秒）
- [ ] 考虑为经典图案的 selected 状态设计更明显的选中效果（当前 selected 版本为黑色剪影，游戏中使用 `modulate` 高亮）
- [ ] 背景图加载目前按文件名排序选择，可考虑按关卡主题更精细匹配
