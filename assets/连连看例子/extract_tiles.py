import struct, zlib, os, shutil
from PIL import Image

# 连连看例子目录（脚本所在目录）
SRC_DIR = os.path.dirname(os.path.abspath(__file__))
# 项目根目录
PROJECT_ROOT = os.path.abspath(os.path.join(SRC_DIR, "../.."))
# 输出目录
OUT_DIR = os.path.join(PROJECT_ROOT, "assets", "classicPics")

def write_png(rgb_bytes, w, h, path):
    """把 RGB 字节数组写成 PNG（保持与原脚本一致，无外部依赖）"""
    def chunk(name, data):
        return struct.pack('>I', len(data)) + name + data + struct.pack('>I', zlib.crc32(name + data) & 0xffffffff)
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw.extend(rgb_bytes[y*w*3:(y+1)*w*3])
    compressed = zlib.compress(bytes(raw), 9)
    ihdr = struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr) + chunk(b'IDAT', compressed) + chunk(b'IEND', b'')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(png)

def extract_sprite_sheet(bmp_path, tile_w, tile_h, out_prefix):
    """
    从 BMP 精灵表中切出 tile_w x tile_h 的小图。
    假设第一列是 normal，其余列是 selected。
    返回提取到的图块数量（按行计）。
    """
    im = Image.open(bmp_path)
    if im.mode != 'RGB':
        im = im.convert('RGB')
    width, height = im.size
    cols = width // tile_w
    rows = height // tile_h
    if cols == 0 or rows == 0:
        return 0

    print(f"Extracting {bmp_path}: {cols} cols x {rows} rows = {cols*rows} tiles ({tile_w}x{tile_h})")

    normal_dir = os.path.join(out_prefix, "normal")
    selected_dir = os.path.join(out_prefix, "selected")
    os.makedirs(normal_dir, exist_ok=True)
    os.makedirs(selected_dir, exist_ok=True)

    count = 0
    for row in range(rows):
        for col in range(cols):
            tile = im.crop((col * tile_w, row * tile_h, (col + 1) * tile_w, (row + 1) * tile_h))
            rgb = bytearray()
            for y in range(tile_h):
                for x in range(tile_w):
                    r, g, b = tile.getpixel((x, y))
                    rgb.extend((r, g, b))  # PIL 已返回 RGB，无需再交换
            suffix = "normal" if col == 0 else "selected"
            idx = row + 1
            write_png(bytes(rgb), tile_w, tile_h, os.path.join(out_prefix, suffix, f"tile_{idx:02d}.png"))
        count = rows
    return count

def copy_tiles_to_level3(all_tiles_dir):
    """把所有图块集中到 level3，精简项目，避免初中高级素材重复。"""
    normal_src = os.path.join(all_tiles_dir, "normal")
    selected_src = os.path.join(all_tiles_dir, "selected")
    normal_files = sorted([f for f in os.listdir(normal_src) if f.endswith('.png')])

    level_normal = os.path.join(OUT_DIR, "level3", "normal")
    level_selected = os.path.join(OUT_DIR, "level3", "selected")
    os.makedirs(level_normal, exist_ok=True)
    os.makedirs(level_selected, exist_ok=True)

    for filename in normal_files:
        shutil.copy2(os.path.join(normal_src, filename), os.path.join(level_normal, filename))
        shutil.copy2(os.path.join(selected_src, filename), os.path.join(level_selected, filename))
    print(f"  level3: {len(normal_files)} tiles")

def copy_backgrounds():
    """把 img/ 中的关卡背景图按编号分组复制到 backgrounds/ 下"""
    img_dir = os.path.join(SRC_DIR, "img")
    bg_dir = os.path.join(OUT_DIR, "backgrounds")
    groups = {
        "level1": [(101, 110)],
        "level2": [(201, 211)],
        "level3": [(302, 310)],
    }
    for level, ranges in groups.items():
        target = os.path.join(bg_dir, level)
        os.makedirs(target, exist_ok=True)
        for start, end in ranges:
            for n in range(start, end + 1):
                src = os.path.join(img_dir, f"{n}.jpg")
                if os.path.exists(src):
                    shutil.copy2(src, os.path.join(target, f"bg_{n}.jpg"))
        print(f"  backgrounds/{level}: copied {len(os.listdir(target))} images")

def main():
    print(f"Source: {SRC_DIR}")
    print(f"Output: {OUT_DIR}")

    # 清理旧输出（保留 .import 由 Godot 自行管理）
    if os.path.exists(OUT_DIR):
        shutil.rmtree(OUT_DIR)

    # 1. 从所有疑似精灵表的 BMP 中提取图块
    bmp_dir = os.path.join(SRC_DIR, "extracted_bmp")
    all_tiles_dir = os.path.join(SRC_DIR, "extracted_tiles_all")

    # 已知或推测的精灵表配置：(文件名关键字, 图块宽, 图块高)
    # 目前只有 bitmap_129 是完整宝可梦图块表（39x39，2列 x 42行）
    sprite_configs = [
        ("bitmap_129.bmp", 39, 39),
    ]

    total_rows = 0
    for filename, tw, th in sprite_configs:
        path = os.path.join(bmp_dir, filename)
        if os.path.exists(path):
            rows = extract_sprite_sheet(path, tw, th, all_tiles_dir)
            total_rows += rows
        else:
            print(f"Warning: {path} not found")

    if total_rows == 0:
        print("No sprite sheets found. Nothing to organize.")
        return

    # 2. 把所有图块集中到 level3，初中高级共用同一套素材
    print("Copying all tiles into level3...")
    copy_tiles_to_level3(all_tiles_dir)

    # 3. 复制背景图
    print("Copying level backgrounds...")
    copy_backgrounds()

    print("\nDone. Check assets/classicPics/")

if __name__ == "__main__":
    main()
