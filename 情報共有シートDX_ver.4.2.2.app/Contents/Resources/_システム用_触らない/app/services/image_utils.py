from pathlib import Path
from PIL import Image, ImageOps


def prepare_image_for_ppt(image_path: Path, temp_dir: Path, stem: str):
    """EXIFの向き情報を反映して一時保存。iPhoneなどの向きズレ対策。"""
    temp_dir.mkdir(parents=True, exist_ok=True)

    with Image.open(image_path) as img:
        img = ImageOps.exif_transpose(img)

        if img.mode in ("RGBA", "LA"):
            out_path = temp_dir / f"{stem}.png"
            img.save(out_path)
        else:
            out_path = temp_dir / f"{stem}.jpg"
            img = img.convert("RGB")
            img.save(out_path, quality=95)

        width_px, height_px = img.size

    return out_path, width_px, height_px


def calc_fit_rect(box_left, box_top, box_width, box_height, img_width_px, img_height_px):
    """縦横比を維持して枠内に収める中央配置計算。切り抜きなし、引き伸ばしなし。"""
    if img_width_px <= 0 or img_height_px <= 0:
        return box_left, box_top, box_width, box_height

    img_ratio = img_width_px / img_height_px
    box_ratio = box_width / box_height

    if img_ratio >= box_ratio:
        new_width = box_width
        new_height = int(box_width / img_ratio)
    else:
        new_height = box_height
        new_width = int(box_height * img_ratio)

    new_left = int(box_left + (box_width - new_width) / 2)
    new_top = int(box_top + (box_height - new_height) / 2)

    return new_left, new_top, int(new_width), int(new_height)
