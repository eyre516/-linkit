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

### 14. 初始化 Git 仓库并推送至 GitHub

**时间**：2026-06-30  
**涉及文件**：`.gitignore`

**说明**：应要求将项目代码推送到 GitHub 仓库 `https://github.com/eyre516/-linkit.git`。

**操作**：
- 初始化本地 Git 仓库：`git init`
- 添加远程仓库：`origin https://github.com/eyre516/-linkit.git`
- 首次提交并推送主分支
- 修复 `.gitignore`：首次提交时不慎把 `.venv/`（Python 虚拟环境，包含 numpy、PIL 等大量依赖）一起提交；随后将其从 Git 索引中移除，并在 `.gitignore` 中新增 `.venv/`，避免虚拟环境被版本控制

最终仓库中不包含 `.godot/`、`/android/`、`.venv/` 等应由本地生成或重建的目录。

---

### 15. 调整暂停按钮与暂停弹窗文本颜色为柔和红色

**时间**：2026-07-01  
**涉及文件**：`game.tscn`

**原因**：用户希望暂停相关的文字颜色不那么刺眼。

**改动**：
- 顶部按钮 `VBoxContainer/HBoxContainer/PauseButton`：添加 `theme_override_colors/font_color = Color(0.8, 0.25, 0.25, 1)`（第 160 行）。
- 屏幕中央暂停大字 `CanvasLayer/PauseLabel`：其使用的 `LabelSettings_pause` 资源中的 `font_color` 从原来的 `Color(0, 0.35, 0.1, 0.9)` 改为 `Color(0.8, 0.25, 0.25, 0.9)`（第 25 行）。

两处均使用偏暗、低饱和度的红色，并保持暂停大字的半透明效果。

---

### 16. 记录变更报告规范到 AGENTS.md

**时间**：2026-07-01  
**涉及文件**：`AGENTS.md`

**原因**：用户要求以后每次修改代码时，都要明确报告修改的文件、位置和内容。

**改动**：在 `AGENTS.md` 的 `Notes for Agents` 部分新增一条 **Change Reporting** 规范，要求每次代码修改后向用户报告受影响的文件、具体位置以及修改前后的内容。

---

### 17. 优化选中高亮、消除动画、暂停菜单与音量设置

**时间**：2026-07-01  
**涉及文件**：`cell.tscn`、`cell.gd`、`game.tscn`、`game.gd`

**原因**：用户希望实现之前建议的三项优化：选中高亮 + 消除动画、暂停菜单面板 + Esc 暂停、音量设置面板与持久化。

#### 17.1 选中高亮（`cell.tscn`、`cell.gd`）

- `cell.tscn` 第 34-42 行：在 `Cell` 节点下新增 `SelectionHighlight`（`ColorRect`），全屏锚定、`mouse_filter = 2`、颜色 `Color(1, 0.8, 0.2, 0.35)`，初始隐藏。
- `cell.gd` 第 37 行：新增 `@onready var selection_highlight` 引用。
- `cell.gd` 第 42-44 行：新增 `_selection_tween`、`_eliminate_tween` 变量。
- `cell.gd` 第 118-132 行：重写 `_set_selected`，选中时显示高亮层，并给 `TextureRect` 添加 0.12 秒放大到 `1.12` 的补间；取消选中时隐藏高亮并恢复缩放。
- `cell.gd` 第 97-115 行：`_set_tile_type` 中停止消除动画、重置 `TextureRect` 缩放与透明度，并隐藏高亮层。

#### 17.2 消除动画（`cell.gd`、`game.gd`）

- `cell.gd` 第 146-160 行：新增 `play_eliminate_animation()`，使用 Tween 在 0.25 秒内将图标缩放至 0 并淡出，返回 Tween 供外部 `await`。
- `game.gd` 第 137 行：新增 `_is_animating` 状态变量。
- `game.gd` 第 1247-1345 行：重写 `_on_cell_clicked` 的匹配成功分支：
  - 先设置 `_is_animating = true` 并清除选中状态；
  - 对两个匹配格子调用 `play_eliminate_animation()` 并 `await` 动画结束；
  - 再调用 `_eliminate()` 更新棋盘、分数、坍塌；
  - 最后设置 `_is_animating = false`。
- `game.gd` 第 1251、1804、1838、1852、1886 行：在 `_on_cell_clicked`、`_on_undo_button_pressed`、`_on_redo_button_pressed`、`_on_hint_button_pressed`、`_on_shuffle_button_pressed`、`_on_restart_button_pressed` 中增加 `_is_animating` 防护，动画期间禁止这些操作。

#### 17.3 暂停菜单面板 + Esc 暂停（`game.tscn`、`game.gd`）

- `game.tscn` 第 577-632 行：在 `CanvasLayer` 下新增：
  - `PauseDim`（全屏半透明黑色遮罩，`Color(0, 0, 0, 0.5)`）
  - `PauseMenuPanel`（居中的 `PanelContainer`），内部 `VBoxContainer` 包含标题 "游戏已暂停"、按钮 "继续游戏"、`"重新开始本局"`、`"设置"`、隐藏的 `"返回主菜单"`。
- `game.gd` 第 201-211 行：新增 `@onready` 引用 `pause_dim`、`pause_menu_panel` 等。
- `game.gd` 第 252-256 行：在 `_ready` 中连接暂停菜单按钮信号。
- `game.gd` 第 276-279 行：在 `_ready` 中设置新按钮 `focus_mode = FOCUS_NONE`。
- `game.gd` 第 1047-1059 行：修改 `_set_paused`，隐藏旧的 `PauseLabel`，改为显示/隐藏 `PauseDim` 与 `PauseMenuPanel`；恢复游戏时自动关闭设置面板。
- `game.gd` 第 986-1011 行：修改 `_input`：
  - 设置面板打开时按 Esc 关闭设置面板；
  - 自定义弹窗打开时 Esc 关闭弹窗；
  - `KEY_SPACE` 与 `KEY_ESCAPE` 都用于切换暂停；
  - 设置面板打开时屏蔽游戏快捷键。

#### 17.4 音量设置面板与持久化（`game.tscn`、`game.gd`）

- `game.tscn` 第 634-730 行：在 `CanvasLayer` 下新增 `SettingsPanel`（居中的 `PanelContainer`），内部包含：
  - 标题 "设置"
  - 三行音量控制：主音量 / 音效 / 背景音乐，每行含 `Label`、`HSlider`（`0~1`，步进 `0.01`）、百分比 `Label`
  - `CheckButton` "音效"、"背景音乐"
  - "返回" 按钮
- `game.gd` 第 159 行：新增 `SETTINGS_FILE := "user://settings.json"`。
- `game.gd` 第 204-211 行：新增设置面板控件引用。
- `game.gd` 第 258-263 行：在 `_ready` 中连接滑块与复选框信号。
- `game.gd` 第 568-697 行：新增设置相关函数：
  - `_load_settings()` / `_save_settings()`：读写 `user://settings.json`
  - `_apply_settings_to_ui()`：同步滑块、百分比标签、静音开关与 `OptionsMenu` 勾选状态
  - `_on_master_volume_slider_changed` / `_on_sfx_volume_slider_changed` / `_on_bgm_volume_slider_changed`
  - `_on_sfx_mute_toggled` / `_on_bgm_mute_toggled`
  - `_open_settings_panel()` / `_close_settings_panel()`
  - `_on_resume_button_pressed()` / `_on_settings_button_pressed()` / `_on_close_settings_button_pressed()`
- `game.gd` 第 281 行：在 `_ready` 末尾调用 `_load_settings()` 加载持久化设置。
- `game.gd` 第 670-704 行：修改 `OptionsMenu` 的音量/静音菜单处理函数，使其修改后也调用 `_apply_settings_to_ui()` 与 `_save_settings()`，保持两处状态同步。

#### 17.5 弹窗背景不透明化（`game.tscn`）

**时间**：2026-07-01（同日追加）

**原因**：用户反馈暂停菜单和设置面板太透明，文字看不清楚。

**改动**：
- `game.tscn` 第 1 行：`load_steps` 从 `9` 改为 `10`。
- `game.tscn` 第 28-29 行：新增 `StyleBoxFlat_popup_panel`，`bg_color = Color(0.12, 0.12, 0.12, 0.92)`（深灰、92% 不透明度）。
- `game.tscn` 第 599 行：为 `PauseMenuPanel` 添加 `theme_override_styles/panel = SubResource("StyleBoxFlat_popup_panel")`。
- `game.tscn` 第 656 行：为 `SettingsPanel` 添加同样的面板样式。

#### 17.6 加快消除动画速度（`cell.gd`）

**时间**：2026-07-01（同日追加）

**原因**：用户希望消除动画更快一点。

**改动**：`cell.gd` 第 154-155 行，`play_eliminate_animation()` 中缩放和淡出动画的时长从 `0.25` 秒改为 `0.15` 秒。

#### 17.7 弹窗文字放大（`game.tscn`）

**时间**：2026-07-01（同日追加）

**原因**：用户希望各种弹窗里的字再大一些。

**改动**：
- `CanvasLayer/GameOverPanel/GameOverLabel`：新增 `theme_override_font_sizes/font_size = 36`。
- `CanvasLayer/CustomDialog/CenterContainer/VBoxContainer/DialogTitle`：`38` → `48`。
- `CanvasLayer/CustomDialog/CenterContainer/VBoxContainer/DialogContent`：`normal_font_size` `26` → `32`。
- `CanvasLayer/CustomDialog/CenterContainer/VBoxContainer/DialogHint`：`24` → `30`。
- `CanvasLayer/CustomDialog/CenterContainer/VBoxContainer/DialogNameInput`：`custom_minimum_size` 从 `280×40` 改为 `360×50`，新增字体大小 `28`。
- `CanvasLayer/PauseMenuPanel/VBoxContainer/TitleLabel`：`32` → `42`。
- `CanvasLayer/PauseMenuPanel/VBoxContainer` 下四个按钮：新增 `theme_override_font_sizes/font_size = 32`。
- `CanvasLayer/SettingsPanel/VBoxContainer/TitleLabel`：`32` → `42`。
- 设置面板内三个音量标签与三个百分比标签：新增 `theme_override_font_sizes/font_size = 28`。
- 设置面板内两个 `CheckButton`：新增 `theme_override_font_sizes/font_size = 30`。
- `CanvasLayer/SettingsPanel/VBoxContainer/CloseSettingsButton`：新增 `theme_override_font_sizes/font_size = 32`。

**测试情况**：Godot 编辑器未在当前环境安装，无法直接运行；已进行静态检查，未发现明显语法或节点引用错误。建议启动 Godot 后重点验证消除动画、暂停菜单按钮、Esc 快捷键与音量滑块的实时效果。

---

## 待后续考虑

- [ ] 增加自动测试或启动后的 smoke test
- [ ] 优化高级难度棋盘时间 `MAX_TIME`（当前固定 60 秒）
- [ ] 考虑为经典图案的 selected 状态设计更明显的选中效果（当前 selected 版本为黑色剪影，游戏中使用 `modulate` 高亮）
- [ ] 背景图加载目前按文件名排序选择，可考虑按关卡主题更精细匹配

### 18. 统一海洋主题视觉风格

**时间**：2026-07-01  
**涉及文件**：`ocean_theme.tres`（新增）、`game.tscn`、`cell.tscn`、`game.gd`

**原因**：用户希望将整体 UI 统一为大海主题，使用浅蓝海、浅黄沙、珊瑚粉、贝壳白、海鸟喙褐等配色，并用 Theme 资源集中管理按钮、滑块、进度条、面板样式，同时要求按钮具备圆角与 hover/pressed 反馈。

**改动**：

- 新增 `ocean_theme.tres`：
  - 定义完整的 `Theme` 资源，包含 `Button`、`MenuButton`、`ProgressBar`、`HSlider`、`PanelContainer`、`PopupMenu`、`LineEdit`、`Label`、`RichTextLabel`、`CheckButton` 的配色与样式。
  - 按钮使用贝壳白/沙黄色底色 + 海鸟喙褐色边框，圆角半径 8；hover 时边框变为珊瑚粉，pressed 时底色变为海鸟喙褐色、文字变白。
  - 进度条背景为浅海蓝，填充为浅粉色偏红（危险色）。
  - 滑块轨道为浅海蓝，已填充段为珊瑚粉。
  - 面板/弹窗使用贝壳白底色 + 浅海蓝边框，圆角 12–16。
  - 新增两个自定义主题类型：`MenuBarPanel`（浅海蓝底色）与 `BoardPanel`（沙黄色底色）。

