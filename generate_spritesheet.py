#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 assets 下 1-42 的 PNG 图标合并成 cell_spritesheet.png"""

import re
from pathlib import Path
from PIL import Image


ASSETS_DIR = Path(__file__).parent / "assets"
OUTPUT = ASSETS_DIR / "cell_spritesheet.png"

# 图集配置：6 列，每格 128x128，图标最大 120x120 以留出边距
COLS = 6
CELL_SIZE = 128
MAX_ICON_SIZE = 120


def extract_number(path: Path) -> int:
    m = re.match(r"(\d+)", path.name)
    if not m:
        raise ValueError(f"无法从文件名提取编号: {path}")
    return int(m.group(1))


# 按编号顺序加载 1-42 的图标
def load_images() -> list[Image.Image]:
    files = sorted(ASSETS_DIR.glob("[0-9]*.png"), key=extract_number)
    images: list[Image.Image] = []
    for f in files:
        idx = extract_number(f)
        if idx < 1 or idx > 42:
            continue
        if idx != len(images) + 1:
            raise ValueError(f"缺少编号 {len(images) + 1} 的图片，找到的是 {f.name}")
        img = Image.open(f).convert("RGBA")
        images.append(img)
    if len(images) != 42:
        raise ValueError(f"需要 42 张图片，实际找到 {len(images)} 张")
    return images


# 等比缩放图标，让长边不超过 MAX_ICON_SIZE
def fit_image(img: Image.Image) -> Image.Image:
    img.thumbnail((MAX_ICON_SIZE, MAX_ICON_SIZE), Image.Resampling.LANCZOS)
    return img


# 将 42 张图标按 6 列排列到透明背景上
def build_spritesheet(images: list[Image.Image]) -> Image.Image:
    rows = (len(images) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * CELL_SIZE, rows * CELL_SIZE), (0, 0, 0, 0))

    for i, img in enumerate(images):
        icon = fit_image(img)
        x = (i % COLS) * CELL_SIZE
        y = (i // COLS) * CELL_SIZE
        # 居中粘贴
        paste_x = x + (CELL_SIZE - icon.width) // 2
        paste_y = y + (CELL_SIZE - icon.height) // 2
        sheet.paste(icon, (paste_x, paste_y), icon)

    return sheet


# 生成并保存图集
def main():
    images = load_images()
    sheet = build_spritesheet(images)
    sheet.save(OUTPUT, "PNG")
    print(f"已生成 {OUTPUT} ({sheet.width}x{sheet.height})")


if __name__ == "__main__":
    main()
