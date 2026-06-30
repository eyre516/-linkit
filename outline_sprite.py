#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""给 PNG 精灵图添加黑色描边（勾黑边）"""

from pathlib import Path
from PIL import Image, ImageFilter
import sys


def add_black_outline(input_path: Path, output_path: Path | None = None, thickness: float | None = None) -> Image.Image:
    """
    为透明背景的 PNG 图片添加黑色描边。

    Args:
        input_path: 输入 PNG 路径。
        output_path: 输出路径；为 None 时覆盖原文件。
        thickness: 描边粗细（像素）。为 None 时按图片短边自适应。
    """
    img = Image.open(input_path).convert("RGBA")
    w, h = img.size

    if thickness is None:
        # 按短边比例自适应，保证缩放到 48x48 格子里仍能看到黑边
        thickness = max(8, min(w, h) // 55)

    # 提取不透明区域掩码
    alpha = img.split()[3]
    mask = alpha.point(lambda a: 255 if a > 30 else 0, mode="1")

    # 形态学膨胀：用 MaxFilter 模拟
    filter_size = int(2 * thickness + 1)
    dilated = mask.filter(ImageFilter.MaxFilter(filter_size))

    # 构建黑色描边层
    outline = Image.new("RGBA", img.size, (0, 0, 0, 255))
    # 只在“膨胀后但不属于原图”的区域显示黑色
    outline.putalpha(dilated)

    # 原图覆盖在描边之上
    result = Image.alpha_composite(outline, img)

    if output_path is None:
        output_path = input_path
    result.save(output_path, "PNG")
    return result


# 批量处理 assets 下编号 1-42 的 PNG
def main():
    assets_dir = Path(__file__).parent / "assets"
    files = sorted(assets_dir.glob("[0-9]*.png"))
    if not files:
        print("No numbered images found.")
        sys.exit(1)

    print(f"Found {len(files)} images, processing...")
    for f in files:
        add_black_outline(f)
        print(f"  [OK] {f.name}")
    print("All done.")


if __name__ == "__main__":
    main()