- `game.tscn`：
  - 根节点 `Game` 应用 `theme = ExtResource("3_ocean")`。
  - `Background` 颜色从纯黑改为浅海蓝 `Color(0.62, 0.85, 0.93, 1)`。
  - 菜单栏改造：`MenuBar` 从 `HBoxContainer` 改为 `PanelContainer`，内部嵌套 `HBoxContainer`，并设置 `theme_type_variation = "MenuBarPanel"`。
  - 棋盘背景改造：在 `BoardCenter` 与 `AspectRatioContainer` 之间新增 `BoardPanel`（`theme_type_variation = "BoardPanel"`），使棋盘区域呈现沙黄色底板。
  - 移除所有已被主题接管的 `theme_override_styles/...`、`theme_override_colors/...`、`label_settings = SubResource("LabelSettings_score")` 等覆盖。
  - 移除内联的 `Theme_main`、`StyleBoxFlat_timer_bg`、`StyleBoxFlat_timer_fill`、`LabelSettings_score`、`StyleBoxFlat_popup_panel` 子资源，`load_steps` 从 10 调整为 6。
  - `HintLine` 颜色改为珊瑚粉。
  - `PauseLabel` 的 `LabelSettings_pause` 颜色改为浅粉色偏红。
  - `CustomDialog/Background` 与 `PauseDim` 遮罩改为深海蓝半透明，呼应海洋主题。

- `cell.tscn`：
  - 格子 `StyleBoxFlat` 底色改为贝壳白，边框改为海鸟喙褐色，四边圆角半径 8。
  - 选中高亮 `SelectionHighlight` 颜色改为珊瑚粉、不透明度 0.45。

- `game.gd`：
  - `_update_level_info()`：难度/关卡标签前缀改为海鸟喙褐色 `#D4A373`，内容值改为浅海蓝色 `#7EC8E3`。
  - `_update_time_labels()`：时间标签前缀改为海鸟喙褐色，时间值改为贝壳白色 `#FFF8F0`。
  - `_emphasize_score_label()`：分数强调动画的闪烁色改为珊瑚粉，恢复色改为白色，以配合主题默认字体色。

**验证**：
- 使用脚本检查 `game.tscn`、`cell.tscn`、`ocean_theme.tres` 中所有 `SubResource` / `ExtResource` 引用，确认无缺失。
- 当前环境未安装 Godot 编辑器，建议在 Godot 4.5 中打开项目，重点检查菜单栏背景、棋盘沙底板、按钮 hover/pressed 效果以及倒计时进度条颜色是否正确应用。

### 19. 按钮现代化 + 经典棋子去黑底 + 背景统一为浅蓝

**时间**：2026-07-01  
**涉及文件**：`ocean_theme.tres`、`assets/classicPics/level3/normal/tile_*.png`、`game.tscn`

**原因**：用户反馈当前按钮样式仍显古老；经典图版棋子因黑色背景显得暗沉，希望像宝可梦棋子一样整体偏浅；同时要求整个背景统一为浅蓝色，不再保留棋盘中间的沙滩色区域。

**改动**：

- `ocean_theme.tres` 按钮样式重做：
  - 普通态：贝壳白底色 + 海蓝色边框，圆角半径 16（胶囊形），带 4px 柔和投影。
  - 悬停态：海沫蓝底色 + 珊瑚粉边框，投影加深。
  - 按下态：海蓝色底色 + 深海蓝边框，白字，投影收缩，呈现按下凹陷感。
  - 禁用态：灰蓝色扁平样式。
  - 聚焦态：透明底 + 珊瑚粉边框。
  - 同步更新了 `MenuButton`、`PanelContainer`、`PopupMenu`、`LineEdit` 的圆角、边框与投影，使整体风格统一。
  - 文字默认色改为深海蓝 `Color(0.15, 0.28, 0.38)`。
  - `BoardPanel` 自定义类型样式改为全透明，使棋盘区域不再显示沙滩色，完全融入浅蓝背景。
  - `MenuBarPanel` 去掉边框并增加轻微投影，与新的按钮阴影风格协调。

- `assets/classicPics/level3/normal/tile_01.png` ~ `tile_42.png`：
  - 使用 PIL 批量处理，将 RGB 三通道均小于 30 的近黑色像素改为透明。
  - 这样经典棋子的黑色背景被移除，露出下方浅色的格子底板，整体视觉与宝可梦图版更接近。

- `game.tscn`：
  - `BoardPanel` 样式由主题接管为透明，棋盘中间不再出现沙滩色块。

**验证**：
- 脚本检查 `game.tscn`、`cell.tscn`、`ocean_theme.tres` 的资源引用，无缺失。
- 建议启动 Godot 后重点验证：
  - 顶部菜单栏、暂停菜单、设置面板按钮的胶囊圆角与投影是否正常。
  - 切换到经典图版时棋子是否不再呈现黑色方块。
  - 棋盘区域是否与背景一样是浅蓝色，没有中间的沙滩色底板。

### 20. 修复经典棋子去黑底导致的画质损伤

**时间**：2026-07-01  
**涉及文件**：`classic_tile.gdshader`（新增）、`cell.gd`、`assets/classicPics/level3/normal/tile_*.png`

**原因**：第 19 步用 PIL 直接把经典棋子 PNG 的黑底像素改为透明，结果去掉了图案的暗部抗锯齿边缘，导致棋子看起来“画质损伤、图案不清晰”。

**改动**：

- `assets/classicPics/level3/normal/tile_*.png`：
  - 通过 `git checkout HEAD -- assets/classicPics/level3/normal/` 恢复为原始文件，不再修改素材。

- 新增 `classic_tile.gdshader`：
  - 使用 Godot CanvasItem Shader，在渲染时根据像素亮度把深色背景平滑地变为透明。
  - `brightness < 0.10` 完全透明，`brightness > 0.18` 保持原样，中间用 `smoothstep` 过渡，保留原始 PNG 的抗锯齿细节。

- `cell.gd`：
  - 新增常量 `CLASSIC_TILE_SHADER` 预加载 `classic_tile.gdshader`。
  - 新增静态变量 `_classic_material`，所有经典图版格子共用同一个 `ShaderMaterial`。
  - 修改 `update_icon()`：
    - 当 `current_skin == TileSkin.CLASSIC` 时，为 `TextureRect` 赋 `_classic_material`。
    - 当切回宝可梦图版时，把 `material` 置空，避免影响宝可梦棋子。
    - 空白格也同步清空 `material`。

**验证**：
- 静态资源引用检查通过。
- 由于当前环境无 Godot，建议在编辑器里切换到经典图版后观察：棋子边缘是否平滑、图案细节是否清晰、黑底是否已去除。

### 21. 用连通域（flood fill）重新去除经典棋子黑底

**时间**：2026-07-01  
**涉及文件**：`assets/classicPics/level3/normal/tile_*.png`、`cell.gd`、`classic_tile.gdshader`（删除）

**原因**：第 20 步使用 Shader 在渲染时按亮度去除黑底，结果把棋子本身的深色部分也一起变透明了，用户反馈“图案都看不清晰”。需要改用不损伤图案本体的方法重新处理有黑底的原始素材。

**改动**：

- `cell.gd`：
  - 删除 `CLASSIC_TILE_SHADER` 常量、`_classic_material` 静态变量以及 `update_icon()` 中根据皮肤设置 ShaderMaterial 的逻辑。
  - 恢复为最直接的纹理显示方式，不再依赖 Shader。

- `classic_tile.gdshader`：
  - 删除该文件及其 `.uid` 缓存。

- `assets/classicPics/level3/normal/tile_*.png`：
  - 这些文件在第 20 步已恢复为原始黑底版本，现在用 Python + PIL + numpy 重新批量处理：
    1. **连通域识别背景**：从图像四边开始 flood fill，只把与边界相连、且亮度 < 35 的像素标记为背景。这样即使图标内部有深色像素，只要它不连到边界，就会被保留。
    2. **背景完全透明**：被标记为背景的像素 alpha 设为 0。
    3. **边缘平滑过渡**：对非背景但亮度 < 90 的边界像素，按亮度线性计算 alpha，使锯齿感更弱。
  - 处理了 `tile_01.png` 到 `tile_42.png` 共 42 张。

**验证**：
- 随机抽查处理后的 `tile_01.png`、`tile_02.png`、`tile_04.png`、`tile_07.png`，图标主体颜色保留完整，黑色背景已去除。
- 静态资源引用检查通过。
- 建议启动 Godot 后切换到经典图版，重点观察：
  - 棋子图案是否清晰、颜色是否完整。
  - 黑底是否已去除。
  - 边缘是否还有明显锯齿。

### 22. 修复菜单栏按钮悬停时文字截断

**时间**：2026-07-01  
**涉及文件**：`ocean_theme.tres`

**原因**：用户反馈菜单栏的“游戏 / 选项 / 帮助 / 图版”四个 `MenuButton` 在鼠标悬停时，由于 hover 样式增加了 2px 边框，而 normal 样式边框为 0，导致按钮宽度不足以容纳内容，第二个字显示不全。

**改动**：
- 在 `ocean_theme.tres` 的 `StyleBoxFlat_menu_normal`、`StyleBoxFlat_menu_hover`、`StyleBoxFlat_menu_pressed` 中分别增加：
  - `content_margin_left = 10`
  - `content_margin_right = 10`
- 这样每个菜单按钮左右各增加 10 像素内容边距，hover 态的边框不会挤压文字区域，文字可以完整显示。

**验证**：
- 静态资源引用检查通过。
- 建议启动 Godot 后将鼠标移到菜单栏四个选项上，确认悬停时“游戏”“选项”“帮助”“图版”四个字均完整显示。

### 23. 回退一行按钮改回方形

**时间**：2026-07-01  
**涉及文件**：`ocean_theme.tres`、`game.tscn`

**原因**：用户希望顶部工具栏（回退、前进、暂停、重新开始本局、提示、洗牌）的按钮从胶囊形改回方形，而暂停菜单、设置面板等其它按钮保持胶囊形。

**改动**：

- `ocean_theme.tres`：
  - 新增 5 个 `StyleBoxFlat_toolbar_button_*` 子资源，颜色/阴影与现有胶囊按钮一致，但 `corner_radius` 从 16 改为 6，呈现圆角方形。
  - 新增自定义主题类型 `ToolbarButton`，基础类型为 `Button`，并绑定上述方形样式与字体颜色。
  - `load_steps` 从 18 调整为 23。

- `game.tscn`：
  - 为 `UndoButton`、`RedoButton`、`PauseButton`、`RestartButton`、`HintButton`、`ShuffleButton` 分别添加 `theme_type_variation = "ToolbarButton"`。

**验证**：
- 静态资源引用检查通过。
- 建议启动 Godot 后确认：顶部六个按钮为方形，暂停菜单和设置面板内的按钮仍为胶囊形。

### 24. 统一菜单栏及下拉菜单文字颜色

**时间**：2026-07-01  
**涉及文件**：`ocean_theme.tres`

**原因**：用户反馈菜单栏中“选项”等按钮的文字颜色与“游戏”不一致，要求统一。

**改动**：

- `ocean_theme.tres`：
  - `MenuButton/colors/font_pressed_color` 从白色改回深海蓝 `Color(0.15, 0.28, 0.38, 1)`，与 `font_color`、`font_hover_color` 保持一致。
  - `StyleBoxFlat_menu_pressed` 底色从海蓝改为海沫蓝，确保深蓝文字在按下态仍有足够对比度。
  - 新增 `StyleBoxFlat_popup_hover` 子资源，作为下拉菜单项的悬停高亮背景（海沫蓝、小圆角）。
  - 为 `PopupMenu` 设置字体颜色：
    - 普通 / 悬停 / 按下：深海蓝
    - 禁用 / 快捷键：灰蓝色
  - `load_steps` 从 23 调整为 24。

**验证**：
- 静态资源引用检查通过。
- 建议启动 Godot 后观察：
  - 菜单栏四个按钮在常态、悬停、按下态文字均为同一深海蓝色。
  - 点击“选项”“游戏”等打开下拉菜单后，菜单项文字颜色与菜单栏按钮文字一致。

### 25. 移除所有按钮与棋子的边框

**时间**：2026-07-01  
**涉及文件**：`ocean_theme.tres`、`cell.tscn`

**原因**：用户希望所有按钮和棋子（格子）都不要有边框色。

