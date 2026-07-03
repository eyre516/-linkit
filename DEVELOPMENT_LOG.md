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