**改动**：

- `ocean_theme.tres`：
  - 移除 `Button`（胶囊按钮）、`ToolbarButton`（方形工具栏按钮）、`MenuButton`（菜单栏按钮）所有状态样式中的 `border_width_*` 和 `border_color`。
  - 焦点态（focus）原本靠边框指示焦点，去掉边框后改为半透明珊瑚色背景 `Color(1, 0.65, 0.7, 0.35)`，确保焦点仍然可见。
  - 面板（PanelContainer、PopupMenu）、输入框（LineEdit）、进度条、滑块等非按钮组件保留原有边框，未作改动。

- `cell.tscn`：
  - 移除格子 `StyleBoxFlat_gwrgs` 中的 `border_width_*` 和 `border_color`，棋子背面改为无边框圆角矩形。

**验证**：
- 静态资源引用检查通过。
- 建议启动 Godot 后确认：
  - 顶部工具栏按钮、暂停菜单按钮、设置面板按钮、菜单栏按钮均无可见边框。
  - 棋盘上的棋子格子没有边框线。

### 26. 分数数字改为醒目主题色

**时间**：2026-07-01  
**涉及文件**：`game.tscn`、`game.gd`

**原因**：用户希望分数标签中“分数：”后面的数字使用更醒目的主题色。

**改动**：

- `game.tscn`：
  - 将 `ScoreLabel` 从 `Label` 改为 `RichTextLabel`。
  - 启用 `bbcode_enabled`，设置 `fit_content = true`、`scroll_active = false`、`autowrap_mode = 0`，并给出默认文本 `[color=#D4A373]分数：[/color][color=#FF8B94]0[/color]`。

- `game.gd`：
  - `@onready var score_label` 类型从 `Label` 改为 `RichTextLabel`。
  - `_update_score_label()` 改用 BBCode：前缀“分数：”使用喙褐色 `#D4A373`，数字使用醒目的浅粉红 `#FF8B94`（主题危险色）。
  - 分数强调动画（`_emphasize_score_label`）保持不变，通过 `modulate` 给整个标签做闪烁后恢复白色。

**验证**：
- 静态资源引用检查通过。
- 建议启动 Godot 后消除棋子，观察分数标签：前缀为喙褐色，数字为亮粉色，加分动画正常。

### 27. 统一加深主题中的浅蓝、浅粉、浅褐色

**时间**：2026-07-01  
**涉及文件**：`ocean_theme.tres`（重新生成）、`game.tscn`、`game.gd`、`cell.tscn`

**原因**：用户反馈当前主题里用到的浅蓝、浅粉、浅褐颜色太浅，希望统一加深一点。

**改动**：

- `ocean_theme.tres`：
  - 重新生成整个主题文件，避免之前颜色调整脚本造成的重复加深和透明色被误改问题。
  - 所有浅蓝、浅粉、浅褐色统一乘以 0.88 加深一次：
    - 浅海蓝 `#7EC8E3` → `#5AB4E0`
    - 海沫蓝 → 对应加深
    - 珊瑚粉 `#FFB6B9` → `#E08787`
    - 危险粉红 `#FF8B94` → `#E07A82`
    - 海鸟喙褐 `#D4A373` → `#BB8F65`
  - 纯白、透明、深色文字、阴影等颜色保持不变。

- `game.tscn`：
  - 背景、暂停大字、提示线、弹窗遮罩等 Color 值同步加深。
  - 默认文本中的 `#FFFF00`、`#6C5CD1`、`#32CD32` 等替换为新的主题色 `#BB8F65`、`#5AB4E0`、`#FFF8F0`。
  - `ScoreLabel` 默认文本颜色同步为 `#BB8F65` / `#E07A82`。

- `game.gd`：
  - 难度/关卡/时间/分数等 BBCode 颜色更新为加深后的主题色。
  - 分数强调动画颜色更新为加深后的珊瑚粉。

- `cell.tscn`：
  - 选中高亮 `SelectionHighlight` 颜色更新为加深后的珊瑚粉 `Color(0.88, 0.628, 0.638, 0.45)`。
  - 格子底色保持贝壳白，未加深。

**验证**：
- 静态资源引用检查通过。
- 建议启动 Godot 后整体观察：背景、菜单栏、按钮、进度条、分数、棋子选中效果是否都比之前深一点点，且没有明显偏色。

---

### 28. 顶部信息栏重新排版

**时间**：2026-07-03  
**涉及文件**：`game.tscn`、`game.gd`

**原因**：原 `MenuBar` 同时塞入菜单、难度/关卡标签和倒计时进度条，层级混乱；进度条固定 320px 宽度在小屏幕上会被挤压；且进度条全程红色，无法体现时间紧迫感的变化。

**改动**：

- `game.tscn`：
  - `MenuBar` 仅保留左侧菜单（游戏 / 选项 / 帮助 / 图版）和右侧总用时 / 分数标签。
  - 新增 `InfoBar`（第三行），从左到右依次放置难度、关卡、剩余对数、倒计时进度条。
  - 按钮行（第二行）重新排序为：回退 / 前进 / 暂停 / 提示 / 洗牌 / 重新开始本局，并移除总用时 / 分数标签。
  - `TimerBar` 移至 `InfoBar`，`size_flags_horizontal = 3` 让其自适应剩余宽度，`custom_minimum_size.x` 从 320 降为 120，避免小屏幕挤压。
  - 为 `TimerBar` 新增 `Gradient` + `GradientTexture2D` + `StyleBoxTexture` 资源，填充样式改为绿 → 黄 → 红渐变，替代原本的单色红色。

- `game.gd`：
  - 新增 `@onready var remaining_pairs_label: RichTextLabel = %RemainingPairsLabel` 引用。
  - 新增 `_update_pairs_label()` 用于刷新“剩余：X”文本。
  - `_update_level_info()` 末尾调用 `_update_pairs_label()`，确保换关/换难度时同步更新。
  - 消除成功后调用 `_update_pairs_label()`，实时反映剩余对数变化。
  - `_update_timer_bar()` 增加最后 10 秒脉冲逻辑：当 `remaining_time <= 10` 且游戏处于运行状态时，启动循环 Tween 改变 `modulate` 产生亮度脉冲；否则停止 Tween 并恢复白色。
  - `_process()` 中改为调用 `_update_timer_bar()`，保证每帧都能正确启停脉冲。
  - `_set_paused()` 末尾调用 `_update_timer_bar()`，暂停/继续时及时停止或恢复脉冲。

**验证**：

- 静态资源引用与节点路径检查通过。
- 建议启动 Godot 后观察：
  - 顶层菜单栏右侧仅显示总用时与分数。
  - 第二行按钮顺序为回退 / 前进 / 暂停 / 提示 / 洗牌 / 重开。
  - 第三行信息栏显示难度、关卡、剩余对数，进度条随窗口宽度自适应。
  - 倒计时进度条颜色从绿色平滑过渡到黄色再到红色；剩余 10 秒时进度条开始闪烁脉冲；暂停时脉冲停止。

**修复**：
- `game.tscn` 中 `Gradient` 子资源 `colors` 属性最初写成 `PackedColorArray(Color(...), Color(...), Color(...))`，Godot 4.5 的 tscn 解析器报 `Expected float in constructor`。
- 已改为扁平浮点数数组：`PackedColorArray(0.2, 0.75, 0.25, 1.0, 1.0, 0.85, 0.0, 1.0, 0.9, 0.2, 0.2, 1.0)`，场景可正常加载运行。

### 29. 调整顶部三行顺序

**时间**：2026-07-03  
**涉及文件**：`game.tscn`

**原因**：用户希望难度/关卡/剩余对数/倒计时进度条位于菜单栏下方（第二行），功能按钮放在第三行。

**改动**：
- 在 `VBoxContainer` 中交换 `InfoBar` 与按钮行 `HBoxContainer` 的节点顺序。
- 现在从上到下依次为：`MenuBar` → `InfoBar`（难度、关卡、剩余、倒计时） → 按钮行（回退、前进、暂停、提示、洗牌、重开） → `BoardCenter`。

**验证**：
- Godot 4.5.1 命令行 `--headless --quit` 可正常加载并打印 `game started!`。

### 30. 为功能按钮添加 Unicode 图标并简化文字

**时间**：2026-07-03  
**涉及文件**：`game.tscn`

**原因**：纯文字按钮显得压迫感较强，用户希望用 Unicode 符号作为图标，并缩短“重新开始本局”为“重开”。

**改动**：
- 按钮行高度从 50 提高到 64，为两行内容留出空间。
- 所有功能按钮文字改为“图标 + 换行 + 文字”：
  - 回退：`↩\n回退`
  - 前进：`↪\n前进`
  - 暂停：`⏸\n暂停`
  - 提示：`💡\n提示`
  - 洗牌：`🔀\n洗牌`
  - 重开：`🔄\n重开`（原“重新开始本局”）

**验证**：
- Godot 4.5.1 命令行 `--headless --quit` 可正常加载并打印 `game started!`。
- 建议启动 Godot 后观察各按钮是否能正确显示 Unicode 图标与文字；若系统字体不支持某些符号，可改用图片图标。

### 31. 按钮图标与文字改为同一行

**时间**：2026-07-03  
**涉及文件**：`game.tscn`

**原因**：用户希望图标和文字在同一行显示，避免换行造成按钮过高。

**改动**：
- 按钮行高度从 64 恢复为 50。
- 所有功能按钮文字由“图标 + 换行 + 文字”改为“图标 + 空格 + 文字”：
  - 回退：`↩ 回退`
  - 前进：`↪ 前进`
  - 暂停：`⏸ 暂停`
  - 提示：`💡 提示`
  - 洗牌：`🔀 洗牌`
  - 重开：`🔄 重开`

**验证**：
- Godot 4.5.1 命令行 `--headless --quit` 可正常加载并打印 `game started!`。

### 32. 修复倒计时进度条红绿方向

**时间**：2026-07-03  
**涉及文件**：`game.tscn`

**原因**：用户反馈倒计时进度条红绿色反了，希望时间充裕时偏绿、时间紧迫时偏红。

**改动**：
- `Gradient_timer` 的颜色顺序从“绿 → 黄 → 红”反转为“红 → 黄 → 绿”。
- ProgressBar 会根据当前 `value` 裁剪/缩放填充纹理：
  - 剩余时间多（`value` 接近满）时显示右侧绿色区域。
  - 剩余时间少（`value` 低）时只显示左侧红色区域。

**验证**：
- Godot 4.5.1 命令行 `--headless --quit` 可正常加载并打印 `game started!`。
- 建议启动 Godot 后观察：倒计时接近 60 秒时进度条主体偏绿，接近 0 秒时偏红。

### 33. 调整顶部信息栏文字颜色

**时间**：2026-07-03  
**涉及文件**：`game.tscn`、`game.gd`

**原因**：用户希望第二行（InfoBar）的浅蓝色数字改为与“游戏”菜单文字同色，第一行和第二行的浅橘色前缀改为褐色。

**改动**：
- 新增颜色：
  - “游戏”二字颜色：`Color(0.150, 0.280, 0.380, 1)`（`#264D61`，深蓝绿）。
  - 褐色：`Color(0.55, 0.36, 0.20, 1)`（`#8C5C33`）。
- `game.tscn`：
  - `TimeLabel`、`ScoreLabel` 前缀 `#BB8F65` → `#8C5C33`。
  - `DifficultyLabel`、`LevelLabel`、`RemainingPairsLabel` 前缀 `#BB8F65` → `#8C5C33`，数字 `#5AB4E0` → `#264D61`。
- `game.gd`：
  - `_update_level_info()` 中难度、关卡标签的前缀和数字颜色同步替换。
  - `_update_pairs_label()` 中“剩余：”前缀和数字颜色同步替换。
  - `_update_time_labels()` 中总用时/本关用时的前缀颜色替换。
  - `_update_score_label()` 中“分数：”前缀颜色替换。
- 弹窗内容中的快捷键说明颜色（`#5AB4E0`）保持不变，不属于顶部一二行。

**验证**：
- Godot 4.5.1 命令行 `--headless --quit` 可正常加载并打印 `game started!`。
- 建议启动 Godot 后观察：第一行和第二行的前缀文字呈褐色，第二行的数字与“游戏”菜单文字同色。

---

### 34. 排行榜分难度标签页与分页显示

**时间**：2026-07-04  
**涉及文件**：`game.tscn`、`game.gd`

**原因**：用户希望排行榜按初级 / 中级 / 高级分成三个可切换的标签页，并且每个难度下的成绩可以分页浏览。

**改动**：

- `game.tscn`：
  - 在 `CanvasLayer/CustomDialog/CenterContainer/VBoxContainer` 下新增 `LeaderboardPanel`（默认隐藏）：
    - `TabRow`：三个按钮 `LeaderboardTab1/2/3`，分别显示“初级 / 中级 / 高级”。
    - `LeaderboardContent`：`RichTextLabel`，用于显示当前难度当前页的成绩列表。
    - `PaginationRow`：`PrevPageButton`、`LeaderboardPageLabel`、`NextPageButton`。
    - `LeaderboardCloseButton`：关闭排行榜弹窗。

- `game.gd`：
  - 常量调整：
    - `LEADERBOARD_MAX_ENTRIES` 从 `10` 改为 `1000`，以支持多页记录。
    - 新增 `LEADERBOARD_ENTRIES_PER_PAGE := 10`。
  - 新增状态：`_leaderboard_difficulty`、`_leaderboard_page`。
  - 新增 `@onready` 引用：`leaderboard_panel`、`leaderboard_content`、`leaderboard_page_label`、`leaderboard_close_button`、`leaderboard_tab_buttons`、`leaderboard_prev_button`、`leaderboard_next_button`。
  - 在 `_ready()` 中连接排行榜标签页、翻页、关闭按钮信号，并设置所有新按钮 `focus_mode = FOCUS_NONE`。
  - 将 `_get_leaderboard_text(difficulty)` 改为 `_get_leaderboard_page_text(difficulty, page)`，仅格式化指定页的记录。
  - 新增 `_show_leaderboard_dialog()`：打开排行榜时默认显示初级第 1 页。
  - 新增 `_update_leaderboard_view()`：根据当前难度与页码刷新内容、页码标签、标签按钮禁用状态、翻页按钮可用状态。
  - 新增 `_on_leaderboard_tab_pressed(difficulty)`：切换难度并重置到第 1 页。
  - 新增 `_on_leaderboard_prev_page_pressed()` / `_on_leaderboard_next_page_pressed()`：翻页并刷新视图。
  - 修改 `_on_options_menu_item_pressed()` 中“排行榜”分支，改为调用 `_show_leaderboard_dialog()`。
  - 修改 `_show_custom_dialog()`：当类型为 `LEADERBOARD` 时隐藏通用 `DialogContent`/`DialogHint`，显示 `LeaderboardPanel`；其他类型则恢复通用内容并隐藏排行榜面板。
  - 修改 `_hide_custom_dialog()`：关闭弹窗时同时隐藏 `LeaderboardPanel`。
  - 修改 `_input()`：排行榜弹窗打开时不响应全局的“按任意键/点击关闭”，让按钮自己处理输入。

**验证**：
- 静态检查节点引用与 GDScript 语法，未发现明显错误。
- 当前环境未安装 Godot，建议启动 Godot 后验证：
  - 点击「选项 → 排行榜」弹出排行榜弹窗，默认显示初级第 1 页。
  - 点击「中级 / 高级」标签可切换难度，页码重置为第 1 页。
  - 当某难度记录超过 10 条时，「下一页」可用，页码显示正确。
  - 点击「关闭」按钮或弹窗外部区域可关闭排行榜并恢复游戏。

---

### 35. 放大排行榜字体

**时间**：2026-07-04  
**涉及文件**：`game.tscn`

**原因**：用户反馈排行榜成绩文字太小，希望参考游戏内字体放大。

**改动**：
- `LeaderboardContent`：
  - `custom_minimum_size` 从 `Vector2(900, 450)` 调整为 `Vector2(900, 500)`，为放大后的文字留出足够空间。
  - 新增 `theme_override_font_sizes/normal_font_size = 32`
  - 新增 `theme_override_font_sizes/bold_font_size = 32`
  - 新增 `theme_override_font_sizes/mono_font_size = 32`
  - 这样标题（`[b]`）、表格正文（`[code]`）和“暂无记录”都使用 32 号字体，与弹窗内容区 `DialogContent` 的字体大小一致。
- 排行榜分页与关闭按钮文字统一放大到 32：
  - `PrevPageButton`：`28` → `32`
  - `LeaderboardPageLabel`：`28` → `32`
  - `NextPageButton`：`28` → `32`
  - `LeaderboardCloseButton`：`30` → `32`

**验证**：
- 静态检查节点属性，无引用错误。
- 建议启动 Godot 后打开排行榜，观察成绩列表、页码、按钮文字是否与游戏内弹窗文字大小一致。

---

### 36. 排行榜列严格对齐表头

**时间**：2026-07-04  
**涉及文件**：`game.gd`

**原因**：用户反馈排行榜每一列的数据没有和最上面的“排名 / 姓名 / 日期 / 用时 / 分数”表头严格对齐。

**改动**：
- 重写 `_get_leaderboard_page_text()` 中的表格生成逻辑：
  - 原先使用空格 + `[code]` 手动模拟表格，表头和数据行的格式字符串列宽不一致，导致错位。
  - 改为使用 RichTextLabel 原生 `[table=5]` 标签：
    - 表头单独一行，5 个单元格分别显示“排名 / 姓名 / 日期 / 用时 / 分数”，并保留原来的金色加粗样式。
    - 每个成绩作为一行，5 个单元格与表头列一一对应。
    - 表格整体包在 `[center]` 中居中显示。
  - 这样每列宽度由该列最宽内容自动决定，数据列会严格与表头列对齐，不再依赖空格估算。

**验证**：
- 静态检查 GDScript 语法与节点引用，未发现明显错误。
- 建议启动 Godot 后打开排行榜，观察：
  - “排名 / 姓名 / 日期 / 用时 / 分数”五个表头是否各自与下方数据在同一垂直线上。
  - 切换不同难度、翻页后是否仍然保持对齐。


---

### 37. 顶部 UI 自动隐藏与悬停恢复

**时间**：2026-07-05  
**涉及文件**：`game.tscn`、`game.gd`

**原因**：用户希望游戏开局后顶部区域更简洁，减少干扰；需要保留关键信息（倒计时、本关用时、分数），并通过鼠标悬停屏幕顶部快速恢复完整菜单。

**改动**：

1. **场景 `game.tscn`**：
   - 新增 `CompactTopBar` 面板（`VBoxContainer/CompactTopBar`），默认隐藏，包含：
     - `CompactTimerBar`：倒计时进度条，与 `InfoBar` 中的进度条共用同一渐变填充样式。
     - `CompactTimeLabel`：仅显示“本关用时”。
     - `CompactScoreLabel`：显示分数。
   - 为 `MenuBar`、`InfoBar` 以及按钮行 `HBoxContainer` 添加 `unique_name_in_owner = true`，便于脚本中统一显示/隐藏。
   - 在根节点 `Game` 下新增 `UIHideTimer`（`Timer`，`one_shot = true`，默认等待 5 秒），用于触发自动隐藏。
   - 在场景底部新增信号连接：`UIHideTimer.timeout -> _on_ui_hide_timer_timeout`。

2. **脚本 `game.gd`**：
   - 新增常量：
     - `AUTO_HIDE_DELAY := 5.0`：开局后多久自动隐藏。
     - `TOP_TRIGGER_HEIGHT := 24.0`：鼠标移到屏幕顶部多少像素内触发恢复。
     - `TOP_HIDE_DELAY := 1.5`：鼠标离开顶部后多久重新隐藏。
   - 新增状态变量 `_ui_hidden`、`_top_leave_time`，以及紧凑进度条脉冲动画引用 `_compact_timer_pulse_tween`。
   - 新增节点引用：`compact_timer_bar`、`compact_time_label`、`compact_score_label`、`menu_bar`、`info_bar`、`toolbar`、`compact_top_bar`、`ui_hide_timer`。
   - 在 `_ready()` 中连接 `ui_hide_timer.timeout`。
   - 在 `_set_paused()` 中同步 `ui_hide_timer.paused`，暂停/继续时计时器不会继续走动。
   - 在 `restart_game()` 中：
     - 重置 `_ui_hidden` 与 `_top_leave_time`。
     - 调用 `_show_full_ui()` 恢复完整顶部 UI。
     - 启动 `ui_hide_timer`（5 秒）。
   - 新增 `_update_ui_visibility(delta)`：
     - 仅在游戏进行中且未暂停时生效。
     - 鼠标位于屏幕顶部 `TOP_TRIGGER_HEIGHT` 以内时，立即恢复完整 UI。
     - 鼠标离开顶部且 5 秒倒计时已结束，经过 `TOP_HIDE_DELAY` 后切换到紧凑 UI。
   - 新增 `_show_compact_ui()` / `_show_full_ui()`：统一控制三行（菜单栏、信息栏、按钮行）与紧凑面板的显隐。
   - 新增 `_update_compact_ui()`：刷新紧凑面板的倒计时条、本关用时与分数。
   - 新增 `_on_ui_hide_timer_timeout()`：5 秒到达后，若鼠标不在屏幕顶部则切换到紧凑 UI。
   - `_update_timer_bar()` 同时同步 `compact_timer_bar`，并为其也添加最后 10 秒脉冲闪烁；新增 `_create_timer_pulse_tween()` 辅助函数避免代码重复。
   - `_update_time_labels()` 与 `_update_score_label()` 同时更新紧凑面板中的 `CompactTimeLabel` 与 `CompactScoreLabel`。
   - 时间耗尽 `_on_time_up()` 与关卡完成 `_on_level_complete()` 时调用 `_show_full_ui()`，确保结束/弹窗状态下完整 UI 可见。

**验证**：
- 静态检查 `game.tscn` 节点结构与 `game.gd` 语法，未发现引用错误。
- 建议启动 Godot 后验证：
  - 开局 5 秒后，菜单栏、难度信息栏、回退/提示/洗牌等按钮行是否隐藏，仅保留顶部紧凑条（倒计时条 + 本关用时 + 分数）。
  - 鼠标移到屏幕最上方时，三行是否在 1 秒内恢复显示。
  - 鼠标离开屏幕顶部超过 1.5 秒后，是否再次进入紧凑模式。
  - 暂停、弹窗、游戏结束或关卡完成时，完整 UI 是否正常显示。


---

### 38. 自动隐藏提示与棋盘边距加倍

**时间**：2026-07-05  
**涉及文件**：`game.tscn`、`game.gd`

**原因**：用户希望在 UI 首次自动隐藏后给出恢复提示，并让棋盘区域距离窗口四周更远一些。

**改动**：

1. **提示功能**：
   - 在 `game.tscn` 的 `CanvasLayer` 中新增 `AutoHideHint` 标签，默认隐藏，位于顶部居中（`anchors_preset = 10`），文字为“将鼠标移到屏幕顶部即可恢复菜单栏”。
   - 在根节点新增 `HintHideTimer`（`Timer`，`one_shot = true`，等待 20 秒）。
   - 在 `game.gd` 中：
     - 新增节点引用 `auto_hide_hint`、`hint_hide_timer`，以及状态变量 `_auto_hide_hint_shown`。
     - 在 `_ready()` 中连接 `hint_hide_timer.timeout`。
     - `_show_compact_ui()` 首次切换到紧凑模式时显示提示并启动 20 秒倒计时；同一局游戏内不会重复显示。
     - `_show_full_ui()` 恢复完整 UI 时立即隐藏提示并停止倒计时。
     - 新增 `_on_hint_hide_timer_timeout()`：20 秒到后自动隐藏提示。
     - `restart_game()` 重置 `_auto_hide_hint_shown = false`，保证每局重新显示一次。

2. **棋盘边距加倍**：
   - 在 `game.tscn` 中把 `VBoxContainer` 的四周偏移从 `4.0` 改为 `8.0`：
     - `offset_left`：`4.0` → `8.0`
     - `offset_top`：`4.0` → `8.0`
     - `offset_right`：`-4.0` → `-8.0`
     - `offset_bottom`：`-4.0` → `-8.0`
   - 这样整个游戏内容区（含棋盘）距离窗口四周的边距从 4 像素变为 8 像素，即原来的 2 倍。

**验证**：
- 静态检查 `game.tscn` 节点属性与 `game.gd` 语法，未发现引用错误。
- 建议启动 Godot 后验证：
  - 开局 5 秒后进入紧凑模式时，是否出现“将鼠标移到屏幕顶部即可恢复菜单栏”提示。
  - 提示是否在显示 20 秒后自动消失，或在鼠标移到顶部恢复完整 UI 时立即消失。
  - 棋盘四周是否比原来有更多留白（从 4px 增加到 8px）。


---

### 39. 恢复提示每局显示三次

**时间**：2026-07-05  
**涉及文件**：`game.gd`

**原因**：用户反馈每局游戏只显示一次自动隐藏恢复提示不够明显，希望增加到三次。

**改动**：
- 将布尔变量 `_auto_hide_hint_shown` 改为计数变量 `_auto_hide_hint_count`。
- 新增常量 `AUTO_HIDE_HINT_MAX := 3`。
- `_show_compact_ui()` 中，只要本局进入紧凑模式的次数不超过 3 次，就显示 20 秒提示；每次显示时计数加 1。
- `restart_game()` 中重置 `_auto_hide_hint_count = 0`。

**验证**：
- 静态检查 GDScript 语法与逻辑，未发现错误。
- 建议启动 Godot 后验证：
  - 同一局游戏中，前 3 次进入紧凑模式时是否每次都出现恢复提示。
  - 第 4 次及以后进入紧凑模式时是否不再显示提示。
  - 重新开始一局后，提示次数是否重新累计。


---

### 40. 仅底部边距加倍

**时间**：2026-07-05  
**涉及文件**：`game.tscn`

**原因**：用户希望只增加棋盘/游戏区域到底部的距离，左右和顶部保持当前 8 像素不变。

**改动**：
- `VBoxContainer` 的 `offset_bottom` 从 `-8.0` 改为 `-16.0`，底部边距由 8 像素增加到 16 像素（即当前值的两倍）。
- `offset_left`、`offset_top`、`offset_right` 保持 `8.0` / `-8.0` 不变。

**验证**：
- 静态检查场景文件，节点引用正确。
- 建议启动 Godot 后观察：游戏区域左右和顶部留白与之前一致，只有底部到窗口下边缘的距离明显变大。


---

### 41. 底部边距调整为 1.5 倍

**时间**：2026-07-05  
**涉及文件**：`game.tscn`

**原因**：用户希望进一步调整底部边距为当前值的 1.5 倍。

**改动**：
- `VBoxContainer` 的 `offset_bottom` 从 `-16.0` 改为 `-24.0`，底部边距由 16 像素增加到 24 像素（即 16 像素的 1.5 倍）。
- 左、右、顶部边距保持不变。

**验证**：
- 静态检查场景文件，节点引用正确。
- 建议启动 Godot 后观察底部留白是否符合预期。


---

### 42. 恢复提示改为左侧竖排大字

**时间**：2026-07-05  
**涉及文件**：`game.tscn`、`game.gd`

**原因**：用户希望恢复提示以竖排形式显示在屏幕左侧，并放大字体。

**改动**：

1. **场景 `game.tscn`**：
   - 将 `CanvasLayer/AutoHideHint` 从 `Label` 改为 `RichTextLabel`。
   - 文字改为每个汉字独占一行，实现竖排效果：
     ```
     将
     鼠
     标
     移
     到
     屏
     幕
     顶
     部
     即
     可
     恢
     复
     菜
     单
     栏
     ```
   - 锚点设为左侧居中（`anchors_preset = 9`），`offset_left = 16.0`，整体位于屏幕左侧。
   - 字体大小从 20 提高到 36（`theme_override_font_sizes/normal_font_size = 36`）。
   - 开启 `bbcode_enabled` 并给文字加上浅色（`#FFF8F0`），保证在各种背景下可读。

2. **脚本 `game.gd`**：
   - 将 `auto_hide_hint` 的变量类型从 `Label` 改为 `RichTextLabel`，与场景节点类型一致。

**验证**：
- 静态检查场景节点与脚本引用类型一致，未发现错误。
- 建议启动 Godot 后验证：
  - 提示是否以竖排大字显示在屏幕左侧居中位置。
  - 字体大小是否明显比原来大。
  - 提示在 20 秒或恢复完整 UI 后是否正常消失。


---

### 43. 恢复提示显示时间改为 15 秒

**时间**：2026-07-05  
**涉及文件**：`game.tscn`、`game.gd`

**原因**：用户希望自动隐藏后的恢复提示显示时间从 20 秒缩短为 15 秒。

**改动**：
- `game.tscn` 中 `HintHideTimer` 的 `wait_time` 从 `20.0` 改为 `15.0`。
- `game.gd` 中 `_show_compact_ui()` 启动提示隐藏计时器的时间从 `20.0` 秒改为 `15.0` 秒。

**验证**：
- 静态检查场景与脚本数值一致。
- 建议启动 Godot 后验证：进入紧凑模式后，左侧竖排提示是否在 15 秒后自动消失。


---

### 44. 恢复提示改回每局显示一次

**时间**：2026-07-05  
**涉及文件**：`game.gd`

**原因**：用户希望恢复提示仍保持每局游戏只显示一次。

**改动**：
- 将 `AUTO_HIDE_HINT_MAX` 从 `3` 改回 `1`。
- `_show_compact_ui()` 中注释从“每局前 3 次”改为“每局首次”。

**验证**：
- 静态检查逻辑正确。
- 建议启动 Godot 后验证：同一局游戏中无论进入紧凑模式多少次，左侧竖排提示只出现一次；重新开始后再次显示一次。


---

### 45. 恢复提示改为闪烁三次后消失

**时间**：2026-07-05  
**涉及文件**：`game.gd`

**原因**：用户不希望提示长时间停留，而是希望它以闪烁方式提醒玩家。

**改动**：
- 新增 `_hint_flash_tween: Tween = null` 用于控制提示闪烁动画。
- `_show_compact_ui()` 中：
  - 首次进入紧凑模式时显示提示。
  - 使用 Tween 让提示的 `modulate:a` 在 0.2 和 1.0 之间来回变化，循环 3 次（约 1.5 秒）。
  - 动画结束后自动隐藏提示并恢复其透明度。
  - 停止 `hint_hide_timer`，不再按固定秒数隐藏提示。
- `_show_full_ui()` 中：
  - 隐藏提示并恢复透明度。
  - 若闪烁动画仍在进行，立即终止它。

**验证**：
- 静态检查 GDScript 语法与逻辑，未发现错误。
- 建议启动 Godot 后验证：
  - 首次进入紧凑模式后，左侧竖排提示是否快速闪烁 3 次然后消失。
  - 闪烁过程中若鼠标移到顶部恢复完整 UI，提示是否立即消失且动画停止。


---

### 46. 欢迎弹窗彩色加粗字与附近文字同大

**时间**：2026-07-05  
**涉及文件**：`game.tscn`

**原因**：用户反馈游戏开始时的欢迎/规则弹窗中，带颜色且加粗的文字（如快捷键、规则标题）与周围普通文字大小不一致。

**改动**：
- 为 `CanvasLayer/CustomDialog/CenterContainer/VBoxContainer/DialogContent` 显式设置：
  - `theme_override_font_sizes/bold_font_size = 32`
- 这样 RichTextLabel 中加粗文字（`[b]`）的字号与常规文字（`normal_font_size = 32`）完全相同，消除了彩色加粗字比附近文字大或小的视觉差异。

**验证**：
- 静态检查场景文件，节点属性正确。
- 建议启动 Godot 后打开欢迎弹窗，观察“游戏规则”“T / 鼠标右键”“2 个转弯”等彩色加粗文字是否与周围普通文字大小一致。


---

### 47. 恢复提示闪烁变慢并停留 5 秒

**时间**：2026-07-05  
**涉及文件**：`game.tscn`、`game.gd`

**原因**：用户希望提示闪烁更慢，且闪烁结束后保持显示一段时间再消失。

**改动**：

1. **脚本 `game.gd`**：
   - `_show_compact_ui()` 中：
     - 每次闪烁的淡出/淡入时间从 0.25 秒延长到 0.75 秒，单次完整闪烁（淡出 + 淡入）从 0.5 秒变为 1.5 秒。
     - 闪烁 3 次后，不再立即隐藏，而是启动 `hint_hide_timer` 停留 5 秒。
   - `_on_hint_hide_timer_timeout()`：
     - 5 秒停留结束后隐藏提示并恢复透明度。
   - 注释同步更新为“闪烁 3 次后再停留 5 秒”。

2. **场景 `game.tscn`**：
   - `HintHideTimer` 的 `wait_time` 从 `15.0` 改为 `5.0`，与代码中停留时间一致。

**验证**：
- 静态检查场景与脚本数值一致，未发现错误。
- 建议启动 Godot 后验证：
  - 首次进入紧凑模式后，左侧竖排提示是否以较慢速度闪烁 3 次。
  - 闪烁结束后是否继续显示 5 秒再消失。
  - 提示显示期间若鼠标移到顶部恢复完整 UI，提示是否立即停止并隐藏。


---

### 48. 消除成功时显示连接路径

**时间**：2026-07-05  
**涉及文件**：`game.tscn`、`game.gd`

**原因**：用户希望在成功连接两个图块时，能看到具体的连接路径，效果与提示的粉线一致。

**改动**：

1. **场景 `game.tscn`**：
   - 在 `CanvasLayer` 中新增 `MatchLine`（`Line2D`），样式与 `HintLine` 相同：
     - `width = 4.0`
     - `default_color = Color(0.88, 0.628, 0.638, 1)`

2. **脚本 `game.gd`**：
   - 新增节点引用 `@onready var match_line: Line2D = %MatchLine`。
   - 在 `_on_cell_clicked()` 中，确认两个图块可以连通后：
     - 调用 `_find_connection_path(r1, c1, r, c)` 获取连接路径。
     - 用 `_extended_to_screen()` 把路径上的扩展坐标转换为屏幕坐标。
     - 赋值给 `match_line.points`，立即画出连接路径。
   - 消除动画播放完毕后，清空 `match_line.points`，让路径消失。

**验证**：
- 静态检查场景节点与脚本引用正确，未发现错误。
- 建议启动 Godot 后验证：
  - 点击两个可连通的相同图块时，是否立即出现一条与提示粉线同色的连接线。
  - 连接线是否贯穿两个图块之间的实际路径（含外圈虚拟空白）。
  - 消除动画结束后，连接线是否同步消失。


---

### 49. 加分可视化反馈（方案 1/2/3）

**时间**：2026-07-05  
**涉及文件**：`game.tscn`、`game.gd`

**原因**：用户希望玩家能潜移默化地感知到不同情况加分不同，既不明显打扰游戏，又能清晰看到得分变化。

**改动**：

1. **场景 `game.tscn`**：
   - 在 `CanvasLayer` 新增 `ScorePopup`（`Label`），用于方案 1 的消除位置飘字。
   - 在 `CanvasLayer` 新增 `ScoreGainLabel`（`RichTextLabel`），用于方案 2 在分数标签旁显示 `+N`。
   - 在 `VBoxContainer/InfoBar/HBoxContainer` 新增 `ComboLabel`（`RichTextLabel`）。
   - 在 `VBoxContainer/CompactTopBar/HBoxContainer` 新增 `CompactComboLabel`（`RichTextLabel`）。

2. **脚本 `game.gd`**：
   - 新增常量：
     - `SCHEME_1_FLOATING_TEXT_ENABLED := true`：方案 1 总开关，便于后续单独关闭或移除。
     - `COMBO_FAST_THRESHOLD := 5.0`：5 秒内消除算一次连击。
     - `COMBO_MAX_DISPLAY := 5`：连击显示上限。
     - 分数等级颜色：`SCORE_COLOR_GOLD`（30 分）、`SCORE_COLOR_SILVER`（20 分）、`SCORE_COLOR_BRONZE`（15 分）、`SCORE_COLOR_NORMAL`（其他）。
   - 新增状态变量：
     - `_last_points: int`：最近一次消除获得的分数。
     - `_combo_count: int`：当前连击次数。
   - 新增节点引用：`score_popup`、`score_gain_label`、`combo_label`、`compact_combo_label`。
   - 修改 `_eliminate()`：
     - 计算分数后保存到 `_last_points`。
     - 根据消除间隔更新 `_combo_count`：5 秒内连击 +1，否则重置为 1。
     - 调用 `_update_combo_display()`。
     - 调用 `_emphasize_score_label(points)`，传入分数以决定脉冲颜色。
   - 修改 `_on_cell_clicked()`：
     - 消除计分后，计算两个被消除格子的中点，调用 `_show_score_feedback(_last_points, mid_point)`。
   - 新增 `_show_score_feedback(points, match_midpoint)`：
     - 方案 1：调用 `_spawn_floating_score()` 在消除位置飘出带等级色的 `+N`。
     - 方案 2：在可见的分数标签（`score_label` 或 `compact_score_label`）右侧弹出 `+N`，同时向上飘动淡出。
   - 新增 `_spawn_floating_score(points, pos)`：
     - 设置飘字内容、颜色、位置，向上移动 50 像素并逐渐透明，1 秒后消失。
   - 修改 `_emphasize_score_label(points)`：
     - 根据分数返回等级色。
     - 脉冲当前可见的分数标签（完整模式用 `score_label`，紧凑模式用 `compact_score_label`）。
   - 新增 `_update_combo_display()`：
     - 连击大于 1 时，在 `ComboLabel` 和 `CompactComboLabel` 显示“连击 xN”。
     - 连击为 1 或以下时清空文本。
   - 新增 `_get_score_tier_color(points)`：根据分数返回对应等级颜色。
   - `restart_game()` 中重置 `_combo_count = 0` 并刷新连击显示。
   - 撤销/重做时重置连击计数，避免时间倒流后连击逻辑不一致。

**验证**：
- 静态检查场景节点与脚本引用、类型一致，未发现明显错误。
- 建议启动 Godot 后验证：
  - 快速消除（3 秒内）时，棋盘中间是否飘出金色 `+30`，分数标签右侧是否也出现金色 `+30`，分数标签是否金色脉冲。
  - 较慢消除时，飘字和标签弹出是否变为银/铜/白色。
  - 连续 5 秒内消除时，顶部是否出现“连击 x2/x3...”。
  - 将 `SCHEME_1_FLOATING_TEXT_ENABLED` 设为 `false` 后，方案 1 的飘字是否消失，方案 2/3 是否仍然工作。


---

### 50. 加分与连击提示加大加鲜艳

**时间**：2026-07-05  
**涉及文件**：`game.tscn`、`game.gd`

**原因**：用户反馈加分飘字、分数旁弹出提示和连击标签不够醒目，希望字号更大、颜色更鲜艳厚重。

**改动**：

1. **脚本 `game.gd`**：
   - 调整分数等级颜色，全部改为更亮更饱和的色号：
     - 30 分金色：`#E0B45A` → `#FFD700`
     - 20 分银色：`#C0C0C0` → `#E0E0E0`
     - 15 分铜色：`#CD7F32` → `#FF8C00`
     - 其他白色：`#FFF8F0` → `#FFFFFF`
   - `ScoreGainLabel` 弹出文字加 `[b]` 粗体。
   - 连击标签文字使用新的金色常量并加粗：`[color=#FFD700][b]连击 xN[/b][/color]`。

2. **场景 `game.tscn`**：
   - `ScorePopup`：
     - 字号 `28` → `40`。
     - 增加黑色描边：`outline_size = 5`，让飘字在复杂背景上更清晰。
     - 尺寸调整为 `100×50`。
   - `ScoreGainLabel`：
     - 字号 `26` → `32`。
     - `bold_font_size` 同样设为 `32`。
     - 尺寸调整为 `90×40`。
   - `ComboLabel` / `CompactComboLabel`：
     - `custom_minimum_size` 高度 `34` → `40`。
     - 字号 `normal_font_size` 和 `bold_font_size` 都设为 `28`。
     - 默认示例文字改为 `[color=#FFD700][b]连击 x2[/b][/color]`。

**验证**：
- 静态检查场景与脚本，引用和 BBCode 格式正确。
- 建议启动 Godot 后验证：
  - 消除时飘出的 `+30/+20` 等是否字号明显变大、带黑色描边、颜色更亮。
  - 分数标签旁的 `+N` 是否更大更粗。
  - 连击时顶部“连击 xN”是否更大、金色更鲜艳。


---

### 51. 快速连击时飘字显示优化

**时间**：2026-07-05  
**涉及文件**：`game.tscn`、`game.gd`

**原因**：用户反馈连击间隔较短时，飘动的加分文字很快就被下一个覆盖或消失，玩家看不清每次得了多少分。

**改动**：

1. **飘字池化（避免互相覆盖）**：
   - `game.tscn` 中新增 `ScorePopup2`、`ScorePopup3`，与原有 `ScorePopup` 组成 3 个飘字实例。
   - `game.gd` 中把单个 `score_popup` 引用改为 `score_popups: Array[Label]`，并添加循环索引 `_score_popup_index` 和 Tween 池 `_score_popup_tweens`。
   - 每次生成飘字时轮询使用下一个实例；若该实例仍有旧动画，先 `kill()` 旧动画再启动新的。

2. **连击越快停留越久**：
   - 在 `_spawn_floating_score()` 中根据当前 `_combo_count` 动态调整停留和淡出时间：
     - 0-1 连击：停留 0.3 秒，淡出 0.7 秒（总计 1.0 秒）。
     - 2-3 连击：停留 0.6 秒，淡出 0.9 秒（总计 1.5 秒）。
     - 4+ 连击：停留 1.0 秒，淡出 1.0 秒（总计 2.0 秒）。
   - 动画分为两段：先保持满透明度停留，再向上飘动淡出，让玩家有足够时间看清分数。

3. **初始化**：
   - 在 `_ready()` 中为 `_score_popup_tweens` 分配与飘字实例数量相同的空间，并初始化为 `null`。

**验证**：
- 静态检查场景节点与脚本引用、Tween 链式调用，未发现明显错误。
- 建议启动 Godot 后快速连续消除，观察：
  - 多个 `+30/+20` 是否能同时或依次显示，而不是互相覆盖。
  - 连击越高，飘字是否在屏幕上停留更久。
  - 慢速消除时，飘字是否保持原来的短暂显示节奏。


---

### 52. 飘字停留缩短与连击逻辑改进

**时间**：2026-07-05  
**涉及文件**：`game.gd`

**原因**：用户希望飘字不要停留太久，同时连击逻辑更合理：10 秒内算连击、无上限、超过 10 秒清零。

**改动**：

1. **飘字停留时间整体减短 0.3 秒**：
   - 0-1 连击：`0.3 秒停留 + 0.7 秒淡出` → `0.0 秒停留 + 0.7 秒淡出`。
   - 2-3 连击：`0.6 秒停留 + 0.9 秒淡出` → `0.3 秒停留 + 0.9 秒淡出`。
   - 4+ 连击：`1.0 秒停留 + 1.0 秒淡出` → `0.7 秒停留 + 1.0 秒淡出`。

2. **连击判定窗口改为 10 秒**：
   - `COMBO_FAST_THRESHOLD` 从 `5.0` 改为 `10.0`。
   - `_eliminate()` 中注释同步更新。

3. **连击数无上限**：
   - 移除 `COMBO_MAX_DISPLAY` 常量。
   - `_update_combo_display()` 直接显示真实的 `_combo_count`，不再做上限截断。

4. **超过 10 秒未消除自动清零**：
   - 在 `_process()` 中增加判断：若距离上次消除已超过 10 秒且连击数不为 0，则将 `_combo_count` 置 0 并刷新显示。

**验证**：
- 静态检查 GDScript 语法与逻辑，未发现错误。
- 建议启动 Godot 后验证：
  - 普通消除时飘字是否更快消失。
  - 连续 10 秒内消除是否一直累计连击数（如 x6、x7）。
  - 停止消除超过 10 秒后，顶部“连击 xN”是否自动清空。


---

### 53. 左侧恢复提示更醒目

**时间**：2026-07-05  
**涉及文件**：`game.tscn`、`game.gd`

**原因**：用户希望左侧竖排恢复提示更显眼、颜色更突出。

**改动**：

1. **场景 `game.tscn`**：
   - 新增 `AutoHideHintBg`（`ColorRect`）作为提示背景，半透明深色，位于提示文字后方，增强可读性。
   - `AutoHideHint`：
     - 字号从 `36` 提升到 `42`。
     - 文字颜色改为亮金色 `#FFD700`。
     - 增加 `6` 像素黑色描边，让文字在任何背景下都清晰。
     - 文字加粗。

2. **脚本 `game.gd`**：
   - 新增 `auto_hide_hint_bg` 节点引用。
   - `_show_compact_ui()` 显示提示时同步显示背景。
   - 闪烁动画增强：除了透明度变化，还加入了 `1.0 → 1.08 → 1.0` 的缩放脉冲，让提示更有“跳动”感。
   - 背景透明度随提示一起闪烁。
   - `_show_full_ui()` 与 `_on_hint_hide_timer_timeout()` 中同步隐藏背景，并恢复提示的缩放与透明度。

**验证**：
- 静态检查场景节点与脚本引用正确，Tween 链式调用无误。
- 建议启动 Godot 后验证：
  - 首次进入紧凑模式时，左侧是否出现带深色背景、亮金色描边大字的竖排提示。
  - 提示闪烁时是否有明显的缩放脉冲效果。
  - 恢复完整 UI 或 5 秒停留结束后，提示和背景是否一起消失。


---

### 54. 左侧恢复提示字号缩小、背景与文字契合

**时间**：2026-07-05  
**涉及文件**：`game.tscn`、`game.gd`

**原因**：用户反馈提示字号偏大，且背景比文字小、不够贴合。

**改动**：

1. **场景 `game.tscn`**：
   - `AutoHideHint` 字号从 `42` 调回 `38`。
   - 描边从 `6` 像素减为 `5` 像素。
   - 将 `AutoHideHintBg` 从 `CanvasLayer` 下移动到 `CanvasLayer/AutoHideHint` 下，作为文字的子节点。
   - 背景使用 `anchors_preset = 15` 填充父节点，并设置四周 `8` 像素外扩（`offset_left = -8`, `offset_top = -8`, `offset_right = 8`, `offset_bottom = 8`），确保背景始终比文字区域大一圈且自动适配文字高度。

2. **脚本 `game.gd`**：
   - 移除 `auto_hide_hint_bg` 引用及相关独立的显示/隐藏/透明度控制代码。
   - 闪烁动画仅控制 `AutoHideHint` 本身；背景作为子节点会自动跟随显示、隐藏和透明度变化。
   - `_show_full_ui()` 与 `_on_hint_hide_timer_timeout()` 中同步恢复提示的透明度和缩放。

**验证**：
- 静态检查场景父子关系与脚本引用正确。
- 建议启动 Godot 后验证：
  - 左侧竖排提示字号是否比上一版稍小、更协调。
  - 深色背景是否完整包裹所有文字，且随文字高度自动调整。
  - 提示闪烁、消失时背景是否与文字同步。


---

### 55. 移除左侧恢复提示背景

**时间**：2026-07-05  
**涉及文件**：`game.tscn`

**原因**：用户反馈深色背景太黑、遮挡后面内容，影响查看。

**改动**：
- 从 `game.tscn` 中删除 `CanvasLayer/AutoHideHint/AutoHideHintBg` 节点。
- 保留金色加粗文字与黑色描边，确保在没有背景的情况下仍能看清。

**验证**：
- 静态检查场景节点引用正确。
- 建议启动 Godot 后验证：左侧恢复提示是否只保留金色大字和黑色描边，不再有深色背景板。


---

### 56. 恢复提示闪烁不变暗

**时间**：2026-07-05  
**涉及文件**：`game.gd`

**原因**：用户反馈提示闪烁时文字会变暗、变糊，影响阅读。

**改动**：
- `_show_compact_ui()` 中的闪烁动画移除所有透明度（`modulate:a`）变化。
- 改为仅通过缩放脉冲提醒：文字从 `1.0` 放大到 `1.08` 再缩回 `1.0`，循环 3 次。
- 文字始终保持原来的亮金色和黑色描边，不会变暗或变糊。

**验证**：
- 静态检查 Tween 调用正确。
- 建议启动 Godot 后验证：左侧恢复提示闪烁时，文字是否依然清晰明亮，只有大小在轻微脉动。


---

### 57. 恢复提示字体变细更清晰

**时间**：2026-07-05  
**涉及文件**：`game.tscn`

**原因**：用户希望左侧恢复提示的字更细、更清晰。

**改动**：
- `AutoHideHint` 文字移除 `[b]` 粗体，改用普通字重。
- 描边从 `5` 像素减为 `3` 像素，避免描边过粗导致字迹显糊。
- 删除不再需要的 `bold_font_size` 覆盖。

**验证**：
- 静态检查场景节点与 BBCode 格式正确。
- 建议启动 Godot 后验证：左侧恢复提示文字是否更细、描边更细、整体更清晰。


---

### 58. 飘字位置改为第二个选中格子

**时间**：2026-07-05  
**涉及文件**：`game.gd`

**原因**：用户希望加分飘字显示在第二次点击的格子位置，而不是两个格子的中间。

**改动**：
- `_on_cell_clicked()` 中，飘字位置从“两个消除格子的中点”改为“第二个点击格子（`cell2`）的中心点”。

**验证**：
- 静态检查逻辑正确。
- 建议启动 Godot 后验证：成功消除时，`+30/+20` 等飘字是否从第二次点击的格子处升起。


---

### 59. 恢复提示改为两列大字显示

**时间**：2026-07-05  
**涉及文件**：`game.tscn`

**原因**：用户希望左侧恢复提示字号更大，并且分两列显示，断句要合理。

**改动**：
- `AutoHideHint` 字号从 `38` 提升到 `44`。
- 使用 RichTextLabel 的 `[table=2]` 将提示分为两列竖排：
  - 左列：`将鼠标移到屏幕顶部`
  - 右列：`即可恢复菜单栏`
- 按语义断句，左列说明操作，右列说明结果，既平衡又易读。
- 调整 `AutoHideHint` 的垂直范围（`offset_top = -250`, `offset_bottom = 250`）和宽度（`offset_right = 150`），以适应两列布局。

**验证**：
- 静态检查场景 BBCode 格式正确。
- 建议启动 Godot 后验证：左侧恢复提示是否以更大的字号、两列竖排显示，断句是否自然。


---

### 60. 恢复提示“屏幕顶部”加粗

**时间**：2026-07-05  
**涉及文件**：`game.tscn`

**原因**：用户希望左侧恢复提示中的“屏幕顶部”四个字更加醒目。

**改动**：
- 在 `AutoHideHint` 的左列中，把“屏幕顶部”四个字用 `[b]...[/b]` 包裹，使其加粗显示。
- 新增 `bold_font_size = 44`，确保加粗字与正常字号一致。
- 其余文字保持原来的普通字重和金色描边样式。

**验证**：
- 静态检查场景 BBCode 格式正确。
- 建议启动 Godot 后验证：左侧恢复提示中“屏幕顶部”是否比周围文字更粗更醒目。


---

### 61. “屏幕顶部”改为加粗黑边

**时间**：2026-07-05  
**涉及文件**：`game.tscn`

**原因**：用户希望“屏幕顶部”四个字不使用粗体，而是通过更粗的黑边来突出。

**改动**：
- 移除“屏幕顶部”的 `[b]` 加粗标签。
- 为“屏幕顶部”单独嵌套 `[outline_size=6][outline_color=#000000]...[/outline_color][/outline_size]`，使其黑边比周围文字（`outline_size=3`）更粗。
- 删除不再使用的 `bold_font_size` 覆盖。

**验证**：
- 静态检查场景 BBCode 格式正确。
- 建议启动 Godot 后验证：左侧恢复提示中“屏幕顶部”是否以更粗的黑边突出显示，而字体粗细与周围一致。


---

### 62. 修复导出后图版只剩一个图案的 Bug

**时间**：2026-07-13  
**涉及文件**：`cell.gd`、`game.gd`

**原因**：`cell.gd` 原本使用动态 `load(path)` 根据 `tile_type` 运行时加载 `assets/pokemon/normal/tile_%02d.png` 或 `assets/classicPics/level3/normal/tile_%02d.png`。Godot 的导出依赖扫描只会把“显式引用”的资源打包进 PCK，动态拼接路径的 `load()` 不会被识别；导出后这些图块文件经常只有少量（甚至只有 1 张）被包含。结果表现为：
- 经典图版在导出后整局只出现同一种图案；
- 若 `game.gd` 通过 `DirAccess` 扫描目录，导出后也可能只能数到少量 `.png`，进一步导致棋盘生成时 `tile_count` 变成 1。

**改动**：
- 在 `cell.gd` 中用 `preload()` 显式预加载两套图版全部 42 张纹理（`POKEMON_TEXTURES`、`CLASSIC_TEXTURES`），并建立 `SKIN_TEXTURES` 映射表。
- `_get_texture()` 改为从预加载数组中按索引取值，不再使用运行时 `load()`。
- 新增 `Cell.get_texture_count(skin)` 静态方法，供外部查询当前图版实际可用的纹理数量。
- 在 `game.gd` 的 `_get_skin_tile_count()` 中：
  - 经典图版直接返回 `Cell.get_texture_count(Cell.TileSkin.CLASSIC)`，不再依赖导出后可能不可靠的 `DirAccess` 目录扫描。
  - 宝可梦图版返回 `mini(POKEMON_LEVELS[difficulty]["tile_count"], Cell.get_texture_count(Cell.TileSkin.POKEMON))`，防止配置数量超过实际打包的纹理数量。

**验证**：
- 静态检查 `cell.gd` 中 84 条 `preload` 路径与项目目录一致。
- 建议重新导出 Windows Desktop 版本后验证：
  - 选择“经典图案”图版，棋盘是否出现 42 种不同图案；
  - 选择“新版宝可梦”图版，图案是否同样正常；
  - 切换难度、重新开始、切换图版后是否没有花屏或空白格。


---

### 63. 整理与压缩项目素材

**时间**：2026-07-14  
**涉及文件**：`assets/pokemon/normal/tile_*.png`、`assets/sound/喝彩鼓掌14秒.mp3`、
`assets/pokemon/cell_spritesheet.png`、`assets/pokemon/tilemap_packed.png`、
`dcss_tileset.png`、`tile_01_outlined_blackbg.png`、`tile_01_outlined_blackbg_scaled.png`、
`rltiles-2d.json`、`session_33ec6a44-076f-4f88-b09e-79002ee0827a.zip`、
`generate_spritesheet.py`、`outline_sprite.py`、`panel_container.tscn`、
`__pycache__/`、`.venv/`、`AGENTS.md`

**原因**：项目根目录和 `assets/` 下积累了大量未被代码引用的中间文件、测试资源、旧脚本和临时环境，导致仓库体积膨胀（`assets/pokemon` 单目录约 30 MB）；需要在保证游戏内显示品质与画质的前提下进行整合、压缩与清理。

**改动**：

- **压缩在用图块**：
  - 对 `assets/pokemon/normal/tile_01.png` ~ `tile_42.png` 使用 LANCZOS 重采样等比缩放，最长边限制为 256 px，并保存为优化后的 PNG。
  - 处理前：42 张图块共约 29.3 MB（最大单张 2713×2713）。
  - 处理后：42 张图块共约 2.4 MB，画质足以覆盖棋盘格子在桌面和移动端的常见显示尺寸。
  - 经典图块 `assets/classicPics/level3/normal/tile_*.png` 尺寸已为 39×39、总体仅 122 KB，保持原样。

- **删除未使用资源**：
  - `assets/pokemon/cell_spritesheet.png` 及其 `.import`
  - `assets/pokemon/tilemap_packed.png` 及其 `.import`
  - `dcss_tileset.png` 及其 `.import`
  - `tile_01_outlined_blackbg.png` 及其 `.import`
  - `tile_01_outlined_blackbg_scaled.png` 及其 `.import`
  - `rltiles-2d.json`
  - `session_33ec6a44-076f-4f88-b09e-79002ee0827a.zip`
  - `assets/sound/喝彩鼓掌14秒.mp3` 及其 `.import`（代码中未被任何 `preload` 引用）
  - `generate_spritesheet.py`、`outline_sprite.py`（旧辅助脚本，引用的文件结构已不存在）
  - `panel_container.tscn`（空场景，未被引用）
  - `__pycache__/`、`.venv/`（Python 临时缓存与虚拟环境，Godot 运行时不需要）

- **更新文档**：
  - `AGENTS.md`：修正项目结构示例，移除已删除的 `tilemap_packed.png`、`1.png`、`2.png`；更新 `cell.gd` 说明，删除“回退到 tilemap_packed.png 图集”的描述，改为当前两套 `preload` 图版路径。

**验证**：
- 全局搜索 `res://assets` 引用，确认仅剩余 `cell.gd` 中 84 条 `preload` 路径和 `game.gd` 中 10 条音频 `preload` 路径。
- 检查被删除文件的 `.import` 也已同步移除，避免 Godot 残留失效引用。
- 建议启动 Godot 编辑器后：
  - 确认“新版宝可梦”和“经典图案”两种图版均正常显示 42 种图案；
  - 确认无音频丢失、无花屏或空白格；
  - 观察 `.godot/` 重新导入过程无报错。



---

### 64. 添加休闲模式与竞技模式

**时间**：2026-07-14  
**涉及文件**：`game.gd`、`game.tscn`、`AGENTS.md`

**原因**：用户希望游戏支持两种模式：休闲模式保留无限提示与洗牌；竞技模式按关卡限制提示与洗牌次数，并在顶部 UI 显示当前模式。

**改动**：

- `game.gd`：
  - 新增 `enum GameMode {CASUAL, COMPETITIVE}`。
  - 新增竞技模式常量：
    - 第 1–7 关：5 次提示、2 次洗牌
    - 第 8–10 关：8 次提示、3 次洗牌
  - 新增状态变量 `current_mode`、`hints_remaining`、`shuffles_remaining`。
  - 新增 `@onready var mode_label: RichTextLabel = %ModeLabel`。
  - `_setup_menus()` 中在 `GameMenu` 下新增“模式”子菜单，含“休闲模式”与“竞技模式”两个可勾选条目。
  - 新增 `_on_mode_menu_item_pressed()` 处理模式切换，切换后调用 `restart_game()` 以新模式重新开始。
  - 新增 `_update_mode_menu_check()` 同步菜单勾选状态。
  - `restart_game()` 中根据当前模式和关卡重置剩余提示/洗牌次数。
  - `_on_hint_button_pressed()` 与 `_on_shuffle_button_pressed()` 在竞技模式下消耗次数，次数为 0 时不响应。
  - `_set_paused()` 与 `_update_ui()` 中根据模式与剩余次数禁用/启用提示、洗牌按钮。
  - 新增 `_update_mode_label()` 与 `_update_button_texts()`：
    - 休闲模式按钮显示“💡 提示”、“🔀 洗牌”。
    - 竞技模式按钮显示剩余次数，如“💡 提示(5)”、“🔀 洗牌(2)”。

- `game.tscn`：
  - 在 `VBoxContainer/MenuBar/HBoxContainer` 的 `Spacer` 与 `TimeLabel` 之间新增 `ModeLabel`（`%ModeLabel`）RichTextLabel，显示当前模式。

- `AGENTS.md`：
  - 更新 `game.gd` 职责说明，加入 `GameMode` 与竞技模式常量说明。
  - 更新 `game.tscn` 场景说明，加入菜单栏与模式标签。

**验证**：
- 静态检查 `game.gd` 中新增的节点引用、菜单子菜单名称与回调一致。
- 建议启动 Godot 后验证：
  - 默认进入休闲模式，提示与洗牌按钮无次数限制。
  - 通过 `游戏 → 模式 → 竞技模式` 切换后重新开始，按钮显示剩余次数。
  - 竞技模式下第 1–7 关开始为 5 提示 / 2 洗牌；第 8–10 关开始为 8 提示 / 3 洗牌。
  - 竞技模式下次数用尽后对应按钮变灰且点击无效。
  - 顶部 `ModeLabel` 在“总用时”左侧正确显示“模式：休闲”或“模式：竞技”。



---

### 65. 将“模式”子菜单置顶

**时间**：2026-07-14  
**涉及文件**：`game.gd`

**原因**：用户希望 `游戏` 下拉菜单中的“模式”选项放在最上方，便于快速切换。

**改动**：

- `game.gd` 的 `_setup_menus()` 中调整 `GameMenu` 的添加顺序：
  1. `模式` 子菜单
  2. 分隔线
  3. `初级`、`中级`、`高级`
  4. `选择关卡` 子菜单
- 同步更新 `_on_game_menu_item_pressed(index)`，将难度索引计算从 `index + 1` 改为 `index - 1`，以适配新的菜单位置。

**验证**：
- 静态检查菜单索引与难度计算逻辑一致。
- 建议启动 Godot 后打开 `游戏` 菜单，确认“模式”位于最上方，且切换难度仍能正确进入初级/中级/高级。



---

### 66. 在帮助菜单中添加模式说明

**时间**：2026-07-14  
**涉及文件**：`game.gd`

**原因**：用户希望在 `帮助` 菜单中增加模式说明，方便玩家了解休闲模式与竞技模式的区别和次数规则。

**改动**：

- `game.gd`：
  - `DialogType` 枚举新增 `MODE_RULES`。
  - `_setup_menus()` 中在 `帮助` 菜单的“连连看规则”之后新增“模式说明”项。
  - `_on_help_menu_item_pressed(index)` 中新增索引 1 的处理分支：
    - 弹窗标题为“模式说明”。
    - 内容说明休闲模式无限提示/洗牌，竞技模式按关卡分配固定次数（1–7 关 5/2，8–10 关 8/3）。
  - 原有“快捷键说明”“积分规则”“关于”的索引依次后移 1 位。

**验证**：
- 静态检查 `DialogType.MODE_RULES` 已加入枚举，帮助菜单索引与处理分支一一对应。
- 建议启动 Godot 后点击 `帮助 → 模式说明`，确认弹窗内容正确显示两种模式的规则。



---

### 67. 更换 UI 字体为宋体（Noto Serif SC）并保留 Emoji

**时间**：2026-07-15  
**涉及文件**：
- `assets/fonts/NotoSerifSC-Regular.otf`（使用项目中已有的宋体）
- `assets/fonts/NotoColorEmoji.ttf`（新增 Emoji 回退字体）
- `assets/fonts/main_font.tres`（新增主字体组合：宋体 + Emoji 回退）
- `ocean_theme.tres`
- `game.tscn`

**原因**：用户希望界面使用宋体显示，同时保留按钮与标签中的 Emoji。

**改动**：

1. 字体准备：
   - 使用项目已存在的 `NotoSerifSC-Regular.otf` 作为主宋体。
   - 从 CTAN 下载 `NotoColorEmoji.ttf`（彩色 Emoji 字体）并放入 `assets/fonts/`。
   - 为 `NotoSerifSC-Regular.otf` 与 `NotoColorEmoji.ttf` 创建 `.import` 文件，供 Godot 导入。
2. 创建 `assets/fonts/main_font.tres`：
   - `base_font` 设为 `NotoSerifSC-Regular.otf`。
   - `fallbacks` 设为 `[NotoColorEmoji.ttf]`，确保 Emoji 字符可以正常显示。
3. 更新 `ocean_theme.tres`：
   - 引入 `main_font.tres` 作为外部资源。
   - 在 `[resource]` 中设置 `default_font = ExtResource("1_8ajk0")`，让整个主题默认使用宋体 + Emoji 回退。
4. 更新 `game.tscn`：
   - 引入 `main_font.tres` 作为外部资源 `4_2epjp`。
   - 将暂停界面大字号 `LabelSettings_pause` 的字体从系统字体改为 `main_font.tres`，避免该标签脱离主题字体。

**验证**：
- 静态检查主题、场景的字体引用路径正确。
- 建议启动 Godot 后观察：
  - 菜单、按钮、标签文字均为宋体。
  - 按钮中的 Emoji（↩、↪、⏸、💡、🔀、🔄）以及 RichTextLabel 中的符号仍能正常显示。
  - 暂停界面的“暂停”二字也使用宋体放大显示。


---

### 68. 清理 fonts 文件夹中未使用的字体

**时间**：2026-07-15  
**涉及文件**：
- `assets/fonts/NotoSerifCJKsc-Regular.otf`
- `assets/fonts/NotoSerifCJKsc-Regular.otf.import`
- `assets/fonts/NotoEmoji-Regular.ttf`
- `assets/fonts/NotoEmoji-Regular.ttf.import`
- `.godot/imported/` 中对应的缓存文件

**原因**：字体效果合适后，用户要求删除不需要的文件，保持项目整洁。

**改动**：
- 删除未使用的 `NotoSerifCJKsc-Regular.otf` 及其导入文件、缓存。
- 删除备用的 `NotoEmoji-Regular.ttf` 及其导入文件、缓存。
- 仅保留实际使用的：
  - `NotoSerifSC-Regular.otf`（宋体主字体）
  - `NotoColorEmoji.ttf`（Emoji 回退）
  - `main_font.tres`（字体组合）

**验证**：
- 静态检查项目代码中已无对 `NotoSerifCJKsc` 和 `NotoEmoji-Regular` 的引用。
- `assets/fonts/` 中仅剩当前正在使用的字体文件。


---

### 69. 为 RichTextLabel 显式设置宋体字体

**时间**：2026-07-15  
**涉及文件**：`ocean_theme.tres`

**原因**：用户发现“将鼠标移动至顶部”提示语（`AutoHideHint` RichTextLabel）没有使用新字体。

**改动**：
- 在 `ocean_theme.tres` 中为 `RichTextLabel` 显式指定主题字体：
  - `normal_font = main_font.tres`
  - `bold_font = main_font.tres`
  - `italics_font = main_font.tres`
  - `mono_font = main_font.tres`
- 这样所有 `RichTextLabel`（包括提示语、模式标签、分数标签等）都会明确使用宋体 + Emoji 回退。

**验证**：
- 静态检查 `ocean_theme.tres` 中 `RichTextLabel/fonts/*` 都指向 `main_font.tres`。
- 建议启动 Godot 后触发顶部自动隐藏提示，确认“将鼠标移动至顶部”文字也是宋体。


---

### 70. 修复字体 UID 引用错误导致主题字体未生效

**时间**：2026-07-15  
**涉及文件**：`assets/fonts/main_font.tres`

**原因**：Godot 编辑器在导入字体时重新分配了 UID（`NotoSerifSC-Regular.otf` 和 `NotoColorEmoji.ttf` 的 UID 与最初手写的 `.import` 文件不一致），而 `main_font.tres` 仍然引用旧 UID，导致 `FontVariation` 加载失败，UI 回退到系统默认字体（看起来像繁体字）。

**改动**：
- 将 `main_font.tres` 中的字体资源 UID 更新为 Godot 实际生成的 UID：
  - `NotoSerifSC-Regular.otf`：`uid://c7qgmuyivwaw7`
  - `NotoColorEmoji.ttf`：`uid://ch4acpi63uv7l`

**验证**：
- 静态检查项目中已无旧 UID 引用。
- 建议删除 `.godot/` 缓存后重新打开 Godot，让主题字体正确加载，再确认所有中文文字均为宋体。


---

### 71. 去掉 FontVariation，直接用 NotoSerifSC 作为主题字体并代码添加 Emoji 回退

**时间**：2026-07-15  
**涉及文件**：
- `assets/fonts/main_font.tres`（删除）
- `ocean_theme.tres`
- `game.tscn`
- `game.gd`

**原因**：经过多次尝试，`FontVariation` 资源在项目中未能正确加载，导致主题字体始终没有生效，界面回退到系统默认字体（看起来像繁体）。改为直接引用已导入的 `NotoSerifSC-Regular.otf` 作为主题字体，并在运行时为其添加 Emoji 回退。

**改动**：

1. 删除 `assets/fonts/main_font.tres`，避免失效的中间资源干扰。
2. 更新 `ocean_theme.tres`：
   - 将外部字体资源从 `main_font.tres` 改为 `NotoSerifSC-Regular.otf`。
   - `default_font`、`RichTextLabel` 的 `normal_font`/`bold_font`/`italics_font`/`mono_font` 都指向该字体文件。
3. 更新 `game.tscn`：
   - 将暂停界面 `LabelSettings_pause` 的字体从 `main_font.tres` 改为 `NotoSerifSC-Regular.otf`。
4. 更新 `game.gd`：
   - 新增常量 `EMOJI_FONT` 预加载 `NotoColorEmoji.ttf`。
   - 在 `_ready()` 中加载 `NotoSerifSC-Regular.otf`，并把 `EMOJI_FONT` 加入其 `fallbacks`，保证按钮里的 emoji 仍能正常显示。

**验证**：
- 静态检查 `ocean_theme.tres` 和 `game.tscn` 中已无对 `main_font.tres` 的引用。
- 重新打开 Godot 后，所有中文标签（包括“将鼠标移动至顶部”提示）应直接使用 Noto Serif SC 宋体。
- 按钮中的 emoji 符号应继续显示。


---

### 72. 将自动隐藏提示改为横向整句显示

**时间**：2026-07-15  
**涉及文件**：`game.tscn`

**原因**：用户要求“将鼠标移到屏幕顶部即可恢复菜单栏”这句话用当前字体横向、标准简体字显示，而不是之前的竖排单字布局。

**改动**：
- 修改 `CanvasLayer/AutoHideHint` 的 `text`：
  - 去掉 `[table]` 竖排布局，改为完整一句 `[outline_size=3][outline_color=#000000][color=#FFD700]将鼠标移到屏幕顶部即可恢复菜单栏[/color][/outline_color][/outline_size]`。
- 调整控件尺寸：
  - `offset_top` 从 `-250.0` 改为 `-40.0`
  - `offset_bottom` 从 `250.0` 改为 `40.0`
  - `offset_right` 从 `150.0` 改为 `800.0`
  - 使其适应一行横向文字的宽度。

**验证**：
- 静态检查 `AutoHideHint` 的文字为标准简体字，且使用主题中设置的 NotoSerifSC 字体。
- 运行后鼠标移到屏幕顶部触发提示时，应显示为一行横向宋体文字。


---

### 73. 恢复自动隐藏提示的原始竖排布局与位置，并显式指定宋体

**时间**：2026-07-15  
**涉及文件**：`game.tscn`

**原因**：用户希望保留原来的排版和位置，只要求文字用标准简体字宋体显示；同时反馈“将”“复”等字显示异常，因此给该提示单独显式设置字体，避免主题字体未正确继承。

**改动**：
- 恢复 `CanvasLayer/AutoHideHint` 的原始位置和尺寸：
  - `offset_top = -250.0`
  - `offset_bottom = 250.0`
  - `offset_right = 150.0`
- 恢复原来的 `[table=2]` 竖排文字布局。
- 为该 `RichTextLabel` 显式添加 `theme_override_fonts/normal_font = ExtResource("4_2epjp")`，直接指向 `NotoSerifSC-Regular.otf`，确保提示文字使用宋体。

**验证**：
- 静态检查 `AutoHideHint` 的文字为标准简体字，且字体覆盖明确指向 NotoSerifSC。
- 运行后提示应保持原有竖排位置和样式，文字为宋体。


---

### 74. 【最终完成】UI 字体成功更换为宋体（Noto Serif SC）并保留 Emoji

**时间**：2026-07-15  
**涉及文件**：
- `assets/fonts/NotoSerifSC-Regular.otf`
- `assets/fonts/NotoColorEmoji.ttf`
- `assets/fonts/NotoSerifSC-Regular.otf.import`
- `assets/fonts/NotoColorEmoji.ttf.import`
- `ocean_theme.tres`
- `game.tscn`
- `game.gd`
- `DEVELOPMENT_LOG.md`

**原因**：经过多轮尝试（`FontVariation` 资源、`Theme.default_font`、`RichTextLabel` 主题字体项等），最终确认需要直接引用已导入的 `NotoSerifSC-Regular.otf` 作为主题字体，并为 `AutoHideHint` 单独显式设置 `normal_font`，才能确保所有文字（包括 CanvasLayer 下的提示语）都正确渲染为宋体。

**最终方案**：
1. 主题字体：
   - `ocean_theme.tres` 的 `default_font` 直接设为 `NotoSerifSC-Regular.otf`。
   - `RichTextLabel` 的 `normal_font`/`bold_font`/`italics_font`/`mono_font` 也直接指向 `NotoSerifSC-Regular.otf`。
2. Emoji 回退：
   - `game.gd` 中在 `_ready()` 加载 `NotoSerifSC-Regular.otf`，并把 `NotoColorEmoji.ttf` 加入其 `fallbacks`，保证按钮与标签中的 emoji 正常显示。
3. 自动隐藏提示：
   - `game.tscn` 中 `CanvasLayer/AutoHideHint` 恢复原始竖排布局与位置。
   - 为该节点显式设置 `theme_override_fonts/normal_font = NotoSerifSC-Regular.otf`，避免主题继承异常导致个别字显示为系统默认字体。

**验证（已确认生效）**：
- 菜单、按钮、标签、弹窗等所有中文文字均显示为 Noto Serif SC 宋体。
- “将鼠标移到屏幕顶部即可恢复菜单栏”提示保持原有竖排样式，且每个字都是标准简体宋体。
- 按钮中的 emoji（↩、↪、⏸、💡、🔀、🔄）以及其它符号均能正常显示。
